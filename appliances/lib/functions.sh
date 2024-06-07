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

# args: "$@"
_parse_arguments()
{
    _ACTION=nil
    state=nil
    while [ -n "$1" ] ; do
        case "$state" in
            nil)
                case "$1" in
                    -h|--help|help)
                        _ACTION=help
                        state=done
                        ;;
                    install)
                        _ACTION=install
                        state=install
                        ;;
                    configure|bootstrap)
                        _ACTION="$1"
                        state=configure
                        ;;
                    *)
                        _ACTION=badargs
                        msg unknown "BAD USAGE: unknown argument: $1"
                        break
                        ;;
                esac
                ;;
            configure)
                case "$1" in
                    reconfigure)
                        ONE_SERVICE_RECONFIGURE=true
                        state=done
                        ;;
                    *)
                        _ACTION=badargs
                        msg unknown "BAD USAGE: unknown argument: $1"
                        break
                        ;;
                esac
                ;;
            install)
                ONE_SERVICE_VERSION="$1"
                state=done
                ;;
            done)
                _ACTION=badargs
                msg unknown "BAD USAGE: extraneous argument(s)"
                break
                ;;
        esac
        shift
    done
}

# args: "$0" "${@}"
_lock_or_fail()
{
    this_script="$1"
    if [ "${_SERVICE_LOCK}" != "$this_script" ] ; then
        exec env _SERVICE_LOCK="$this_script" flock -xn $this_script "$@"
    fi
}

_on_exit()
{
    # this is the exit handler - I want to clean up as much as I can
    set +e

    # first do whatever the service appliance needs to clean after itself
    service_cleanup

    # delete temporary working file(s)
    if [ -n "$_SERVICE_LOG_PIPE" ] ; then
        rm -f "$_SERVICE_LOG_PIPE"
    fi

    # exiting while the stage was interrupted - change status to failure
    _status=$(_get_current_service_result)
    case "$_status" in
        started)
            _set_service_status failure
            ;;
    esac

    # all done - delete pid file and exit
    rm -f "$ONE_SERVICE_PIDFILE"
}

_trap_exit()
{
    trap '_on_exit 2>/dev/null' INT QUIT TERM EXIT
}

_is_running()
{
    pid=$(_get_pid)

    if echo "$pid" | grep -q '^[0-9]\+$' ; then
        kill -0 $pid
        return $?
    fi

    return 1
}

_get_pid()
{
    if [ -f "$ONE_SERVICE_PIDFILE" ] ; then
        cat "$ONE_SERVICE_PIDFILE"
    fi
}

_write_pid()
{
    echo $$ > "$ONE_SERVICE_PIDFILE"
}

_get_service_status()
{
    if [ -f "$ONE_SERVICE_STATUS" ] ; then
        cat "$ONE_SERVICE_STATUS"
    fi
}

_get_current_service_step()
{
    _get_service_status | sed -n 's/^\(install\|configure\|bootstrap\)_.*/\1/p'
}

_get_current_service_result()
{
    _result=$(_get_service_status | sed -n 's/^\(install\|configure\|bootstrap\)_\(.*\)/\2/p')
    case "$_result" in
        started|success|failure)
            echo "$_result"
            ;;
    esac
}

