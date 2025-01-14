# -------------------------------------------------------------------------- #
# Copyright 2002-2021, OpenNebula Project, OpenNebula Systems                #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

# Original work by:

#################################################################
##### Windows Powershell Script to configure OpenNebula VMs #####
#####   Created by andremonteiro@ua.pt and tsbatista@ua.pt  #####
#####        DETI/IEETA Universidade de Aveiro 2011         #####
#################################################################

################################################################################
# Functions
################################################################################

function logmsg($message) {
    # powershell 4 does not automatically add newline in the transcript so we
    # workaround it by adding it explicitly and using the NoNewline argument
    # we ensure that it will not be added twice
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm K')] $message`r`n" -NoNewline
}

function logsuccess {
    logmsg "  ... Success"
}
function logfail {
    logmsg "  ... Failed"
}

function getContext($file) {

    # TODO: Improve regexp for multiple SSH keys on SSH_PUBLIC_KEY
    $context = @{}
    switch -regex -file $file {
        "^([^=]+)='(.+?)'$" {
            $name, $value = $matches[1..2]
            $context[$name] = $value
        }
    }
    return $context
}

function envContext($context) {
    ForEach ($h in $context.GetEnumerator()) {
        $name = "Env:" + $h.Name
        Set-Item $name $h.Value
    }
}

function contextChanged($file, $last_checksum) {
    $new_checksum = Get-FileHash -Algorithm SHA256 $file
    $ret = $last_checksum.Hash -ne $new_checksum.Hash
    return $ret
}

function waitForContext($checksum) {
    # This object will be set and returned at the end
    $contextPaths = New-Object PsObject -Property @{
        contextScriptPath     = $null
        contextPath           = $null
        contextDrive          = $null
        contextLetter         = $null
        contextInitScriptPath = $null
    }

    # How long to wait before another poll (in seconds)
    $sleep = 30

    do {

        # Reset the contextPath
        $contextPaths.contextPath = ""

        # Get all drives and select only the one that has "CONTEXT" as a label
        $contextPaths.contextDrive = Get-WMIObject Win32_Volume | Where-Object { $_.Label -eq "CONTEXT" }

        if ($contextPaths.contextDrive) {

            # At this point we can obtain the letter of the contextDrive
            $contextPaths.contextLetter = $contextPaths.contextDrive.Name
            $contextPaths.contextPath = $contextPaths.contextLetter + "context.sh"
            $contextPaths.contextInitScriptPath = $contextPaths.contextLetter
        }
        else {

            # Try the VMware API
            foreach ($pf in ${env:ProgramFiles}, ${env:ProgramFiles(x86)}, ${env:ProgramW6432}) {
                $vmtoolsd = "${pf}\VMware\VMware Tools\vmtoolsd.exe"
                if (Test-Path $vmtoolsd) {
                    break
                }
            }

            $vmwareContext = ""
            if (Test-Path $vmtoolsd) {
                $vmwareContext = & $vmtoolsd --cmd "info-get guestinfo.opennebula.context" | Out-String
            }

            if ("$vmwareContext" -ne "") {
                [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($vmwareContext)) | Out-File "$ctxDir\context.sh" "UTF8"
                $contextPaths.contextLetter = $env:SystemDrive + "\"
                $contextPaths.contextPath = "$ctxDir\context.sh"
                $contextPaths.contextInitScriptPath = "$ctxDir\.init-scripts\"

                if (!(Test-Path $contextPaths.contextInitScriptPath)) {
                    mkdir $contextPaths.contextInitScriptPath
                }

                # Look for INIT_SCRIPTS
                $fileId = 0
                while ($true) {
                    $vmwareInitFilename = & $vmtoolsd --cmd "info-get guestinfo.opennebula.file.${fileId}" | Select-Object -First 1 | Out-String

                    $vmwareInitFilename = $vmwareInitFilename.Trim()

                    if ($vmwareInitFilename -eq "") {
                        # no file found
                        break
                    }

                    $vmwareInitFileContent64 = & $vmtoolsd --cmd "info-get guestinfo.opennebula.file.${fileId}" | Select-Object -Skip 1 | Out-String

                    # Sanitize the filenames (drop any path from them and instead use our directory)
                    $vmwareInitFilename = $contextPaths.contextInitScriptPath + [System.IO.Path]::GetFileName("$vmwareInitFilename")

                    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($vmwareInitFileContent64)) | Out-File "${vmwareInitFilename}" "UTF8"

                    $fileId++
                }
            }

        }

        # Terminate the wait-loop only when context.sh is found and changed
        if (![string]::IsNullOrEmpty($contextPaths.contextPath) -and (Test-Path $contextPaths.contextPath)) {

            # Context must differ
            if (contextChanged $contextPaths.contextPath $checksum) {
                Break
            }
        }

        cleanup $contextPaths

        Write-Host "`r`n" -NoNewline
        Start-Sleep -Seconds $sleep
    } while ($true)

    # make a copy of the context.sh in the case another event would happen and
    # trigger a new context.sh while still working on the previous one which
    # would result in a mismatched checksum...
    $contextPaths.contextScriptPath = "$ctxDir\.opennebula-context.sh"
    Copy-Item -Path $contextPaths.contextPath -Destination $contextPaths.contextScriptPath -Force

    return $contextPaths
}

