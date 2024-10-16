#!/usr/bin/env bash

# This script contains an example implementation logic for your appliances.
# For this example the goal will be to have a "database as a service" appliance

### MariaDB ##########################################################

# For organization purposes is good to define here variables that will be used by your bash logic
MARIADB_CREDENTIALS=/root/.my.cnf
MARIADB_CONFIG=/etc/my.cnf.d/example.cnf
PASSWORD_LENGTH=16
ONE_SERVICE_SETUP_DIR="/opt/one-appliance" ### Install location. Required by bash helpers

### CONTEXT SECTION ##########################################################

# List of contextualization parameters
# This is how you interact with the appliance using OpenNebula.
# These variables are defined in the CONTEXT section of the VM Template as custom variables
# https://docs.opennebula.io/6.8/management_and_operations/references/template.html#context-section
ONE_SERVICE_PARAMS=(
    'ONEAPP_DB_NAME'            'configure' 'Database name'                                     ''
    'ONEAPP_DB_USER'            'configure' 'Database service user'                             ''
    'ONEAPP_DB_PASSWORD'        'configure' 'Database service password'                         ''
    'ONEAPP_DB_ROOT_PASSWORD'   'configure' 'Database password for root'                        ''
)
# Default values for when the variable doesn't exist on the VM Template
ONEAPP_DB_NAME="${ONEAPP_DB_NAME:-mariadb}"
ONEAPP_DB_USER="${ONEAPP_DB_USER:-mariadb}"
ONEAPP_DB_PASSWORD="${ONEAPP_DB_PASSWORD:-$(gen_password ${PASSWORD_LENGTH})}"
ONEAPP_DB_ROOT_PASSWORD="${ONEAPP_DB_ROOT_PASSWORD:-$(gen_password ${PASSWORD_LENGTH})}"

# You can make this parameters a required step of the VM instantiation wizard by using the USER_INPUTS feature
# https://docs.opennebula.io/6.8/management_and_operations/vm_management/vm_templates.html?#user-inputs

###############################################################################
###############################################################################
###############################################################################

# The following functions will be called by the appliance service manager at
# the  different stages of the appliance life cycles. They must exist
# https://github.com/OpenNebula/one-apps/wiki/apps_intro#appliance-life-cycle

#
# Mandatory Functions
#

service_install()
{
    mkdir -p "$ONE_SERVICE_SETUP_DIR"

    msg info "Enable EPEL repository"
    if ! yum install -y --setopt=skip_missing_names_on_install=False epel-release ; then
        msg error "Failed to enable EPEL repository"
        exit 1
    fi

    msg info "Install required packages"
    if ! yum install -y --setopt=skip_missing_names_on_install=False mariadb mariadb-server expect ; then
        msg error "Package(s) installation failed"
        exit 1
    fi

    msg info "Delete cache and stored packages"
    yum clean all
    rm -rf /var/cache/yum

    msg info "INSTALLATION FINISHED"

    return 0
}

service_configure()
{
    msg info "Stopping services"
    systemctl stop mariadb

    setup_mariadb

    msg info "Credentials and config values are saved in: ${ONE_SERVICE_REPORT}"

    cat > "$ONE_SERVICE_REPORT" <<EOF
[DB connection info]
host     = localhost
database = ${ONEAPP_DB_NAME}

[DB root credentials]
username = root
password = ${ONEAPP_DB_ROOT_PASSWORD}

[DB user credentials]
username = ${ONEAPP_DB_USER}
password = ${ONEAPP_DB_PASSWORD}
EOF

    chmod 600 "$ONE_SERVICE_REPORT"

    msg info "Enable services"
    systemctl enable mariadb

    msg info "CONFIGURATION FINISHED"

    return 0
}

service_bootstrap()
{
    msg info "BOOTSTRAP FINISHED"

    return 0
}

# This one is not really mandatory, however it is a handled function
service_help()
{
    msg info "Example appliance how to use message. If missing it will default to the generic help"

    return 0
}

