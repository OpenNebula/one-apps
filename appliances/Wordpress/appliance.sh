# ---------------------------------------------------------------------------- #
# Copyright 2018-2019, OpenNebula Project, OpenNebula Systems                  #
#                                                                              #
# Licensed under the Apache License, Version 2.0 (the "License"); you may      #
# not use this file except in compliance with the License. You may obtain      #
# a copy of the License at                                                     #
#                                                                              #
# http://www.apache.org/licenses/LICENSE-2.0                                   #
#                                                                              #
# Unless required by applicable law or agreed to in writing, software          #
# distributed under the License is distributed on an "AS IS" BASIS,            #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.     #
# See the License for the specific language governing permissions and          #
# limitations under the License.                                               #
# ---------------------------------------------------------------------------- #

### Important notes ##################################################
#
# The contextualization variable 'ONEAPP_SITE_HOSTNAME' IS (!) mandatory and
# must be correct (resolveable, reachable) otherwise the web will be broken.
# It defaults to first non-loopback address it finds - if no address is found
# then the 'localhost' is used - and then wordpress will function correctly
# only from within the instance.
#
# 'ONEAPP_SITE_HOSTNAME' can be changed in the wordpress settings but it should
# be set to something sensible from the beginning so you can be able to login
# to the wordpress and change the settings...
#
### Important notes ##################################################


# List of contextualization parameters
ONE_SERVICE_PARAMS=(
    'ONEAPP_PASSWORD_LENGTH'    'configure' 'Database password length'                          ''
    'ONEAPP_DB_NAME'            'configure' 'Database name'                                     ''
    'ONEAPP_DB_USER'            'configure' 'Database service user'                             ''
    'ONEAPP_DB_PASSWORD'        'configure' 'Database service password'                         ''
    'ONEAPP_DB_ROOT_PASSWORD'   'configure' 'Database password for root'                        ''
    'ONEAPP_SITE_HOSTNAME'      'configure' 'Fully qualified domain name or IP'                 ''
    'ONEAPP_SSL_CERT'           'configure' 'SSL certificate'                                   'O|text64'
    'ONEAPP_SSL_PRIVKEY'        'configure' 'SSL private key'                                   'O|text64'
    'ONEAPP_SSL_CHAIN'          'configure' 'SSL CA chain'                                      'O|text64'
    'ONEAPP_SITE_TITLE'         'bootstrap' '** Site Title (set all or none)'                   'O|text'
    'ONEAPP_ADMIN_USERNAME'     'bootstrap' '** Site Administrator Login (set all or none)'     'O|text'
    'ONEAPP_ADMIN_PASSWORD'     'bootstrap' '** Site Administrator Password (set all or none)'  'O|password'
    'ONEAPP_ADMIN_EMAIL'        'bootstrap' '** Site Administrator E-mail (set all or none)'    'O|text'
)


### Appliance metadata ###############################################