function addLocalUser($context) {
    # Create new user
    $username = $context["USERNAME"]
    $password = $context["PASSWORD"]
    $password64 = $context["PASSWORD_BASE64"]

    If ($password64) {
        $password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password64))
    }

    if ($username -Or $password) {

        if ($null -eq $username) {
            # ATTENTION - Language/Regional settings have influence on the naming
            #             of this user. Use the User SID instead (S-1-5-21domain-500)
            $username = (Get-WmiObject -Class "Win32_UserAccount" |
                Where-Object { $_.SID -like "S-1-5-21[0-9-]*-500" } |
                Select-Object -ExpandProperty Name |
                Get-Unique -AsString)
        }

        logmsg "* Creating Account for $username"

        $ADSI = [adsi]$ConnectionString

        if (!([ADSI]::Exists("WinNT://$computerName/$username"))) {
            # User does not exist, Create the User
            logmsg "- Creating account"
            $user = $ADSI.Create("user", $username)
            $user.setPassword($password)
            $user.SetInfo()
        }
        else {
            # User exists, Set Password
            logmsg "- Setting Password"
            $admin = [ADSI]"WinNT://$env:computername/$username"
            $admin.psbase.invoke("SetPassword", $password)
        }

        # Set Password to Never Expire
        logmsg "- Setting password to never expire"
        $admin = [ADSI]"WinNT://$env:computername/$username"
        $admin.UserFlags.value = $admin.UserFlags.value -bor 0x10000
        $admin.CommitChanges()

        # Add user to local Administrators
        # ATTENTION - Language/Regional settings have influence on the naming
        #             of this group. Use the Group SID instead (S-1-5-32-544)
        $groups = (Get-WmiObject -Class "Win32_Group" |
            Where-Object { $_.SID -like "S-1-5-32-544" } |
            Select-Object -ExpandProperty Name)

        ForEach ($grp in $groups) {

            # Make sure the Group exists
            If ([ADSI]::Exists("WinNT://$computerName/$grp,group")) {

                # Check if the user is a Member of the Group
                $group = [ADSI] "WinNT://$computerName/$grp,group"
                $members = @($group.psbase.Invoke("Members"))

                $memberNames = @()
                $members | ForEach-Object {
                    # https://p0w3rsh3ll.wordpress.com/2016/06/14/any-documented-adsi-changes-in-powershell-5-0/
                    $memberNames += ([ADSI]$_).psbase.InvokeGet('Name')
                }

                If (-Not ($memberNames -Contains $username)) {

                    # Make sure the user exists, again
                    if ([ADSI]::Exists("WinNT://$computerName/$username")) {

                        # Add the user
                        logmsg "- Adding to $grp"
                        $group.Add("WinNT://$computerName/$username")
                    }
                }
            }
        }
    }
    Write-Host "`r`n" -NoNewline
}

