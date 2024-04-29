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

get_local_ip()
{
    extif=$(ip r | awk '{if ($1 == "default") print $5;}')
    local_ip=$(ip a show dev "$extif" | \
        awk '{if ($1 == "inet") print $2;}' | sed -e '/^127\./d' -e 's#/.*##')

    echo "${local_ip:-127.0.0.1}"
}

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