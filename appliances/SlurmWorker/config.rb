begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end


ONEAPP_SLURM_CONTROLLER_IP    = env :ONEAPP_SLURM_CONTROLLER_IP, ''
ONEAPP_MUNGE_KEY_BASE64 = env :ONEAPP_MUNGE_KEY_BASE64, ''