function configureNetwork($context) {

    # Get the NIC in the Context
    $nicIds = ($context.Keys | Where-Object { $_ -match '^ETH\d+_MAC$' } | ForEach-Object { $_ -replace '(^ETH|_MAC$)', '' } | Sort-Object -Unique)

    $nicId = 0

    foreach ($nicId in $nicIds) {
        $nicPrefix = "ETH" + $nicId + "_"

        $method = $context[$nicPrefix + 'METHOD']
        $ip = $context[$nicPrefix + 'IP']
        $netmask = $context[$nicPrefix + 'MASK']
        $mac = $context[$nicPrefix + 'MAC']
        $dns = (($context[$nicPrefix + 'DNS'] -split " " | Where-Object { $_ -match '^(([0-9]*).?){4}$' }) -join ' ')
        $dns6 = (($context[$nicPrefix + 'DNS'] -split " " | Where-Object { $_ -match '^(([0-9A-F]*):?)*$' }) -join ' ')
        $dnsSuffix = $context[$nicPrefix + 'SEARCH_DOMAIN']
        $gateway = $context[$nicPrefix + 'GATEWAY']
        $network = $context[$nicPrefix + 'NETWORK']
        $mtu = $context[$nicPrefix + 'MTU']
        $metric = $context[$nicPrefix + 'METRIC']

        $ip6Method = $context[$nicPrefix + 'IP6_METHOD']
        $ip6 = $context[$nicPrefix + 'IP6']
        $ip6ULA = $context[$nicPrefix + 'IP6_ULA']
        $ip6Prefix = $context[$nicPrefix + 'IP6_PREFIX_LENGTH']
        $ip6Gw = $context[$nicPrefix + 'IP6_GATEWAY']
        $ip6Metric = $context[$nicPrefix + 'IP6_METRIC']

        $mac = $mac.ToUpper()
        if (!$netmask) {
            $netmask = "255.255.255.0"
        }
        if (!$ip6Prefix) {
            $ip6Prefix = "64"
        }
        if (!$ip6Gw) {
            # Backward compatibility, new context parameter
            # ETHx_IP6_GATEWAY introduced since 6.2
            $ip6Gw = $context[$nicPrefix + 'GATEWAY6']
        }
        if (!$ip6Metric) {
            $ip6Metric = $metric
        }
        if (!$network) {
            $network = $ip -replace "\.[^.]+$", ".0"
        }
        if ($nicId -eq 0 -and !$gateway) {
            $gateway = $ip -replace "\.[^.]+$", ".1"
        }

        # default NIC configuration methods
        if (!$method) {
            $method = 'static'
        }
        if (!$ip6Method) {
            $ip6Method = $method
        }

        # Load the NIC Configuration Object
        $nic = $false
        $retry = 30
        do {
            $retry--
            Start-Sleep -s 1
            $nic = Get-WMIObject Win32_NetworkAdapterConfiguration | `
                Where-Object { $_.IPEnabled -eq "TRUE" -and $_.MACAddress -eq $mac }
        } while (!$nic -and $retry)

        If (!$nic) {
            logmsg ("* Configuring Network Settings: " + $mac)
            logmsg ("  ... Failed: Interface with MAC not found")
            Continue
        }

        # We need the connection ID (i.e. "Local Area Connection",
        # which can be discovered from the NetworkAdapter object
        $na = Get-WMIObject Win32_NetworkAdapter | `
            Where-Object { $_.deviceId -eq $nic.index }

        If (!$na) {
            logmsg ("* Configuring Network Settings: " + $mac)
            logmsg ("  ... Failed: Network Adapter not found")
            Continue
        }

        logmsg ("* Configuring Network Settings: " + $nic.Description.ToString())

        # Flag to indicate if any IPv4/6 configuration was placed
        $set_ip_conf = $false

        # IPv4 Configuration Methods
        Switch -Regex ($method) {
            '^\s*static\s*$' {
                if ($ip) {
                    # Release the DHCP lease, will fail if adapter not DHCP Configured
                    logmsg "- Release DHCP Lease"
                    $ret = $nic.ReleaseDHCPLease()
                    If ($ret.ReturnValue) {
                        logmsg ("  ... Failed: " + $ret.ReturnValue.ToString())
                    }
                    Else {
                        logmsg "  ... Success"
                    }

                    # set static IP address and retry for few times if there was a problem
                    # with acquiring write lock (2147786788) for network configuration
                    # https://msdn.microsoft.com/en-us/library/aa390383(v=vs.85).aspx
                    logmsg "- Set Static IP"
                    $retry = 10
                    do {
                        $retry--
                        Start-Sleep -s 1
                        $ret = $nic.EnableStatic($ip , $netmask)
                    } while ($ret.ReturnValue -eq 2147786788 -and $retry)
                    If ($ret.ReturnValue) {
                        logmsg ("  ... Failed: " + $ret.ReturnValue.ToString())
                    }
                    Else {
                        logmsg "  ... Success"
                    }

                    # Set IPv4 MTU
                    if ($mtu) {
                        logmsg "- Set MTU: ${mtu}"
                        netsh interface ipv4 set interface $nic.InterfaceIndex mtu=$mtu

                        If ($?) {
                            logmsg "  ... Success"
                        }
                        Else {
                            logmsg "  ... Failed"
                        }
                    }

                    # Set the Gateway
                    if ($gateway) {
                        if ($metric) {
                            logmsg "- Set Gateway with metric"
                            $ret = $nic.SetGateways($gateway, $metric)
                        }
                        Else {
                            logmsg "- Set Gateway"
                            $ret = $nic.SetGateways($gateway)
                        }

                        If ($ret.ReturnValue) {
                            logmsg ("  ... Failed: " + $ret.ReturnValue.ToString())
                        }
                        Else {
                            logmsg "  ... Success"
                        }
                    }

                    # Set DNS servers
                    If ($dns) {
                        $dnsServers = $dns -split " "

                        # DNS Server Search Order
                        logmsg "- Set DNS Server Search Order"
                        $ret = $nic.SetDNSServerSearchOrder($dnsServers)
                        If ($ret.ReturnValue) {
                            logmsg ("  ... Failed: " + $ret.ReturnValue.ToString())
                        }
                        Else {
                            logmsg "  ... Success"
                        }

                        # Set Dynamic DNS Registration
                        logmsg "- Set Dynamic DNS Registration"
                        $ret = $nic.SetDynamicDNSRegistration("TRUE")
                        If ($ret.ReturnValue) {
                            logmsg ("  ... Failed: " + $ret.ReturnValue.ToString())
                        }
                        Else {
                            logmsg "  ... Success"
                        }

                        # WINS Addresses
                        # $nic.SetWINSServer($DNSServers[0], $DNSServers[1])
                    }

                    # Set DNS domain/search order
                    if ($dnsSuffix) {
                        $dnsSuffixes = $dnsSuffix -split " "

                        # Set DNS Suffix Search Order
                        logmsg "- Set DNS Suffix Search Order"
                        $ret = ([WMIClass]"Win32_NetworkAdapterConfiguration").SetDNSSuffixSearchOrder(($dnsSuffixes))
                        If ($ret.ReturnValue) {
                            logmsg ("  ... Failed: " + $ret.ReturnValue.ToString())
                        }
                        Else {
                            logmsg "  ... Success"
                        }

                        # Set Primary DNS Domain
                        logmsg "- Set Primary DNS Domain"
                        $ret = $nic.SetDNSDomain($dnsSuffixes[0])
                        If ($ret.ReturnValue) {
                            logmsg ("  ... Failed: " + $ret.ReturnValue.ToString())
                        }
                        Else {
                            logmsg "  ... Success"
                        }
                    }

                    $set_ip_conf = $true
                }
                else {
                    logmsg "- No static IPv4 configuration provided, skipping"
                }
            }

            '^\s*dhcp\s*$' {
                # Enable DHCP
                logmsg "- Enable DHCP"
                $ret = $nic.EnableDHCP()
                # TODO: 1 ... Successful completion, reboot required
                If ($ret.ReturnValue) {
                    logmsg ("  ... Failed: " + $ret.ReturnValue.ToString())
                }
                Else {
                    logmsg "  ... Success"
                }

                # Set IPv4 MTU
                if ($mtu) {
                    logmsg "- Set MTU: ${mtu}"
                    netsh interface ipv4 set interface $nic.InterfaceIndex mtu=$mtu

                    If ($?) {
                        logmsg "  ... Success"
                    }
                    Else {
                        logmsg "  ... Failed"
                    }
                }

                $set_ip_conf = $true
            }

            '\s*skip\s*$' {
                logmsg "- Skipped IPv4 configuration as requested in method (${nicPrefix}METHOD=${method})"
            }

            Default {
                logmsg "- Unknown IPv4 method (${nicPrefix}METHOD=${method}), skipping configuration"
            }
        }

        # IPv6 Configuration Methods
        Switch -Regex ($ip6Method) {
            '^\s*static\s*$' {
                if ($ip6) {
                    enableIPv6
                    disableIPv6Privacy

                    # Disable router discovery
                    logmsg "- Disable IPv6 router discovery"
                    netsh interface ipv6 set interface $na.NetConnectionId `
                        advertise=disabled routerdiscover=disabled | Out-Null

                    If ($?) {
                        logmsg "  ... Success"
                    }
                    Else {
                        logmsg "  ... Failed"
                    }

                    # Remove old IPv6 addresses
                    logmsg "- Removing old IPv6 addresses"
                    if (Get-Command Remove-NetIPAddress -ErrorAction SilentlyContinue) {
                        # Windows 8.1 and Server 2012 R2 and up
                        # we want to remove everything except the link-local address
                        Remove-NetIPAddress -InterfaceAlias $na.NetConnectionId `
                            -AddressFamily IPv6 -Confirm:$false `
                            -PrefixOrigin Other, Manual, Dhcp, RouterAdvertisement `
                            -errorAction SilentlyContinue

                        If ($?) {
                            logmsg "  ... Success"
                        }
                        Else {
                            logmsg "  ... Nothing to do"
                        }
                    }
                    Else {
                        logmsg "  ... Not implemented"
                    }

                    # Set IPv6 Address
                    logmsg "- Set IPv6 Address"
                    netsh interface ipv6 add address $na.NetConnectionId $ip6/$ip6Prefix
                    If ($? -And $ip6ULA) {
                        netsh interface ipv6 add address $na.NetConnectionId $ip6ULA/64
                    }

                    If ($?) {
                        logmsg "  ... Success"
                    }
                    Else {
                        logmsg "  ... Failed"
                    }

                    # Set IPv6 Gateway
                    if ($ip6Gw) {
                        if ($ip6Metric) {
                            logmsg "- Set IPv6 Gateway with metric"
                            netsh interface ipv6 add route ::/0 $na.NetConnectionId $ip6Gw metric="${ip6Metric}"
                        }
                        else {
                            logmsg "- Set IPv6 Gateway"
                            netsh interface ipv6 add route ::/0 $na.NetConnectionId $ip6Gw
                        }

                        If ($?) {
                            logmsg "  ... Success"
                        }
                        Else {
                            logmsg "  ... Failed"
                        }
                    }

                    # Set IPv6 MTU
                    if ($mtu) {
                        logmsg "- Set IPv6 MTU: ${mtu}"
                        netsh interface ipv6 set interface $nic.InterfaceIndex mtu=$mtu

                        If ($?) {
                            logmsg "  ... Success"
                        }
                        Else {
                            logmsg "  ... Failed"
                        }
                    }

                    # Remove old IPv6 DNS Servers
                    logmsg "- Removing old IPv6 DNS Servers"
                    netsh interface ipv6 set dnsservers $na.NetConnectionId source=static address=

                    If ($dns6) {
                        # Set IPv6 DNS Servers
                        logmsg "- Set IPv6 DNS Servers"
                        $dns6Servers = $dns6 -split " "
                        foreach ($dns6Server in $dns6Servers) {
                            netsh interface ipv6 add dnsserver $na.NetConnectionId address=$dns6Server
                        }
                    }

                    $set_ip_conf = $true

                    doPing($ip6)
                }
                else {
                    logmsg "- No static IPv6 configuration provided, skipping"
                }
            }

            '^\s*(auto|dhcp)\s*$' {
                enableIPv6
                disableIPv6Privacy

                # Enable router discovery
                logmsg "- Enable IPv6 router discovery"
                netsh interface ipv6 set interface $na.NetConnectionId `
                    advertise=disabled routerdiscover=enabled | Out-Null

                # Run of DHCPv6 client is controlled by RA managed/other
                # flags, we can't independently enable/disable DHCPv6
                # client. So at least we release the address allocated
                # through DHCPv6 in auto mode. See
                # https://serverfault.com/questions/692291/disable-dhcpv6-client-in-windows
                if ($ip6Method -match '^\s*auto\s*$') {
                    logmsg "- Release DHCPv6 Lease (selected method auto, not dhcp!)"
                    ipconfig /release6 $na.NetConnectionId

                    If ($?) {
                        logmsg "  ... Success"
                    }
                    Else {
                        logmsg "  ... Failed"
                    }
                }

                # Set IPv6 MTU
                if ($mtu) {
                    logmsg "- Set IPv6 MTU: ${mtu}"
                    logmsg "WARNING: MTU will be overwritten if announced as part of RA!"
                    netsh interface ipv6 set interface $nic.InterfaceIndex mtu=$mtu

                    If ($?) {
                        logmsg "  ... Success"
                    }
                    Else {
                        logmsg "  ... Failed"
                    }
                }

                $set_ip_conf = $true
            }

            '^\s*disable\s*$' {
                disableIPv6
            }

            '\s*skip\s*$' {
                logmsg "- Skipped IPv6 configuration as requested in method (${nicPrefix}IP6_METHOD=${ip6Method})"
            }

            Default {
                logmsg "- Unknown IPv6 method (${nicPrefix}IP6_METHOD=${ip6Method}), skipping configuration"
            }
        }

        ###

        # If no IP configuration happened, we skip
        # configuring additional IP addresses (aliases)
        If ($set_ip_conf -eq $false) {
            logmsg "- Skipped IP aliases configuration due to missing main IP"
            Continue
        }

        # Get the aliases for the NIC in the Context
        $aliasIds = ($context.Keys | Where-Object { $_ -match "^ETH${nicId}_ALIAS\d+_IP6?$" } | ForEach-Object { $_ -replace '(^ETH\d+_ALIAS|_IP$|_IP6$)', '' } | Sort-Object -Unique)

        foreach ($aliasId in $aliasIds) {
            $aliasPrefix = "ETH${nicId}_ALIAS${aliasId}"
            $aliasIp = $context[$aliasPrefix + '_IP']
            $aliasNetmask = $context[$aliasPrefix + '_MASK']
            $aliasIp6 = $context[$aliasPrefix + '_IP6']
            $aliasIp6ULA = $context[$aliasPrefix + '_IP6_ULA']
            $aliasIp6Prefix = $context[$aliasPrefix + '_IP6_PREFIX_LENGTH']
            $detach = $context[$aliasPrefix + '_DETACH']
            $external = $context[$aliasPrefix + '_EXTERNAL']

            if ($external -and ($external -eq "YES")) {
                continue
            }

            if (!$aliasNetmask) {
                $aliasNetmask = "255.255.255.0"
            }

            if (!$aliasIp6Prefix) {
                $aliasIp6Prefix = "64"
            }

            if ($aliasIp -and !$detach) {
                logmsg "- Set Additional Static IP (${aliasPrefix})"
                netsh interface ipv4 add address $nic.InterfaceIndex $aliasIp $aliasNetmask

                If ($?) {
                    logmsg "  ... Success"
                }
                Else {
                    logmsg "  ... Failed"
                }
            }

            if ($aliasIp6 -and !$detach) {
                logmsg "- Set Additional IPv6 Address (${aliasPrefix})"
                netsh interface ipv6 add address $nic.InterfaceIndex $aliasIp6/$aliasIp6Prefix
                If ($? -And $aliasIp6ULA) {
                    netsh interface ipv6 add address $nic.InterfaceIndex $aliasIp6ULA/64
                }

                If ($?) {
                    logmsg "  ... Success"
                }
                Else {
                    logmsg "  ... Failed"
                }
            }
        }

        If ($ip) {
            doPing($ip)
        }
    }

    Write-Host "`r`n" -NoNewline
}

function setTimeZone($context) {
    $timezone = $context['TIMEZONE']

    If ($timezone) {
        logmsg "* Configuring time zone '${timezone}'"

        tzutil /s "${timezone}"

        If ($?) {
            logmsg '  ... Success'
        }
        Else {
            logmsg '  ... Failed'
        }
    }
}

function renameComputer($context) {
    # Initialize Variables
    $current_hostname = hostname
    $context_hostname = $context["SET_HOSTNAME"]

    # SET_HOSTNAME was not set but maybe DNS_HOSTNAME was...
    if (! $context_hostname) {
        $dns_hostname = $context["DNS_HOSTNAME"]

        if ($null -ne $dns_hostname -and $dns_hostname.ToUpper() -eq "YES") {

            # we will set our hostname based on the reverse dns lookup - the IP
            # in question is the first one with a set default gateway
            # (as is done by get_first_ip in addon-context-linux)

            logmsg "* Requested change of Hostname via reverse DNS lookup (DNS_HOSTNAME=YES)"
            $first_ip = (Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object { $null -ne $_.DefaultIPGateway }).IPAddress | Select-Object -First 1
            $context_hostname = [System.Net.Dns]::GetHostbyAddress($first_ip).HostName
            logmsg "- Resolved Hostname is: $context_hostname"
        }
        Else {

            # no SET_HOSTNAME nor DNS_HOSTNAME - skip setting hostname
            return
        }
    }

    $splitted_hostname = $context_hostname.split('.')
    $context_hostname = $splitted_hostname[0]
    $context_domain = $splitted_hostname[1..$splitted_hostname.length] -join '.'

    If ($context_domain) {
        logmsg "* Changing Domain to $context_domain"

        $networkConfig = Get-WmiObject Win32_NetworkAdapterConfiguration -filter "ipenabled = 'true'"
        $ret = $networkConfig.SetDnsDomain($context_domain)

        If ($ret.ReturnValue) {

            # Returned Non Zero, Failed, No restart
            logmsg ("  ... Failed: " + $ret.ReturnValue.ToString())
        }
        Else {

            # Returned Zero, Success
            logmsg "  ... Success"
        }
    }

    # Check for the .opennebula-renamed file
    $logged_hostname = ""
    If (Test-Path "$ctxDir\.opennebula-renamed") {
        logmsg "- Using the JSON file: $ctxDir\.opennebula-renamed"

        # Grab the JSON content
        $json = Get-Content -Path "$ctxDir\.opennebula-renamed" `
        | Out-String

        # Convert to a Hash Table and set the Logged Hostname
        try {
            $status = $json | ConvertFrom-Json
            $logged_hostname = $status.ComputerName
        }
        # Invalid JSON
        catch [System.ArgumentException] {
            logmsg " [!] Invalid JSON:"
            Write-Host $json.ToString()
        }
    }
    Else {

        # no renaming was ever done - we fallback to our current Hostname
        $logged_hostname = $current_hostname
    }

    If (($current_hostname -ne $context_hostname) -and `
        ($context_hostname -eq $logged_hostname)) {

        # avoid rename->reboot loop - if we detect that rename attempt was done
        # but failed then we drop log message about it and finish...

        logmsg "* Computer Rename Attempted but failed:"
        logmsg "- Current: $current_hostname"
        logmsg "- Context: $context_hostname"
    }
    ElseIf ($context_hostname -ne $current_hostname) {

        # the current_name does not match the context_name, rename the computer

        logmsg "* Changing Hostname to $context_hostname"
        # Load the ComputerSystem Object
        $ComputerInfo = Get-WmiObject -Class Win32_ComputerSystem

        # Rename the computer
        $ret = $ComputerInfo.rename($context_hostname)

        $contents = @{}
        $contents["ComputerName"] = $context_hostname
        ConvertTo-Json $contents | Out-File "$ctxDir\.opennebula-renamed"

        # Check success
        If ($ret.ReturnValue) {

            # Returned Non Zero, Failed, No restart
            logmsg ("  ... Failed: " + $ret.ReturnValue.ToString())
            Write-Host "      Check the computername. "
            Write-Host "Possible Issues: The name cannot include control " `
                "characters, leading or trailing spaces, or any of " `
                "the following characters: `" / \ [ ] : | < > + = ; , ?"

        }
        Else {

            # Returned Zero, Success
            logmsg "  ... Success"

            # Restart the Computer
            logmsg "  ... Rebooting"
            Restart-Computer -Force

            # Exit here so the script doesn't continue to run
            Exit 0
        }
    }
    Else {

        # Hostname is set and correct
        logmsg "* Computer Name already set: $context_hostname"
    }

    Write-Host "`r`n" -NoNewline
}

function enableRemoteDesktop() {
    logmsg "* Enabling Remote Desktop"
    # Windows 7 only - add firewall exception for RDP
    logmsg "- Enable Remote Desktop Rule Group"
    netsh advfirewall Firewall set rule group="Remote Desktop" new enable=yes

    # Enable RDP
    logmsg "- Enable Allow Terminal Services Connections"
    $ret = (Get-WmiObject -Class "Win32_TerminalServiceSetting" -Namespace root\cimv2\terminalservices).SetAllowTsConnections(1)
    If ($ret.ReturnValue) {
        logmsg ("  ... Failed: " + $ret.ReturnValue.ToString())
    }
    Else {
        logmsg "  ... Success"
    }
    Write-Host "`r`n" -NoNewline
}

function enableSSH() {
    logmsg "* Enabling SSH"
    # Get sshd service
    $serviceName = "sshd"
    $sshdService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    
    # Check if service is present
    if ($sshdService) {
        # Service is running and automatic start is enabled
        if ($sshdService.StartType -eq "Automatic" -and $sshdService.Status -eq "Running") {
            logmsg " ... Success (Service is already enabled and running )"
            return
        }
        # Enable autostart
        if ($sshdService.StartType -ne "Automatic") {
            logmsg "- Enabling automatic start for SSH service"
            Set-Service -Name $serviceName -StartupType Automatic
            if ($?) {
                logsuccess
            } else {
                logfail
                return
            }
        }
        # Start service
        if ($sshdService.Status -ne "Running") {
            logmsg "- Starting SSH service"
        Start-Service -Name $serviceName
        if ($?) {
            logsuccess
        } else {
            logfail
        }
    }
    } else {
        # OpenSSH.Server feature is not installed
        logmsg " ... Failed (OpenSSH Server is not installed)"
    }
}

function enablePing() {
    logmsg "* Enabling Ping"
    #Create firewall manager object
    New-Object -com hnetcfg.fwmgr

    # Get current profile
    $pro = $fwmgcalPolicy.CurrentProfile

    logmsg "- Enable Allow Inbound Echo Requests"
    $ret = $pro.IcmpSettings.AllowInboundEchoRequest = $true
    If ($ret) {
        logmsg "  ... Success"
    }
    Else {
        logmsg "  ... Failed"
    }

    Write-Host "`r`n" -NoNewline
}

function doPing($ip, $retries = 20) {
    logmsg "- Ping Interface IP $ip"

    $ping = $false
    $retry = 0
    do {
        $retry++
        Start-Sleep -s 1
        $ping = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue
    } while (!$ping -and ($retry -lt $retries))

    If ($ping) {
        logmsg "  ... Success ($retry tries)"
    }
    Else {
        logmsg "  ... Failed ($retry tries)"
    }
}

function disableIPv6Privacy() {
    # Disable Randomization of IPv6 addresses (use EUI-64)
    logmsg "- Globally disable IPv6 Identifiers Randomization"
    netsh interface ipv6 set global randomizeidentifiers=disable

    If ($?) {
        logmsg "  ... Success"
    }
    Else {
        logmsg "  ... Failed"
    }

    # Disable IPv6 Privacy Extensions (temporary addresses)
    logmsg "- Globally disable IPv6 Privacy Extensions"
    netsh interface ipv6 set privacy state=disabled

    If ($?) {
        logmsg "  ... Success"
    }
    Else {
        logmsg "  ... Failed"
    }
}

function enableIPv6() {
    logmsg '- Enabling IPv6'

    Enable-NetAdapterBinding -Name $na.NetConnectionId -ComponentID ms_tcpip6

    If ($?) {
        logmsg "  ... Success"
    }
    Else {
        logmsg "  ... Failed"
    }
}

function disableIPv6() {
    logmsg '- Disabling IPv6'

    Disable-NetAdapterBinding -Name $na.NetConnectionId -ComponentID ms_tcpip6

    If ($?) {
        logmsg "  ... Success"
    }
    Else {
        logmsg "  ... Failed"
    }
}

function runScripts($context, $contextPaths) {
    logmsg "* Running Scripts"

    # Get list of scripts to run, " " delimited
    $initscripts = $context["INIT_SCRIPTS"]

    if ($initscripts) {
        # Parse each script and run it
        ForEach ($script in $initscripts.split(" ")) {

            # Sanitize the filename (drop any path from them and instead use our directory)
            $script = $contextPaths.contextInitScriptPath + [System.IO.Path]::GetFileName($script.Trim())

            if (Test-Path $script) {
                logmsg "- $script"
                envContext($context)
                pswrapper "$script"
            }

        }
    }
    else {
        # Emulate the init.sh fallback behavior from Linux
        $script = $contextPaths.contextInitScriptPath + "init.ps1"

        if (Test-Path $script) {
            logmsg "- $script"
            envContext($context)
            pswrapper "$script"
        }
    }

    # Execute START_SCRIPT or START_SCRIPT_64
    $startScript = $context["START_SCRIPT"]
    $startScript64 = $context["START_SCRIPT_BASE64"]

    if ($startScript64) {
        $startScript = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($startScript64))
    }

    if ($startScript) {

        # Save the script as .opennebula-startscript.ps1
        $startScriptPS = "$ctxDir\.opennebula-startscript.ps1"
        $startScript | Out-File $startScriptPS "UTF8"

        # Launch the Script
        logmsg "- $startScriptPS"
        envContext($context)
        pswrapper "$startScriptPS"
        removeFile "$startScriptPS"
    }
    Write-Host "`r`n" -NoNewline
}

