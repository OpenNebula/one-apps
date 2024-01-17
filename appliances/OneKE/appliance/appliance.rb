# frozen_string_literal: true

require_relative 'config.rb'
require_relative 'helpers.rb'

require_relative 'vnf.rb'
require_relative 'kubernetes.rb'

require_relative 'multus.rb'
require_relative 'calico.rb'
require_relative 'canal.rb'
require_relative 'cilium.rb'

require_relative 'metallb.rb'
require_relative 'traefik.rb'
require_relative 'longhorn.rb'
require_relative 'cleaner.rb'

if caller.empty?
    case ARGV[0].to_sym
    when :install
        msg :debug, "ONE_SERVICE_AIRGAPPED=#{ONE_SERVICE_AIRGAPPED}"

        install_packages PACKAGES

        with_policy_rc_d_disabled do
            install_kubernetes
        end

        install_metallb
        install_traefik
        install_longhorn
        install_cleaner

        # NOTE: Longhorn images are pulled separately.
        pull_addon_images if ONE_SERVICE_AIRGAPPED

        msg :info, 'Installation completed successfully'

    when :configure
        msg :debug, "ONE_SERVICE_AIRGAPPED=#{ONE_SERVICE_AIRGAPPED}"

        prepare_dedicated_storage unless ONEAPP_STORAGE_DEVICE.nil?

        configure_vnf

        if ONE_SERVICE_AIRGAPPED
            include_images 'rke2-images-core'
            include_images 'rke2-images-multus' if ONEAPP_K8S_MULTUS_ENABLED
            include_images 'rke2-images-calico' if ONEAPP_K8S_CNI_PLUGIN == 'calico'
            include_images 'rke2-images-canal'  if ONEAPP_K8S_CNI_PLUGIN == 'canal'
            include_images 'rke2-images-cilium' if ONEAPP_K8S_CNI_PLUGIN == 'cilium'

            include_images 'one-longhorn' if ONEAPP_K8S_LONGHORN_ENABLED
            include_images 'one-metallb'  if ONEAPP_K8S_METALLB_ENABLED
            include_images 'one-traefik'  if ONEAPP_K8S_TRAEFIK_ENABLED
            include_images 'one-cleaner'
        end

        node = configure_kubernetes(
            configure_cni: ->{
                configure_multus if ONEAPP_K8S_MULTUS_ENABLED
                configure_calico if ONEAPP_K8S_CNI_PLUGIN == 'calico'
                configure_canal  if ONEAPP_K8S_CNI_PLUGIN == 'canal'
                configure_cilium if ONEAPP_K8S_CNI_PLUGIN == 'cilium'
            },
            configure_addons: ->{
                configure_metallb if ONEAPP_K8S_METALLB_ENABLED

                include_manifests 'one-longhorn' if ONEAPP_K8S_LONGHORN_ENABLED
                include_manifests 'one-metallb'  if ONEAPP_K8S_METALLB_ENABLED
                include_manifests 'one-traefik'  if ONEAPP_K8S_TRAEFIK_ENABLED
                include_manifests 'one-cleaner'
            }
        )

        if node[:join_worker]
            vnf_ingress_setup_https_backend
            vnf_ingress_setup_http_backend
        end

        msg :info, 'Configuration completed successfully'

    when :bootstrap
        puts 'bootstrap_success'
    end
end
