#!/usr/bin/env bash

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


# shellcheck disable=SC2086
true


# args: <type> <message>
msg()
{
    msg_type="$1"
    shift

    case "$msg_type" in
        info)
            printf "[%s] => " "$(date)"
            echo 'INFO:' "$@"
            ;;
        debug)
            printf "[%s] => " "$(date)" >&2
            echo 'DEBUG:' "$@" >&2
            ;;
        warning)
            printf "[%s] => " "$(date)" >&2
            echo 'WARNING [!]:' "$@" >&2
            ;;
        error)
            printf "[%s] => " "$(date)" >&2
            echo 'ERROR [!!]:' "$@" >&2
            return 1
            ;;
        *)
            printf "[%s] => " "$(date)" >&2
            echo 'UNKNOWN [?!]:' "$@" >&2
            return 2
            ;;
    esac
    return 0
}

# arg: <length>
gen_password()
{
    pw_length="${1:-16}"
    new_pw=''

    while true ; do
        if command -v pwgen >/dev/null ; then
            new_pw=$(pwgen -s "${pw_length}" 1)
            break
        elif command -v openssl >/dev/null ; then
            new_pw="${new_pw}$(openssl rand -base64 ${pw_length} | tr -dc '[:alnum:]')"
        else
            new_pw="${new_pw}$(head /dev/urandom | tr -dc '[:alnum:]')"
        fi
        # shellcheck disable=SC2000
        [ "$(echo $new_pw | wc -c)" -ge "$pw_length" ] && break
    done

    echo "$new_pw" | cut -c1-${pw_length}
}

# arg: <ipv4 address>
is_ipv4_address()
{
    echo "$1" | grep '^[0-9.]*$' | awk '
    BEGIN {
        FS = ".";
        octet = 0;
    }
    {
        for(i = 1; i <= NF; i++)
            if (($i >= 0) && ($i <= 255))
                octet++;
    }
    END {
        if (octet == 4)
            exit 0;
        else
            exit 1;
    }'
}

get_local_ip()
{
    extif=$(ip r | awk '{if ($1 == "default") print $5;}')
    local_ip=$(ip a show dev "$extif" | \
        awk '{if ($1 == "inet") print $2;}' | sed -e '/^127\./d' -e 's#/.*##')

    echo "${local_ip:-127.0.0.1}"
}

# arg: <ip>
is_my_ip()
(
    _ip="$1"

    _local_ips=$(ip a | \
        sed -n 's#^[[:space:]]*inet[[:space:]]\+\([^/[:space:]]\+\)[/[:space:]].*#\1#p')

    for _local_ip in ${_local_ips} ; do
        if [ "$_ip" = "$_local_ip" ] ; then
            return 0
        fi
    done

    return 1
)

# returns an netmask in the old notation, eg.: 255.255.255.255
# arg: <cidr>
#
# NOTE: shamelessly copied from here:
# https://forums.gentoo.org/viewtopic-t-888736-start-0.html
cidr_to_mask ()
(
   # Number of args to shift, 255..255, first non-255 byte, zeroes
   set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
   [ $1 -gt 1 ] && shift $1 || shift
   echo ${1-0}.${2-0}.${3-0}.${4-0}
)

# Gets the network part of an IP
# arg: <ip> <mask>
get_network_ip()
(
    awk -v ip="$1" -v mask="$2" 'END {
        split(ip, ip_b, "."); split(mask, mask_b, ".");
        for (i=1; i<=4; ++i) x = x "." and(ip_b[i], mask_b[i]);
        sub(/^./, "", x); print x; }' </dev/null
)

# returns ip of an interface which has route to ip/cidr from argument
# arg: <plain ipv4 or address in cidr format>
#
# NOTE: this originally never worked properly:
# https://gitlab.com/openconnect/vpnc-scripts/-/merge_requests/5
#
# The fix is to first find the network address.
get_gw_ip()
(
    _ip=$(echo "$1" | awk 'BEGIN{FS="/"}{print $1;}')
    _mask=$(echo "$1" | awk 'BEGIN{FS="/"}{print $2;}')

    if echo "$_mask" | grep -q '^[0-9][0-9]*$' && [ "$_mask" -le 32 ] ; then
        # ip had cidr prefix - we will find network ip
        _mask=$(cidr_to_mask "$_mask")
        _ip=$(get_network_ip "$_ip" "$_mask")
    elif [ -n "$_mask" ] ; then
        # netmask is garbage
        return 1
    fi

    ip r g "$_ip" 2>/dev/null | awk '
        {
            for(i = 1; i <= NF; i++)
            {
                if ($i == "src")
                {
                    print $(i + 1);
                    exit 0;
                }
            }
        }
    '
)