function extendPartition($disk, $part) {
    "select disk $disk", "select partition $part", "extend" | diskpart | Out-Null
}

function extendPartitions($context) {
    logmsg "* Extend partitions"

    "rescan" | diskpart

    $disks = @()

    # Cmdlet 'Get-Partition' is not in older Windows/Powershell versions
    if (Get-Command -ErrorAction SilentlyContinue -Name Get-Partition) {
        if ([string]$context['GROW_ROOTFS'] -eq '' -or $context['GROW_ROOTFS'].ToUpper() -eq 'YES') {
            # Add at least C:
            $drives = "C: $($context['GROW_FS'])"
        }
        else {
            $drives = "$($context['GROW_FS'])"
        }

        $driveLetters = (-split $drives | Select-String -Pattern "^(\w):?[\/]?$" -AllMatches | ForEach-Object { $_.matches.groups[1].Value } | Sort-Object -Unique)

        ForEach ($driveLetter in $driveLetters) {
            $disk = New-Object PsObject -Property @{
                name    = $null
                diskId  = $null
                partIds = @()
            }
            # TODO: in the future an AccessPath can be used instead of just DriveLetter
            $drive = (Get-Partition -DriveLetter $driveLetter)
            $disk.name = "$driveLetter" + ':'
            $disk.diskId = $drive.DiskNumber
            $disk.partIds += $drive.PartitionNumber
            $disks += $disk
        }
    }
    Else {
        # always resize at least the disk 0
        $disk = New-Object PsObject -Property @{
            name    = $null
            diskId  = 0
            partIds = @()
        }

        # select all parts - preserve old behavior for disk 0
        $disk.partIds = "select disk $($disk.diskId)", "list partition" | diskpart | Select-String -Pattern "^\s+\w+ (\d+)\s+" -AllMatches | ForEach-Object { $_.matches.groups[1].Value }
        $disks += $disk
    }

    # extend all requested disk/part
    ForEach ($disk in $disks) {
        ForEach ($partId in $disk.partIds) {
            if ($disk.name) {
                logmsg "- Extend ($($disk.name)) Disk: $($disk.diskId) / Part: $partId"
            }
            Else {
                logmsg "- Extend Disk: $($disk.diskId) / Part: $partId"
            }
            extendPartition $disk.diskId $partId
        }
    }
}

