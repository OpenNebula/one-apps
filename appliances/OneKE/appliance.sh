#!/usr/bin/env bash

service_bootstrap() { ruby -- "${BASH_SOURCE%.*}/appliance.rb" bootstrap; }

service_cleanup() { ruby -- "${BASH_SOURCE%.*}/appliance.rb" cleanup; }

service_configure() { ruby -- "${BASH_SOURCE%.*}/appliance.rb" configure; }

service_install() { ruby -- "${BASH_SOURCE%.*}/appliance.rb" install; }

return
