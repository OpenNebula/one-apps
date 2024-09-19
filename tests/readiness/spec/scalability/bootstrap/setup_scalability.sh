#!/bin/bash

DB_USER=oneadmin
DB_PASS=opennebula
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

echo 'Stopping opennebula'
service opennebula status 1>/dev/null 2>/dev/null

IS_SERVICE=$CHILD_STATUS
if [[ $IS_SERVICE == 0 ]]; then
    # Stop opennebula as service
    systemctl stop opennebula
else
    # Open nebula is not service
    one stop
fi

# Restore DB
echo 'Restoring DB'
xz -d 1.25KHosts_20KVMs.sql.xz
onedb restore -f '1.25KHosts_20KVMs.sql'

# Fix database charset:
echo 'Fixing DB charset'
mysql -u $DB_USER -p$DB_PASS opennebula -e "ALTER DATABASE opennebula CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;"

# For each table fix charset:
TABLES=$(mysql -u $DB_USER -p$DB_PASS opennebula -N -s -e "SHOW TABLES")

for TABLE in $TABLES; do
    echo "Processing table $TABLE"
    mysql -u $DB_USER -p$DB_PASS opennebula -e "ALTER TABLE $TABLE CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"
done

echo 'Upgrading DB'
onedb upgrade -v

# Start opennebula
echo 'Starting OpenNebula'
if [[ $IS_SERVICE == 0 ]]; then
    # Start opennebula as service
    systemctl start opennebula
    systemctl stop opennebula-scheduler
else
    # OpenNebula is not service
    one start
    killall -9 mm_sched
fi