function reportReady($context, $contextLetter) {
    $reportReady = $context['REPORT_READY']
    $oneGateEndpoint = $context['ONEGATE_ENDPOINT']
    $vmId = $context['VMID']
    $token = $context['ONEGATE_TOKEN']
    $retryCount = 3
    $retryWaitPeriod = 10

    if ($reportReady -and $reportReady.ToUpper() -eq 'YES') {
        logmsg '* Report Ready to OneGate'

        if (!$oneGateEndpoint) {
            logmsg '  ... Failed: ONEGATE_ENDPOINT not set'
            return
        }

        if (!$vmId) {
            logmsg '  ... Failed: VMID not set'
            return
        }

        if (!$token) {
            logmsg "  ... Token not set. Try file"
            $tokenPath = $contextLetter + 'token.txt'
            if (Test-Path $tokenPath) {
                $token = Get-Content $tokenPath
            }
            else {
                logmsg "  ... Failed: Token file not found"
                return
            }
        }

        $retryNumber = 1
        while ($true) {
            try {
                $body = 'READY=YES'
                $target = $oneGateEndpoint + '/vm'

                [System.Net.HttpWebRequest] $webRequest = [System.Net.WebRequest]::Create($target)
                $webRequest.Timeout = 10000
                $webRequest.Method = 'PUT'
                $webRequest.Headers.Add('X-ONEGATE-TOKEN', $token)
                $webRequest.Headers.Add('X-ONEGATE-VMID', $vmId)
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
                $webRequest.ContentLength = $buffer.Length

                if ($oneGateEndpoint -ilike "https://*") {
                    #For reporting on HTTPS OneGateEndpoint
                    logmsg "  ... Use HTTPS for OneGateEndpoint report: $oneGateEndpoint"
                    $AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
                    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
                    [System.Net.ServicePointManager]::Expect100Continue = $false
                    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
                }

                $requestStream = $webRequest.GetRequestStream()
                $requestStream.Write($buffer, 0, $buffer.Length)
                $requestStream.Flush()
                $requestStream.Close()

                $response = $webRequest.getResponse()
                if ($response.StatusCode -eq 'OK') {
                    logmsg '  ... Success'
                    break
                }
                else {
                    logmsg "  ... Failed: $($response.StatusCode)"
                }
            }
            catch {
                $errorMessage = $_.Exception.Message
                logmsg "  ... Failed: $errorMessage"
            }

            logmsg "  ... Report ready failed (${retryNumber}. try out of ${retryCount})"
            $retryNumber++
            if ($retryNumber -le $retryCount) {
                logmsg "  ... sleep for ${retryWaitPeriod} seconds and try again..."
                Start-Sleep -Seconds $retryWaitPeriod
            }
            else {
                logmsg "  ... All retries failed!"
                break
            }
        }
    }
}