# arg: install|configure|bootstrap [<yes/true>|
_check_service_status()
{
    _reconfigure="$2"

    case "$1" in
        install)
            case "$(_get_service_status)" in
                '')
                    # nothing was done so far
                    return 0
                    ;;
                install_success)
                    msg warning "Installation was already done - skip"
                    return 1
                    ;;
                install_started)
                    msg error "Installation was probably interrupted - abort"
                    _set_service_status failure
                    exit 1
                    ;;
                install_failure)
                    msg error "Last installation attempt failed - abort"
                    exit 1
                    ;;
                *)
                    msg error "Install step cannot be run - go check: ${ONE_SERVICE_STATUS}"
                    exit 1
                    ;;
            esac
            ;;
        configure)
            case "$(_get_service_status)" in
                '')
                    # nothing was done so far - missing install
                    msg error "Cannot proceed with configuration - missing installation step"
                    exit 1
                    ;;
                install_success)
                    # installation was successfull - can continue
                    return 0
                    ;;
                configure_success)
                    if is_true _reconfigure ; then
                        msg info "Starting reconfiguration of the service"
                        return 0
                    else
                        msg warning "Configuration was already done - skip"
                        return 1
                    fi
                    ;;
                configure_started)
                    if is_true _reconfigure ; then
                        msg info "Starting reconfiguration of the service"
                        return 0
                    else
                        msg error "Configuration was probably interrupted - abort"
                        _set_service_status failure
                        exit 1
                    fi
                    ;;
                configure_failure)
                    if is_true _reconfigure ; then
                        msg info "Starting reconfiguration of the service"
                        return 0
                    else
                        msg error "Last configuration attempt failed - abort"
                        exit 1
                    fi
                    ;;
                bootstrap*)
                    if is_true _reconfigure ; then
                        msg info "Starting reconfiguration of the service"
                        return 0
                    else
                        msg error "Configure step will not run since the appliance is set as non-reconfigurable. Chech the value of ONE_SERVICE_RECONFIGURABLE"
                        exit 1
                    fi
                    ;;
                *)
                    msg error "Configure step cannot be run - go check: ${ONE_SERVICE_STATUS}"
                    exit 1
                    ;;
            esac
            ;;
        bootstrap)
            case "$(_get_service_status)" in
                '')
                    # nothing was done so far - missing install
                    msg error "Cannot proceed with bootstrapping - missing installation step"
                    exit 1
                    ;;
                configure_success)
                    # configuration was successfull - can continue
                    return 0
                    ;;
                bootstrap_success)
                    if is_true _reconfigure ; then
                        msg info "Redo bootstrap of the service"
                        return 0
                    else
                        msg warning "Bootstrap was already done - skip"
                        return 1
                    fi
                    ;;
                bootstrap_started)
                    if is_true _reconfigure ; then
                        msg info "Redo bootstrap of the service"
                        return 0
                    else
                        msg error "Bootstrap was probably interrupted - abort"
                        _set_service_status failure
                        exit 1
                    fi
                    ;;
                bootstrap_failure)
                    if is_true _reconfigure ; then
                        msg info "Redo bootstrap of the service"
                        return 0
                    else
                        msg error "Last bootstrap attempt failed - abort"
                        exit 1
                    fi
                    ;;
                *)
                    msg error "Bootstrap step cannot be run - go check: ${ONE_SERVICE_STATUS}"
                    exit 1
                    ;;
            esac
            ;;
    esac

    msg error "THIS SHOULD NOT HAPPEN!"
    msg unknown "Possibly a bug, wrong usage, action etc."
    exit 1
}

# arg: install|configure|bootstrap|success|failure
_set_service_status()
{
    _status="$1"
    case "$_status" in
        install|configure|bootstrap)
            echo ${_status}_started > "$ONE_SERVICE_STATUS"
            _set_motd "$_status" started
            ;;
        success|failure)
            _step=$(_get_current_service_step)
            echo ${_step}_${_status} > "$ONE_SERVICE_STATUS"
            _set_motd "$_step" "$_status"
            ;;
        *)
            msg unknown "THIS SHOULD NOT HAPPEN!"
            msg unknown "Possibly a bug, wrong usage, action etc."
            exit 1
            ;;
    esac
}

_print_logo()
{
    cat > ${ONE_SERVICE_MOTD} <<EOF

    ___   _ __    ___
   / _ \ | '_ \  / _ \   OpenNebula Service Appliance
  | (_) || | | ||  __/
   \___/ |_| |_| \___|

EOF
}

#args: install|configure|bootstrap started|success|failure
_set_motd()
{
    _step="$1"
    _status="$2"

    case "$_step" in
        install)
            _line="1/3 Installation"
            ;;
        configure)
            _line="2/3 Configuration"
            ;;
        bootstrap)
            _line="3/3 Bootstrap"
            ;;
    esac

    _print_logo
    case "$_status" in
        started)
            cat >> ${ONE_SERVICE_MOTD} <<EOF
 $_line step is in progress...

 * * * * * * * *
 * PLEASE WAIT *
 * * * * * * * *

EOF
            ;;
        success)
            if [ "$_step" = bootstrap ] ; then
                cat >> ${ONE_SERVICE_MOTD} <<EOF
 All set and ready to serve 8)

EOF
            else
                cat >> ${ONE_SERVICE_MOTD} <<EOF
 $_line step was successfull.

EOF
            fi
            ;;
        failure)
            cat >> ${ONE_SERVICE_MOTD} <<EOF
 $_line step failed.

 * * * * * * * * * *
 * APPLIANCE ERROR *
 * * * * * * * * * *

 Read documentation and try to redeploy!

EOF
            ;;
    esac
}

# arg: <log_filename>
_start_log()
{
    _logfile="$1"
    _SERVICE_LOG_PIPE="$ONE_SERVICE_LOGDIR"/one_service_log.pipe

    # create named pipe
    mknod "$_SERVICE_LOG_PIPE" p

    # connect tee to the pipe and let it write to the log and screen
    tee <"$_SERVICE_LOG_PIPE" -a "$_logfile" &

    # save stdout to fd 3 and force shell to write to the pipe
    exec 3>&1 >"$_SERVICE_LOG_PIPE"
}

_end_log()
{
    # restore stdout for the shell and close fd 3
    exec >&3 3>&-
}