# Appliance metadata
ONE_SERVICE_NAME='Service WordPress - KVM'
ONE_SERVICE_VERSION='6.4.2'   #latest
ONE_SERVICE_BUILD=$(date +%s)
ONE_SERVICE_SHORT_DESCRIPTION='Appliance with preinstalled WordPress for KVM hosts'
ONE_SERVICE_DESCRIPTION=$(cat <<EOF
Appliance with preinstalled WordPress. Run, get WordPress setup web wizard
and manually bootstrap the service, or use contextualization variables
to automate the bootstrap. For more information about credentials,
connections, and site URL check \`/etc/appliance/config\` on your running
appliance.

Initial configuration can be customized via parameters:

$(params2md 'configure')

And, optionally bootstrapped with (**ALL MUST BE SET**):

$(params2md 'bootstrap')

**WARNING: Do not use localhost or loopback for \`ONEAPP_SITE_HOSTNAME\`, it
breaks the service bootstrap. It's necessary to provide a routable name
or IP.**
EOF
)


### Contextualization defaults #######################################

# should be set before any password is to be generated
ONEAPP_PASSWORD_LENGTH="${ONEAPP_PASSWORD_LENGTH:-16}"
ONEAPP_DB_NAME="${ONEAPP_DB_NAME:-wordpress}"
ONEAPP_DB_USER="${ONEAPP_DB_USER:-wordpress}"
ONEAPP_DB_PASSWORD="${ONEAPP_DB_PASSWORD:-$(gen_password ${ONEAPP_PASSWORD_LENGTH})}"
ONEAPP_DB_ROOT_PASSWORD="${ONEAPP_DB_ROOT_PASSWORD:-$(gen_password ${ONEAPP_PASSWORD_LENGTH})}"
ONEAPP_SITE_HOSTNAME="${ONEAPP_SITE_HOSTNAME:-$(get_local_ip)}"
#ONEAPP_SSL_CERT
#ONEAPP_SSL_PRIVKEY
#ONEAPP_SSL_CHAIN


### Globals ##########################################################

MARIADB_CREDENTIALS=/root/.my.cnf
MARIADB_CONFIG=/etc/my.cnf.d/wordpress.cnf
DEP_PKGS="coreutils httpd mod_ssl mariadb mariadb-server php php-common php-mysqlnd php-json php-gd php-xml php-mbstring unzip wget curl openssl expect ca-certificates"


###############################################################################
###############################################################################
###############################################################################

#
# service implementation
#

service_cleanup()
{
    :
}

service_install()
{
    # ensuring that the setup directory exists
    #TODO: move to service
    mkdir -p "$ONE_SERVICE_SETUP_DIR"

    # packages
    install_pkgs ${DEP_PKGS}

    # wordpress
    install_wordpress "${ONE_SERVICE_VERSION}"

    # service metadata
    create_one_service_metadata

    # cleanup
    postinstall_cleanup

    msg info "INSTALLATION FINISHED"

    return 0
}

service_configure()
{
    # preparation
    stop_services

    # wordpress
    configure_wordpress

    # apache
    configure_apache

    # mariadb
    setup_mariadb
    report_config

    # enable the services
    enable_services

    # start the wordpress
    start_wordpress

    msg info "CONFIGURATION FINISHED"

    return 0
}

service_bootstrap()
{
    # run the wizard
    if ! check_wordpress_wizard ; then
        echo
        msg warning "We could not run the wizard!"
        msg info "You should have provide to us a username, a password and an email"
        msg info "Go to the wizard and input those manually:\n\thttp://${ONEAPP_SITE_HOSTNAME}/wp-admin/install.php\n"
    else
        if run_wordpress_wizard ; then
            msg info "You can log in to your new wordpress here:\n\thttp://${ONEAPP_SITE_HOSTNAME}/wp-login.php\n"
        else
            msg error "BOOTSTRAP FAILED"
            return 1
        fi
    fi

    msg info "BOOTSTRAP FINISHED"

    return 0
}

###############################################################################
###############################################################################
###############################################################################

#
# functions
#


postinstall_cleanup()
{
    msg info "Delete cache and stored packages"
    yum clean all
    rm -rf /var/cache/yum
}

stop_services()
{
    msg info "Stopping services"
    systemctl stop httpd
    systemctl stop mariadb
}

enable_services()
{
    msg info "Enable services"
    systemctl enable httpd
    systemctl enable mariadb
}

start_wordpress()
{
    msg info "Start WordPress"
    systemctl start httpd
}

install_pkgs()
{
    msg info "Enable EPEL repository"
    if ! yum install -y --setopt=skip_missing_names_on_install=False epel-release ; then
        msg error "Failed to enable EPEL repository"
        exit 1
    fi

    msg info "Install required packages"
    if ! yum install -y --setopt=skip_missing_names_on_install=False "${@}" ; then
        msg error "Package(s) installation failed"
        exit 1
    fi
}

install_wordpress()
{
    local _version="${1:-${ONE_SERVICE_VERSION}}"

    msg info "Download and unpack WordPress version: ${_version}"
    if ! [ -f "$ONE_SERVICE_SETUP_DIR"/wordpress-"${_version}".tar.gz ] || [ "${_version}" = latest ] ; then
        if ! wget "https://wordpress.org/wordpress-${_version}.tar.gz" \
            -O "$ONE_SERVICE_SETUP_DIR"/"wordpress-${_version}.tar.gz" ;
        then
            msg error "I am unable to download the required version: ${_version}"
            return 1
        fi
    fi

    rm -rf "$ONE_SERVICE_SETUP_DIR"/wordpress
    tar -C "$ONE_SERVICE_SETUP_DIR"/ -xzf "$ONE_SERVICE_SETUP_DIR"/"wordpress-${_version}.tar.gz"

    if [ "${_version}" = 'latest' ]; then
        _version=$(grep '^$wp_version =' "${ONE_SERVICE_SETUP_DIR}/wordpress/wp-includes/version.php" | cut -d"'" -f2)
        #TODO: check match x.y.z
        if [ -n "${_version}" ]; then
            msg info "Latest WordPress version detected: ${_version}"
            ONE_SERVICE_VERSION="${_version}"
        else
            msg error 'Failed to detect latest WordPress version'
            return 1
        fi
    fi

    return $?
}

configure_apache_ssl()
{
    # saving certs and key
    msg info "Saving cert files and key into PKI"
    _cert="/etc/pki/tls/certs/wordpress.pem"
    _certkey="/etc/pki/tls/private/wordpress-privkey.pem"
    _cacert="/etc/pki/tls/certs/wordpress-chain.pem"
    _cert_line="SSLCertificateFile ${_cert}"
    _certkey_line="SSLCertificateKeyFile ${_certkey}"
    _cacert_line="SSLCACertificateFile ${_cacert}"

    echo "$ONEAPP_SSL_CERT" | base64 -d > "$_cert"
    echo "$ONEAPP_SSL_PRIVKEY" | base64 -d > "$_certkey"
    if [ -n "$ONEAPP_SSL_CHAIN" ] ; then
        echo "$ONEAPP_SSL_CHAIN" | base64 -d > "$_cacert"
        chmod +r "$_cacert"
    fi
    chmod +r "$_cert"

    # ssl check
    msg info "Checking if private key match certificate:"
    _ssl_check_cert=$(openssl x509 -noout -modulus -in "$_cert")
    _ssl_check_key=$(openssl rsa -noout -modulus -in "$_certkey")
    if [ "$_ssl_check_cert" = "$_ssl_check_key" ] ; then
        msg info "OK"
    else
        msg error "Private SSL key does not belong to the certificate"
        return 1
    fi

    # fixing ssl.conf
    msg info "Fixing ssl.conf"
    sed -i 's|[[:space:]#]*SSLCertificateFile.*|'"$_cert_line"'|' /etc/httpd/conf.d/ssl.conf
    sed -i 's|[[:space:]#]*SSLCertificateKeyFile.*|'"$_certkey_line"'|' /etc/httpd/conf.d/ssl.conf
    if [ -n "$ONEAPP_SSL_CHAIN" ] ; then
        sed -i 's|[[:space:]#]*SSLCACertificateFile.*|'"$_cacert_line"'|' /etc/httpd/conf.d/ssl.conf
    else
        sed -i 's|[[:space:]#]*\(SSLCACertificateFile.*\)|#\1|' /etc/httpd/conf.d/ssl.conf
    fi

    msg info "Configuring https vhost"
    cat > /etc/httpd/conf.d/wordpress-ssl.conf <<EOF
<VirtualHost *:443>
  ServerAdmin root@localhost
  DocumentRoot /var/www/html
  ServerName ${ONEAPP_SITE_HOSTNAME}
  SSLEngine On
  ${_cert_line}
  ${_certkey_line}
  ${ONEAPP_SSL_CHAIN:+${_cacert_line}}

  ErrorLog /var/log/httpd/wordpress-ssl-error.log
  CustomLog /var/log/httpd/wordpress-ssl-access.log combined

  <Directory /var/www/html>
    Options FollowSymLinks
    AllowOverride None
    Require all granted
  </Directory>
</VirtualHost>
EOF
}

configure_apache()
{
    msg info "Apache setup"

    msg info "Configuring http vhost"
    cat > /etc/httpd/conf.d/wordpress.conf <<EOF
<VirtualHost *:80>
    ServerAdmin root@localhost
    DocumentRoot /var/www/html
    ErrorLog /var/log/httpd/wordpress-error.log
    CustomLog /var/log/httpd/wordpress-access.log combined

    <Directory /var/www/html>
        Options FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
EOF

    # SSL setup if everything needed is provided
    if [ -n "$ONEAPP_SSL_CERT" ] && [ -n "$ONEAPP_SSL_PRIVKEY" ] ; then
        msg info "SSL setup"
        msg info "DISCLAIMER: site address and certs must match for this to work..."

        if [ -f /etc/httpd/conf.modules.d/00-ssl.conf ] ; then
            sed -i 's/.*\(LoadModule.*\)/\1/' /etc/httpd/conf.modules.d/00-ssl.conf
        else
            printf 'LoadModule ssl_module modules/mod_ssl.so' > /etc/httpd/conf.modules.d/00-ssl.conf
        fi

        if ! [ -f /etc/httpd/conf.d/ssl.conf ] ; then
            if [ -f /etc/httpd/conf.d/ssl.conf-disabled ] ; then
                mv /etc/httpd/conf.d/ssl.conf-disabled /etc/httpd/conf.d/ssl.conf
            else
                msg error "Missing ssl.conf"
                return 1
            fi
        fi

        configure_apache_ssl
    else
        msg info "No SSL setup (no cert files provided)"

        rm -f /etc/httpd/conf.d/wordpress-ssl.conf

        if [ -f /etc/httpd/conf.modules.d/00-ssl.conf ] ; then
            sed -i 's/.*\(LoadModule.*\)/#\1/' /etc/httpd/conf.modules.d/00-ssl.conf
        fi

        if [ -f /etc/httpd/conf.d/ssl.conf ] ; then
            mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.conf-disabled
        fi

    fi

    # fail if config is wrong
    msg info "Apache configtest..."
    apachectl configtest

    return $?
}

configure_wordpress()
{
    msg info "WordPress setup"

    rm -rf /var/www/html
    cp -a "$ONE_SERVICE_SETUP_DIR"/wordpress /var/www/html
    mkdir /var/www/html/wp-content/uploads

    mv /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

    sed -i \
        -e "s#^[[:space:]]*define([[:space:]]*'DB_NAME'.*#define('DB_NAME', '${ONEAPP_DB_NAME}');#" \
        -e "s#^[[:space:]]*define([[:space:]]*'DB_USER'.*#define('DB_USER', '${ONEAPP_DB_USER}');#" \
        -e "s#^[[:space:]]*define([[:space:]]*'DB_PASSWORD'.*#define('DB_PASSWORD', '${ONEAPP_DB_PASSWORD}');#" \
        /var/www/html/wp-config.php

    chown -R apache:apache /var/www/html/
    find /var/www/html -type d -exec chmod 750 '{}' \;
    find /var/www/html -type f -exec chmod 640 '{}' \;

    return 0
}

report_config()
{
    msg info "Credentials and config values are saved in: ${ONE_SERVICE_REPORT}"

    cat > "$ONE_SERVICE_REPORT" <<EOF
[DB connection info]
host     = localhost
database = ${ONEAPP_DB_NAME}

[DB root credentials]
username = root
password = ${ONEAPP_DB_ROOT_PASSWORD}

[DB wordpress credentials]
username = ${ONEAPP_DB_USER}
password = ${ONEAPP_DB_PASSWORD}

[Wordpress]
site_url = ${ONEAPP_SITE_HOSTNAME}
username = ${ONEAPP_ADMIN_USERNAME}
password = ${ONEAPP_ADMIN_PASSWORD}
EOF

    chmod 600 "$ONE_SERVICE_REPORT"
}

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

    # prepare db for wordpress
    msg info "Preparing WordPress database and passwords"
    mysql -u root -p"${ONEAPP_DB_ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS ${ONEAPP_DB_NAME};
GRANT ALL PRIVILEGES on ${ONEAPP_DB_NAME}.* to '${ONEAPP_DB_USER}'@'localhost' identified by '${ONEAPP_DB_PASSWORD}';
FLUSH PRIVILEGES;
EOF
}

check_wordpress_wizard()
{
    msg info "Checking WordPress variables..."

    [ -z "$ONEAPP_SITE_TITLE" ] && return 1
    [ -z "$ONEAPP_ADMIN_USERNAME" ] && return 1
    [ -z "$ONEAPP_ADMIN_PASSWORD" ] && return 1
    [ -z "$ONEAPP_ADMIN_EMAIL" ] && return 1

    return 0
}

run_wordpress_wizard()
{
    # install.php could give 503 for a while
    curl --retry 3 --retry-delay 1 --retry-max-time 10 \
        http://${ONEAPP_SITE_HOSTNAME}/wp-admin/install.php

    msg info "WordPress wizard..."

    msg info "Running the wizard"
    curl_output=$(curl "http://${ONEAPP_SITE_HOSTNAME}/wp-admin/install.php?step=2" \
        --data-urlencode "weblog_title=${ONEAPP_SITE_TITLE}"\
        --data-urlencode "user_name=$ONEAPP_ADMIN_USERNAME" \
        --data-urlencode "admin_email=$ONEAPP_ADMIN_EMAIL" \
        --data-urlencode "admin_password=$ONEAPP_ADMIN_PASSWORD" \
        --data-urlencode "admin_password2=$ONEAPP_ADMIN_PASSWORD" \
        --data-urlencode "pw_weak=1" | grep -i 'form-table install-success' || true)

    printf "\n\n"

    if echo "$curl_output" | grep -qi 'install-success' ; then
        msg info "Wizard installed WordPress successfully"
        return 0
    else
        msg warning "Wizard did not return expected output - feel free to examine"
        return 1
    fi
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