function ejectContextCD($cdrom_drive) {
    if (-Not $cdrom_drive) {
        return
    }

    $eject_cdrom = $context['EJECT_CDROM']

    if ($null -ne $eject_cdrom -and $eject_cdrom.ToUpper() -eq 'YES') {
        logmsg '* Ejecting context CD'
        try {
            #https://learn.microsoft.com/en-us/windows/win32/api/shldisp/ne-shldisp-shellspecialfolderconstants
            $ssfDRIVES = 0x11
            $sh = New-Object -ComObject "Shell.Application"
            $sh.Namespace($ssfDRIVES).Items() | Where-Object { $_.Type -eq "CD Drive" -and $_.Path -eq $cdrom_drive.Name } | ForEach-Object {
                $_.InvokeVerb("Eject")
                logmsg " ... Ejected $($cdrom_drive.Name)"
            }
        }
        catch {
            logmsg "  ... Failed to eject the CD: $_"
        }
    }
}

function removeFile($file) {
    if (![string]::IsNullOrEmpty($file) -and (Test-Path $file)) {
        logmsg "* Removing the file: ${file}"
        Remove-Item -Path $file -Force
    }
}

function removeDir($dir) {
    if (![string]::IsNullOrEmpty($dir) -and (Test-Path $dir)) {
        logmsg "* Removing the directory: ${dir}"
        Remove-Item -Path $dir -Recurse -Force
    }
}

