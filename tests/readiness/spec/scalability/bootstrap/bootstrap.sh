#!/bin/bash
CONF_FILE=$ONE_LOCATION/etc/one/monitord.conf
INF_FILE=$PWD/infrastructure.yaml

# remove all drivers from monitord
sed -i '/^IM_MAD =/,/^]/d;' $CONF_FILE

# install custom dummy driver
cat >> $CONF_FILE <<EOF

IM_MAD = [
  NAME       = "dummy",
  EXECUTABLE = "$PWD/one_im_none.rb"]

VM_MAD = [
  NAME       = "dummy",
  EXECUTABLE = "one_vmm_dummy",
  TYPE       = "xml"
]

EOF

systemctl restart opennebula
systemctl stop opennebula-scheduler

echo "onebootstrap $INF_FILE"

