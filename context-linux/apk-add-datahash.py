#!/usr/bin/env python3

"""
Post-process an APK v2 package to add the 'datahash' field to .PKGINFO.

Alpine 3.23+ (apk-tools v3) requires a datahash field containing the SHA256
hex digest of the compressed data stream. FPM does not generate this field,
so this script injects it after package creation.

APK v2 format: concatenated gzip streams [signature] + control + data
- datahash = SHA256 of the raw compressed bytes of the data stream
"""

import gzip
import hashlib
import io
import struct
import sys
import zlib


def split_gzip_streams(data):
    """Split concatenated gzip members, return list of raw byte chunks."""
    streams = []
    pos = 0
    while pos < len(data):
        if data[pos:pos+2] != b'\x1f\x8b':
            break
        dc = zlib.decompressobj(16 + zlib.MAX_WBITS)
        try:
            dc.decompress(data[pos:])
        except zlib.error:
            break
        consumed = len(data[pos:]) - len(dc.unused_data)
        streams.append(data[pos:pos + consumed])
        pos += consumed
    return streams


def tar_checksum(header):
    """Compute tar header checksum (treating checksum field as spaces)."""
    h = bytearray(header)
    h[148:156] = b'        '
    return sum(h)


def rebuild_control_raw(control_gz, datahash):
    """Rebuild control stream by modifying .PKGINFO at the raw tar level."""
    # Decompress
    dc = zlib.decompressobj(16 + zlib.MAX_WBITS)
    tar_data = bytearray(dc.decompress(control_gz))

    # Parse first tar header (should be .PKGINFO)
    header = tar_data[:512]
    name = header[:100].rstrip(b'\x00').decode()
    if name != '.PKGINFO':
        print(f"ERROR: expected .PKGINFO, got '{name}'", file=sys.stderr)
        sys.exit(1)

    # Read file size from header (octal, offset 124-135)
    size = int(header[124:136].rstrip(b'\x00').rstrip(b' '), 8)

    # Extract .PKGINFO content
    pkginfo = tar_data[512:512 + size].decode('utf-8')

    # Remove existing datahash, add new one
    lines = [l for l in pkginfo.splitlines(True) if not l.startswith('datahash')]
    lines.append(f'datahash = {datahash}\n')
    new_pkginfo = ''.join(lines).encode('utf-8')
    new_size = len(new_pkginfo)

    # Rebuild tar: header + content + padding to 512-byte boundary
    new_header = bytearray(header)

    # Update size field (octal, 11 chars + null)
    size_str = f'{new_size:011o}'.encode()
    new_header[124:136] = size_str + b'\x00'

    # Recalculate checksum
    chksum = tar_checksum(bytes(new_header))
    chksum_str = f'{chksum:06o}\x00 '.encode()
    new_header[148:156] = chksum_str

    # Content padded to 512 bytes
    content_padded = new_pkginfo + b'\x00' * (512 - new_size % 512) if new_size % 512 else new_pkginfo

    # Check if there are more entries after .PKGINFO (scripts etc)
    old_content_blocks = (size + 511) // 512
    rest_offset = 512 + old_content_blocks * 512
    rest = tar_data[rest_offset:]

    # Assemble new tar
    new_tar = bytes(new_header) + content_padded + bytes(rest)

    # Re-compress
    buf = io.BytesIO()
    with gzip.GzipFile(fileobj=buf, mode='wb', mtime=0) as gz:
        gz.write(new_tar)
    return buf.getvalue()


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <package.apk>", file=sys.stderr)
        sys.exit(1)

    apk_path = sys.argv[1]

    with open(apk_path, 'rb') as f:
        apk_data = f.read()

    streams = split_gzip_streams(apk_data)

    if len(streams) < 2:
        print("ERROR: expected at least 2 gzip streams in APK", file=sys.stderr)
        sys.exit(1)

    # Last stream is data, second-to-last is control
    data_gz = streams[-1]
    control_gz = streams[-2]
    signature_streams = streams[:-2]

    # Compute SHA256 of the compressed data stream
    datahash = hashlib.sha256(data_gz).hexdigest()

    # Rebuild control with datahash
    new_control = rebuild_control_raw(control_gz, datahash)

    # Reassemble: signature(s) + new control + original data
    with open(apk_path, 'wb') as f:
        for sig in signature_streams:
            f.write(sig)
        f.write(new_control)
        f.write(data_gz)

    print(f"Added datahash={datahash} to {apk_path}")


if __name__ == '__main__':
    main()