# it will create a new hostname from an ip address, but only if the current one
# is just localhost and in that case it will also prints it on the stdout
# arg: [<name>]
generate_hostname()
(
    if [ "$(hostname -s)" = localhost ] ; then
        if [ -n "$1" ] ; then
            _new_hostname="$(echo $1 | tr -d '[:space:]' | tr '.' '-')"
        else
            _new_hostname="one-$(get_local_ip | tr '.' '-')"
        fi
        hostname "$_new_hostname"
        hostname > /etc/hostname
        hostname -s
    fi
)

# show default help based on the ONE_SERVICE_PARAMS
# service_help in appliance.sh may override this function
default_service_help()
{
    echo "USAGE: "

    for _command in 'help' 'install' 'configure' 'bootstrap'; do
        echo " $(basename "$0") ${_command}"

        case "${_command}" in
            help)       echo '  Prints this help' ;;
            install)    echo '  Installs service' ;;
            configure)  echo '  Configures service via contextualization or defaults' ;;
            bootstrap)  echo '  Bootstraps service via contextualization' ;;
        esac

        local _index=0
        while [ -n "${ONE_SERVICE_PARAMS[${_index}]}" ]; do
            local _name="${ONE_SERVICE_PARAMS[${_index}]}"
            local _type="${ONE_SERVICE_PARAMS[$((_index + 1))]}"
            local _desc="${ONE_SERVICE_PARAMS[$((_index + 2))]}"
            local _input="${ONE_SERVICE_PARAMS[$((_index + 3))]}"
            _index=$((_index + 4))

            if [ "${_command}" = "${_type}" ]; then
                if [ -z "${_input}" ]; then
                    echo -n '    '
                else
                    echo -n '  * '
                fi

                printf "%-25s - %s\n" "${_name}" "${_desc}"
            fi
        done

        echo
    done

    echo 'Note: (*) variables are provided to the user via USER_INPUTS'
}

#TODO: more or less duplicate to common.sh/service_help()
params2md()
{
    local _command=$1

    local _index=0
    local _count=0
    while [ -n "${ONE_SERVICE_PARAMS[${_index}]}" ]; do
        local _name="${ONE_SERVICE_PARAMS[${_index}]}"
        local _type="${ONE_SERVICE_PARAMS[$((_index + 1))]}"
        local _desc="${ONE_SERVICE_PARAMS[$((_index + 2))]}"
        local _input="${ONE_SERVICE_PARAMS[$((_index + 3))]}"
        _index=$((_index + 4))

        if [ "${_command}" = "${_type}" ] && [ -n "${_input}" ]; then
            # shellcheck disable=SC2016
            printf '* `%s` - %s\n' "${_name}" "${_desc}"
            _count=$((_count + 1))
        fi
    done

    if [ "${_count}" -eq 0 ]; then
        echo '* none'
    fi
}

create_one_service_metadata()
{
    # shellcheck disable=SC2001
    cat >"${ONE_SERVICE_METADATA}" <<EOF
---
name: "${ONE_SERVICE_NAME}"
version: "${ONE_SERVICE_VERSION}"
build: ${ONE_SERVICE_BUILD}
short_description: "${ONE_SERVICE_SHORT_DESCRIPTION}"
description: |
$(echo "${ONE_SERVICE_DESCRIPTION}" | sed -e 's/^\(.\)/  \1/')
EOF

}

# args: <pkg> [<version>]
# use in pipe with yum -y --showduplicates list <pkg>
# yum version follows these rules:
#   starting at the first colon (:) and up to the first hyphen (-)
# example:
#   3:18.09.1-3.el7 -> 18.09.1
yum_pkg_filter()
{
    _pkg="$1"
    _version="$2"

    awk -v pkg="$_pkg" '{if ($1 ~ "^" pkg) print $2;}' | \
    sed -e 's/^[^:]*://' -e 's/-.*//' | \
    if [ -n "$_version" ] ; then
        # only the correct versions
        awk -v version="$_version" '
        {
            if ($1 ~ "^" version)
                print $1;
        }'
    else
        cat
    fi
}

# arg: <word> <list of words>
is_in_list()
{
    _word="$1"
    shift

    # shellcheck disable=SC2048
    for i in $* ; do
        if [ "$_word" = "$i" ] ; then
            return 0
        fi
    done

    return 1
}