# This one is not really mandatory, however it is a handled function
service_cleanup()
{
    msg info "CLEANUP logic goes here in case of install failure"
}


###############################################################################
###############################################################################
###############################################################################

# Then for modularity purposes you can define your own functions as long as their name
# doesn't clash with the previous functions

#
# functions
#


db_reset_root_password()
{
    msg info "Reset root password"

    systemctl stop mariadb

    # waiting for shutdown
    msg info "Waiting for db to shutdown..."
    while is_mariadb_up ; do
        printf .
        sleep 1s
    done
    echo

    # start db in single-user mode
    msg info "Starting db in single-user mode"
    mysqld_safe --skip-grant-tables --skip-networking &

    # waiting for db to start
    msg info "Waiting for single-user db to start..."
    while ! is_mariadb_up ; do
        printf .
        sleep 1s
    done
    echo

    # reset root password
    mysql -u root <<EOF
FLUSH PRIVILEGES;
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${ONEAPP_DB_ROOT_PASSWORD}');
FLUSH PRIVILEGES;
EOF

    msg info "Root password changed - stopping single-user mode"
    kill $(cat /var/run/mariadb/mariadb.pid)

    # waiting for shutdown
    msg info "Waiting for db to shutdown..."
    while is_mariadb_up ; do
        printf .
        sleep 1s
    done
    echo
}

setup_mariadb()
{
    msg info "Database setup"

    # start db
    systemctl start mariadb

    # check if db was initialized
    if [ "$(find /var/lib/mysql -mindepth 1 | wc -l)" -eq 0 ] ; then
        msg error "Database was not initialized: /var/lib/mysql"
        exit 1
    fi

    # setup root password
    if is_root_password_valid ; then
        msg info "Setup root password"

        mysql -u root <<EOF
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${ONEAPP_DB_ROOT_PASSWORD}');
FLUSH PRIVILEGES;
EOF
    else
        # reset root password
        db_reset_root_password
    fi

    # store root password
    msg info "Save root credentials into: ${MARIADB_CREDENTIALS}"
    cat > "$MARIADB_CREDENTIALS" <<EOF
[client]
password = "$ONEAPP_DB_ROOT_PASSWORD"
EOF

    # config db
    msg info "Bind DB to localhost only"
    cat > "$MARIADB_CONFIG" <<EOF
[mysqld]
bind-address=127.0.0.1
EOF
    chmod 644 "$MARIADB_CONFIG"

    # restart db
    msg info "Starting db for the last time"
    systemctl restart mariadb

    # secure db
    msg info "Securing db"
    LANG=C expect -f - <<EOF
set timeout 10
spawn mysql_secure_installation

expect "Enter current password for root (enter for none):"
send "${ONEAPP_DB_ROOT_PASSWORD}\n"

expect "Set root password?"
send "n\n"

expect "Remove anonymous users?"
send "Y\n"

expect "Disallow root login remotely?"
send "Y\n"

expect "Remove test database and access to it?"
send "Y\n"

expect "Reload privilege tables now?"
send "Y\n"

expect eof
EOF

    msg info "Preparing database and passwords"
    mysql -u root -p"${ONEAPP_DB_ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS ${ONEAPP_DB_NAME};
GRANT ALL PRIVILEGES on ${ONEAPP_DB_NAME}.* to '${ONEAPP_DB_USER}'@'localhost' identified by '${ONEAPP_DB_PASSWORD}';
FLUSH PRIVILEGES;
EOF
}

is_mariadb_up()
{
    if [ -f /var/run/mariadb/mariadb.pid ] ; then
        if kill -0 $(cat /var/run/mariadb/mariadb.pid) ; then
            return 0
        fi
    fi
    return 1
}

is_root_password_valid()
{
    _check=$(mysql -u root -s -N -e 'select CURRENT_USER();')
    case "$_check" in
        root@*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac

    return 1
}
