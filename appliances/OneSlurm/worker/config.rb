# frozen_string_literal: true

INSTALL_DRIVERS               = env :INSTALL_DRIVERS, 'true'
INSTALL_INFINIBAND            = env :INSTALL_INFINIBAND, 'true'
NVIDIA_DRIVER_BRANCH          = env :NVIDIA_DRIVER_BRANCH, '595'
ONEAPP_SLURM_INFINIBAND_ENABLE = env :ONEAPP_SLURM_INFINIBAND_ENABLE,
                                      'NO'
ONEAPP_SLURM_IPOIB_SUBNET      = env :ONEAPP_SLURM_IPOIB_SUBNET, ''