# arg: <variable name>
is_true()
{
    _value=$(eval echo "\$${1}" | tr '[:upper:]' '[:lower:]')
    case "$_value" in
        1|true|yes|y)
            return 0
            ;;
    esac

    return 1
}

# arg: [context file]
save_context_base64()
{
    _context_file="${1:-$ONE_SERVICE_CONTEXTFILE}"

    msg info "Store current context in the file: ${_context_file}"
    _context_vars=$(set | sed -n 's/^\(ONEAPP_[^=[:space:]]\+\)=.*/\1/p')

    if ! [ -f "$_context_file" ] ; then
        echo '{}' > "$_context_file"
    fi

    _old_context=$(cat "$_context_file")

    {
        echo "$_old_context"

        for _context_var in ${_context_vars} ; do
            _value=$(eval "printf \"\$${_context_var}\"")
            echo '{}' | jq -S --arg val "$_value" ". + {\"${_context_var}\": \$val | @base64}"
        done
    } | jq -sS add > "$_context_file"
}

# arg: [context file]
save_context()
{
    _context_file="${1:-$ONE_SERVICE_CONTEXTFILE}"

    msg info "Store current context in the file: ${_context_file}"

    "${ONE_SERVICE_SETUP_DIR}/bin/context-helper" \
        update "${_context_file}"
}

# arg: [context file]
load_context()
{
    _context_file="${1:-$ONE_SERVICE_CONTEXTFILE}"

    if ! [ -f "${_context_file}" ] ; then
        msg info "Create empty context file: ${_context_file}"
        echo '{}' > "${_context_file}"
        return 0
    fi

    msg info "Load last context from the file: ${_context_file}"

    _vars=$("${ONE_SERVICE_SETUP_DIR}/bin/context-helper" \
        -t names load "${_context_file}")

    for i in $_vars ; do
        _value=$(get_value_from_context_file "${i}" "${_context_file}")
        eval "${i}=\$(echo \"\$_value\")"
        # shellcheck disable=SC2163
        export "${i}"
    done
}

# arg: [context file]
get_changed_context_vars()
{
    _context_file="${1:-$ONE_SERVICE_CONTEXTFILE}"

    if ! [ -f "${_context_file}" ] ; then
        return 0
    fi

    "${ONE_SERVICE_SETUP_DIR}/bin/context-helper" \
        -t names compare "${_context_file}"
}

# arg: <var name> [<context file>]
get_value_from_context_file()
{
    _var="$1"
    _context_file="${2:-$ONE_SERVICE_CONTEXTFILE}"

    [ -z "${_var}" ] && return 1

    jq -cr ".${_var}" < "${_context_file}"
}

# arg: <variable-name>
is_context_variable_updated()
{
    _varname="$1"

    for v in $(get_changed_context_vars "${ONE_SERVICE_CONTEXTFILE}") ; do
        if [ "$v" = "${_varname}" ] ; then
            # variable has been updated
            return 0
        fi
    done

    return 1
}

# arg: <pidfile>
check_pidfile()
{
    _pidfile="$1"

    if [ -f "${_pidfile}" ] ; then
        _pid=$(grep '^[0-9]\+$' "${_pidfile}")
    else
        _pid=
    fi

    if [ -n "${_pid}" ] ; then
        kill -0 ${_pid}
        return $?
    fi

    return 1
}

# arg: <pidfile>
wait_for_pidfile()
{
    _pidfile="$1"
    _timeout=60 # we wait at most one minute...

    while [ "$_timeout" -gt 0 ]; do
        # we wait for the pidfile to emerge...
        if [ -f "$_pidfile" ] ; then
            _pid=$(cat "$_pidfile")
            # we retry until the pid in pidfile is a number...
            if echo "$_pid" | grep -q '^[0-9]\+$' ; then
                # the pid must be stable for 3 seconds...
                _check_time=3
                while [ "$_check_time" -gt 0 ] ; do
                    sleep 1s
                    if kill -0 "$_pid" ; then
                        _check_time=$(( _check_time - 1 ))
                    else
                        break
                    fi
                done
                if [ "$_check_time" -eq 0 ] ; then
                    # we succeeded - we have valid pid...
                    break
                fi
            fi
        fi

        sleep 1s
        _timeout=$(( _timeout - 1 ))
    done
}

wait_for_file()
(
    _timeout=60 # we wait at most one minute...

    while [ "$_timeout" -gt 0 ] ; do
        if [ -e "$1" ] ; then
            return 0
        fi

        sleep 1s
        _timeout=$(( _timeout - 1 ))
    done

    return 1
)

