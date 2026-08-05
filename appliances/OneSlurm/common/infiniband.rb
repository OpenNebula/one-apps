# frozen_string_literal: true

require 'ipaddr'

# InfiniBand / IPoIB helpers shared by OneSlurm roles.
module OneSlurm

    module Infiniband

        DOCA_PPA = 'ppa:canonical-nvidia/doca-stable'

        def install_worker_infiniband_packages
            msg :info, 'Installing InfiniBand, UCX, and Open MPI runtime packages'
            install_rdma_base_packages
            install_doca_ucx_package
            bash 'apt install -y openmpi-bin openmpi-common'
            install_infiniband_memlock_limits
            verify_ucx_ib_plugin!
        end

        def install_controller_infiniband_packages
            msg :info, 'Installing Open MPI development packages'
            bash 'apt update && apt install -y libopenmpi-dev openmpi-bin openmpi-common'
            install_infiniband_memlock_limits
        end

        def install_rdma_base_packages
            bash 'apt update && apt install -y rdma-core infiniband-diags'
        end

        def install_doca_ucx_package
            bash <<~SCRIPT
                export DEBIAN_FRONTEND=noninteractive
                apt update
                apt install -y software-properties-common gnupg ca-certificates curl
                add-apt-repository -y #{DOCA_PPA}
                apt update
                UCX_PACKAGE="$(apt-cache search --names-only '^ucx-[0-9]' | awk '{print $1}' | sort -V | tail -n1)"
                if [ -z "$UCX_PACKAGE" ]; then
                    echo "WARN: DOCA ucx-* package not found, trying distro ucx package" >&2
                    UCX_PACKAGE=ucx
                fi
                apt install -y "$UCX_PACKAGE"
                if ! find /usr -name 'libuct_ib.so*' -print -quit | grep -q .; then
                    echo 'FATAL: UCX IB transport is not available after UCX install.' >&2
                    exit 1
                fi
                if ! command -v ucx_info >/dev/null || ! ucx_info -v >/dev/null; then
                    echo 'FATAL: ucx_info is not available after UCX install.' >&2
                    exit 1
                fi
            SCRIPT
        end

        def install_infiniband_memlock_limits
            file '/etc/security/limits.d/99-oneslurm-infiniband.conf', <<~LIMITS,
                * soft memlock unlimited
                * hard memlock unlimited
                root soft memlock unlimited
                root hard memlock unlimited
            LIMITS
                 mode: 'u=rw,go=r', overwrite: true
        end

        def verify_infiniband_runtime!
            bash <<~SCRIPT
                command -v rdma >/dev/null
                command -v ibstat >/dev/null
                command -v mpirun >/dev/null
                command -v ucx_info >/dev/null
            SCRIPT
            verify_ucx_ib_plugin!
        rescue StandardError => e
            raise 'FATAL: InfiniBand support is enabled, but the worker image ' \
                  'does not include the required packages. Rebuild with ' \
                  "INSTALL_INFINIBAND=true. #{e.message}"
        end

        def verify_ucx_ib_plugin!
            bash <<~SCRIPT
                if ldconfig -p | grep -q 'libuct_ib.so.0'; then
                    ucx_info -v >/dev/null
                    exit $?
                fi
                if ! find /usr -name 'libuct_ib.so*' -print -quit | grep -q .; then
                    exit 1
                fi
                ucx_info -v >/dev/null
            SCRIPT
        end

        def infiniband_enabled?
            ONEAPP_SLURM_INFINIBAND_ENABLE == true ||
                ONEAPP_SLURM_INFINIBAND_ENABLE.to_s.casecmp('YES').zero? ||
                ONEAPP_SLURM_INFINIBAND_ENABLE.to_s == '1'
        end

        def derive_ipoib_address(eth_ip, subnet_str)
            subnet = subnet_str.to_s.strip
            raise 'IPoIB subnet is required when InfiniBand is enabled' if subnet.empty?

            net = IPAddr.new(subnet.include?('/') ? subnet : "#{subnet}/24")
            prefix = net.prefix
            host_octets = (32 - prefix) / 8
            unless [8, 16, 24].include?(prefix) && ((32 - prefix) % 8).zero?
                raise "IPoIB subnet prefix must be /8, /16, or /24, got /#{prefix}"
            end

            eth_parts = ipv4_octets(eth_ip, 'Ethernet IPv4')
            net_parts = ipv4_octets(net.to_s, 'IPoIB subnet')
            host_parts = eth_parts.last(host_octets)
            raise 'IPoIB host portion must not be all-zero' if host_parts.all?(&:zero?)
            if host_parts.all? { |part| part == 255 }
                raise 'IPoIB host portion must not be all-ones'
            end

            addr = (net_parts.first(4 - host_octets) + host_parts).join('.')
            raise "#{addr} outside #{net}" unless net.include?(IPAddr.new(addr))

            "#{addr}/#{prefix}"
        rescue IPAddr::InvalidAddressError => e
            raise "Invalid IPoIB subnet '#{subnet}': #{e.message}"
        end

        def ipv4_octets(ip, label)
            parts = ip.to_s.split('.')
            unless parts.size == 4 && parts.all? { |part| part.match?(/\A\d+\z/) }
                raise "invalid #{label} #{ip}"
            end

            parts.map(&:to_i).tap do |octets|
                raise "invalid #{label} #{ip}" unless octets.all? { |octet| octet.between?(0, 255) }
            end
        end

        def load_ipoib_modules
            bash 'modprobe ib_ipoib || true'
        end

        def ib_interface
            Dir.glob('/sys/class/net/ib*')
               .map { |path| File.basename(path) }
               .sort
               .first
        end

        def wait_for_ib_interface(retries = 12, seconds = 5)
            retries.times do |i|
                iface = ib_interface
                return iface unless iface.nil?

                msg :warn, "No IPoIB interface found yet, retrying in #{seconds}s (#{i + 1}/#{retries})"
                sleep seconds
            end

            raise 'FATAL: InfiniBand is enabled but no ib* network interface appeared.'
        end

        def configure_ipoib(eth_ip)
            verify_infiniband_runtime!
            subnet = ONEAPP_SLURM_IPOIB_SUBNET.to_s
            ipoib_addr = derive_ipoib_address(eth_ip, subnet)

            load_ipoib_modules
            iface = wait_for_ib_interface
            msg :info, "Configuring IPoIB: Ethernet #{eth_ip} -> #{iface} #{ipoib_addr}"

            file '/etc/netplan/90-oneslurm-ipoib.yaml', <<~YAML,
                network:
                  version: 2
                  ethernets:
                    #{iface}:
                      dhcp4: false
                      addresses:
                        - #{ipoib_addr}
            YAML
                 mode: 'u=rw,go=r', overwrite: true

            bash 'netplan apply'
        end

    end

end
