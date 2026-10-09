# frozen_string_literal: true

require 'fileutils'

module Service
module FRR
# The FRR state files hold neighbor passwords: keep them 0600 in a 0700 dir.
module SecureFile
    extend self

    DIR_MODE  = 0o700
    FILE_MODE = 0o600

    # Creates the directory 0700, or tightens an existing one.
    def secure_dir(dir)
        FileUtils.mkdir_p dir, mode: DIR_MODE
        File.chmod DIR_MODE, dir
    end

    # Writes next to the target and renames, so readers never see a truncated
    # file; the temporary file is private before any content goes in.
    def write(path, content)
        secure_dir File.dirname(path)
        tmp = "#{path}.tmp"
        FileUtils.rm_f tmp
        File.open(tmp, File::WRONLY | File::CREAT | File::EXCL, FILE_MODE) { |file| file.chmod FILE_MODE }
        File.write tmp, content
        File.rename tmp, path
    end
end
end
end