function cleanup($contextPaths) {
    if ($contextPaths.contextDrive) {
        # Eject CD with 'context.sh' if requested
        ejectContextCD $contextPaths.contextDrive
    }
    else {
        # Delete 'context.sh' if not on CD-ROM
        removeFile $contextPaths.contextPath

        # and downloaded init scripts
        removeDir $contextPaths.contextInitScriptPath
    }
}

function pswrapper($path) {
    # source:
    #   - http://cosmonautdreams.com/2013/09/03/Getting-Powershell-to-run-in-64-bit.html
    #   - https://ss64.com/nt/syntax-64bit.html
    If ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
        # This is only set in a x86 Powershell running on a 64bit Windows

        $realpath = [string]$(Resolve-Path "$path")

        # Run 64bit powershell as a subprocess and there execute the command
        #
        # NOTE: virtual subdir 'sysnative' exists only when running 32bit binary under 64bit system
        & "$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile -Command "$realpath"
    }
    Else {
        & "$path"
    }
}

function authorizeSSHKeyAdmin {
    param (
        $authorizedKeys
    )

    $authorizedKeysPath = "$env:ProgramData\ssh\administrators_authorized_keys"


    $authoriozedKeysDir = Split-Path -Parent -Path $authorizedKeysPath
    if (!(Test-Path $authoriozedKeysDir)) {
        logmsg "- Directory $authoriozedKeysDir does not exist"
        logmsg "- Trying to create the directory $authoriozedKeysDir"
        New-Item -ItemType Directory -Path $authoriozedKeysDir
        if ($?) {
            logsuccess
        }
        else {
            logfail
        }
    }

    # whitelisting
    logmsg "- Writing SSH key to $authorizedKeysPath"
    Set-Content $authorizedKeysPath $authorizedKeys

    if ($?) {
        # permissions
        icacls.exe $authorizedKeysPath /inheritance:r /grant Administrators:F /grant SYSTEM:F

        logsuccess
    }
    else {
        logfail
    }

}

function authorizeSSHKeyStandard {
    param (
        $authorizedKeys
    )

    $authorizedKeysPath = "$env:USERPROFILE\.ssh"

    New-Item -Force -ItemType Directory -Path $authorizedKeysPath
    Set-Content $authorized_keys_path $authorizedKeys

    if ($?) {
        logsuccess
    }
    else {
        logfail
    }
}

function authorizeSSHKey {
    param (
        $authorizedKeys,
        $winadmin
    )

    logmsg "* Authorizing SSH_PUBLIC_KEY: ${authorizedKeys}"

    if ($winadmin -ieq "no") {
        authorizeSSHKeyStandard $authorizedKeys
    }
    else {
        authorizeSSHKeyAdmin $authorizedKeys
    }

}

################################################################################
# Main
################################################################################

# global variable pointing to the private .contextualization directory
$global:ctxDir = "$env:SystemDrive\.onecontext"

# Check, if above defined context directory exists
If ( !(Test-Path "$ctxDir") ) {
    mkdir "$ctxDir"
}

# Move old logfile away - so we have a current log containing the output of the last boot
If ( Test-Path "$ctxDir\opennebula-context.log" ) {
    mv "$ctxDir\opennebula-context.log" "$ctxDir\opennebula-context-old.log"
}
m
# Start now logging to logfile
Start-Transcript -Append -Path "$ctxDir\opennebula-context.log" | Out-Null

logmsg "* Running Script: $($MyInvocation.MyCommand.Path)"

Set-ExecutionPolicy unrestricted -Force # not needed if already done once on the VM
[string]$computerName = "$env:computername"
[string]$ConnectionString = "WinNT://$computerName"

# Check the working WMI
if (-Not (Get-WMIObject -ErrorAction SilentlyContinue Win32_Volume)) {
    logmsg "- WMI not ready, exiting"
    Stop-Transcript | Out-Null
    exit 1
}

Write-Host "`r`n" -NoNewline
Write-Host "*********************************`r`n" -NoNewline
Write-Host "*** ENTERING THE SERVICE LOOP ***`r`n" -NoNewline
Write-Host "*********************************`r`n" -NoNewline
Write-Host "`r`n" -NoNewline

# infinite loop
$checksum = ""
do {
    # Stay in this wait-loop until context.sh emerges and its path is stored
    $contextPaths = waitForContext($checksum)

    # Parse context file
    $context = getContext $contextPaths.contextScriptPath

    # Execute the contextualization actions
    extendPartitions $context
    setTimeZone $context
    addLocalUser $context
    enableRemoteDesktop
    enableSSH
    enablePing
    configureNetwork $context
    renameComputer $context
    runScripts $context $contextPaths
    authorizeSSHKey $context["SSH_PUBLIC_KEY"] $context["WINADMIN"]
    reportReady $context $contextPaths.contextLetter

    # Save the 'applied' context.sh checksum for the next recontextualization
    logmsg "* Calculating the checksum of the file: $($contextPaths.contextScriptPath)"
    $checksum = Get-FileHash -Algorithm SHA256 $contextPaths.contextScriptPath
    logmsg "  ... $($checksum.Hash)"
    # and remove the file itself
    removeFile $contextPaths.contextScriptPath

    # Cleanup at the end
    cleanup $contextPaths

    Write-Host "`r`n" -NoNewline

} while ($true)

Stop-Transcript | Out-Null
