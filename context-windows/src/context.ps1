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

function Write-LogMessage {
    param (
        $Message
    )
    # powershell 4 does not automatically add newline in the transcript so we
    # workaround it by adding it explicitly and using the NoNewline argument
    # we ensure that it will not be added twice
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm K')] $Message`r`n" -NoNewline
}

function Get-ContextData {
    param (
        $File
    )

    # TODO: Improve regexp for multiple SSH keys on SSH_PUBLIC_KEY
    $context = @{}
    switch -regex -file $File {
        "^([^=]+)='(.+?)'$" {
            $name, $value = $matches[1..2]
            $context[$name] = $value
        }
    }
    return $context
}

function Set-EnvironmentContext {
    param (
        $Context
    )
    foreach ($h in $Context.GetEnumerator()) {
        $name = "Env:" + $h.Name
        Set-Item $name $h.Value
    }
}

function Test-ContextChanged {
    param (
        $File,
        $LastChecksum
    )
    $newChecksum = Get-FileHash -Algorithm SHA256 $File
    return $LastChecksum.Hash -ne $newChecksum.Hash
}

function Wait-ForContext {
    param (
        $Checksum
    )
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
            if (Test-ContextChanged $contextPaths.contextPath $Checksum) {
                Break
            }
        }

        Remove-Context $contextPaths

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

function Add-LocalUser {
    param (
        $Context
    )
    # Create new user
    $username = $Context["USERNAME"]
    $password = $Context["PASSWORD"]
    $password64 = $Context["PASSWORD_BASE64"]

    if ($password64) {
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

        Write-LogMessage "* Creating Account for $username"

        $ADSI = [adsi]$ConnectionString

        if (!([ADSI]::Exists("WinNT://$computerName/$username"))) {
            # User does not exist, Create the User
            Write-LogMessage "- Creating account"
            $user = $ADSI.Create("user", $username)
            $user.setPassword($password)
            $user.SetInfo()
        }
        else {
            # User exists, Set Password
            Write-LogMessage "- Setting Password"
            $admin = [ADSI]"WinNT://$env:computername/$username"
            $admin.psbase.invoke("SetPassword", $password)
        }

        # Set Password to Never Expire
        Write-LogMessage "- Setting password to never expire"
        $admin = [ADSI]"WinNT://$env:computername/$username"
        $admin.UserFlags.value = $admin.UserFlags.value -bor 0x10000
        $admin.CommitChanges()

        # Add user to local Administrators
        # ATTENTION - Language/Regional settings have influence on the naming
        #             of this group. Use the Group SID instead (S-1-5-32-544)
        $groups = (Get-WmiObject -Class "Win32_Group" |
            Where-Object { $_.SID -like "S-1-5-32-544" } |
            Select-Object -ExpandProperty Name)

        foreach ($grp in $groups) {

            # Make sure the Group exists
            if ([ADSI]::Exists("WinNT://$computerName/$grp,group")) {

                # Check if the user is a Member of the Group
                $group = [ADSI] "WinNT://$computerName/$grp,group"
                $members = @($group.psbase.Invoke("Members"))

                $memberNames = @()
                $members | ForEach-Object {
                    # https://p0w3rsh3ll.wordpress.com/2016/06/14/any-documented-adsi-changes-in-powershell-5-0/
                    $memberNames += ([ADSI]$_).psbase.InvokeGet('Name')
                }

                if (-Not ($memberNames -Contains $username)) {

                    # Make sure the user exists, again
                    if ([ADSI]::Exists("WinNT://$computerName/$username")) {

                        # Add the user
                        Write-LogMessage "- Adding to $grp"
                        $group.Add("WinNT://$computerName/$username")
                    }
                }
            }
        }
    }
    Write-Host "`r`n" -NoNewline
}

function Set-NetworkConfiguration {
    param (
        $Context
    )

    # Get the NIC in the Context
    $nicIds = ($Context.Keys | Where-Object { $_ -match '^ETH\d+_MAC$' } | ForEach-Object { $_ -replace '(^ETH|_MAC$)', '' } | Sort-Object -Unique)

    $nicId = 0

    foreach ($nicId in $nicIds) {
        $nicPrefix = "ETH" + $nicId + "_"

        $method = $Context[$nicPrefix + 'METHOD']
        $ip = $Context[$nicPrefix + 'IP']
        $netmask = $Context[$nicPrefix + 'MASK']
        $mac = $Context[$nicPrefix + 'MAC']
        $dns = (($Context[$nicPrefix + 'DNS'] -split " " | Where-Object { $_ -match '^(([0-9]*).?){4}$' }) -join ' ')
        $dns6 = (($Context[$nicPrefix + 'DNS'] -split " " | Where-Object { $_ -match '^(([0-9A-F]*):?)*$' }) -join ' ')
        $dnsSuffix = $Context[$nicPrefix + 'SEARCH_DOMAIN']
        $gateway = $Context[$nicPrefix + 'GATEWAY']
        $network = $Context[$nicPrefix + 'NETWORK']
        $mtu = $Context[$nicPrefix + 'MTU']
        $metric = $Context[$nicPrefix + 'METRIC']

        $ip6Method = $Context[$nicPrefix + 'IP6_METHOD']
        $ip6 = $Context[$nicPrefix + 'IP6']
        $ip6ULA = $Context[$nicPrefix + 'IP6_ULA']
        $ip6Prefix = $Context[$nicPrefix + 'IP6_PREFIX_LENGTH']
        $ip6Gw = $Context[$nicPrefix + 'IP6_GATEWAY']
        $ip6Metric = $Context[$nicPrefix + 'IP6_METRIC']

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
            $ip6Gw = $Context[$nicPrefix + 'GATEWAY6']
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

        if (!$nic) {
            Write-LogMessage ("* Configuring Network Settings: " + $mac)
            Write-LogMessage ("  ... Failed: Interface with MAC not found")
            continue
        }

        # We need the connection ID (i.e. "Local Area Connection",
        # which can be discovered from the NetworkAdapter object
        $na = Get-WMIObject Win32_NetworkAdapter | `
            Where-Object { $_.deviceId -eq $nic.index }

        if (!$na) {
            Write-LogMessage ("* Configuring Network Settings: " + $mac)
            Write-LogMessage ("  ... Failed: Network Adapter not found")
            continue
        }

        Write-LogMessage ("* Configuring Network Settings: " + $nic.Description.ToString())

        # Flag to indicate if any IPv4/6 configuration was placed
        $setIpConf = $false

        # IPv4 Configuration Methods
        switch -Regex ($method) {
            '^\s*static\s*$' {
                if ($ip) {
                    # Release the DHCP lease, will fail if adapter not DHCP Configured
                    Write-LogMessage "- Release DHCP Lease"
                    $ret = $nic.ReleaseDHCPLease()
                    if ($ret.ReturnValue) {
                        Write-LogMessage ("  ... Failed: " + $ret.ReturnValue.ToString())
                    }
                    else {
                        Write-LogMessage "  ... Success"
                    }

                    # set static IP address and retry for few times if there was a problem
                    # with acquiring write lock (2147786788) for network configuration
                    # https://msdn.microsoft.com/en-us/library/aa390383(v=vs.85).aspx
                    Write-LogMessage "- Set Static IP"
                    $retry = 10
                    do {
                        $retry--
                        Start-Sleep -s 1
                        $ret = $nic.EnableStatic($ip , $netmask)
                    } while ($ret.ReturnValue -eq 2147786788 -and $retry)
                    if ($ret.ReturnValue) {
                        Write-LogMessage ("  ... Failed: " + $ret.ReturnValue.ToString())
                    }
                    else {
                        Write-LogMessage "  ... Success"
                    }

                    # Set IPv4 MTU
                    if ($mtu) {
                        Write-LogMessage "- Set MTU: ${mtu}"
                        netsh interface ipv4 set interface $nic.InterfaceIndex mtu=$mtu

                        if ($?) {
                            Write-LogMessage "  ... Success"
                        }
                        else {
                            Write-LogMessage "  ... Failed"
                        }
                    }

                    # Set the Gateway
                    if ($gateway) {
                        if ($metric) {
                            Write-LogMessage "- Set Gateway with metric"
                            $ret = $nic.SetGateways($gateway, $metric)
                        }
                        else {
                            Write-LogMessage "- Set Gateway"
                            $ret = $nic.SetGateways($gateway)
                        }

                        if ($ret.ReturnValue) {
                            Write-LogMessage ("  ... Failed: " + $ret.ReturnValue.ToString())
                        }
                        else {
                            Write-LogMessage "  ... Success"
                        }
                    }

                    # Set DNS servers
                    if ($dns) {
                        $dnsServers = $dns -split " "

                        # DNS Server Search Order
                        Write-LogMessage "- Set DNS Server Search Order"
                        $ret = $nic.SetDNSServerSearchOrder($dnsServers)
                        if ($ret.ReturnValue) {
                            Write-LogMessage ("  ... Failed: " + $ret.ReturnValue.ToString())
                        }
                        else {
                            Write-LogMessage "  ... Success"
                        }

                        # Set Dynamic DNS Registration
                        Write-LogMessage "- Set Dynamic DNS Registration"
                        $ret = $nic.SetDynamicDNSRegistration("TRUE")
                        if ($ret.ReturnValue) {
                            Write-LogMessage ("  ... Failed: " + $ret.ReturnValue.ToString())
                        }
                        else {
                            Write-LogMessage "  ... Success"
                        }

                        # WINS Addresses
                        # $nic.SetWINSServer($DNSServers[0], $DNSServers[1])
                    }

                    # Set DNS domain/search order
                    if ($dnsSuffix) {
                        $dnsSuffixes = $dnsSuffix -split " "

                        # Set DNS Suffix Search Order
                        Write-LogMessage "- Set DNS Suffix Search Order"
                        $ret = ([WMIClass]"Win32_NetworkAdapterConfiguration").SetDNSSuffixSearchOrder(($dnsSuffixes))
                        if ($ret.ReturnValue) {
                            Write-LogMessage ("  ... Failed: " + $ret.ReturnValue.ToString())
                        }
                        else {
                            Write-LogMessage "  ... Success"
                        }

                        # Set Primary DNS Domain
                        Write-LogMessage "- Set Primary DNS Domain"
                        $ret = $nic.SetDNSDomain($dnsSuffixes[0])
                        if ($ret.ReturnValue) {
                            Write-LogMessage ("  ... Failed: " + $ret.ReturnValue.ToString())
                        }
                        else {
                            Write-LogMessage "  ... Success"
                        }
                    }

                    $setIpConf = $true
                }
                else {
                    Write-LogMessage "- No static IPv4 configuration provided, skipping"
                }
            }

            '^\s*dhcp\s*$' {
                # Enable DHCP
                Write-LogMessage "- Enable DHCP"
                $ret = $nic.EnableDHCP()
                # TODO: 1 ... Successful completion, reboot required
                if ($ret.ReturnValue) {
                    Write-LogMessage ("  ... Failed: " + $ret.ReturnValue.ToString())
                }
                else {
                    Write-LogMessage "  ... Success"
                }

                # Set IPv4 MTU
                if ($mtu) {
                    Write-LogMessage "- Set MTU: ${mtu}"
                    netsh interface ipv4 set interface $nic.InterfaceIndex mtu=$mtu

                    if ($?) {
                        Write-LogMessage "  ... Success"
                    }
                    else {
                        Write-LogMessage "  ... Failed"
                    }
                }

                $setIpConf = $true
            }

            '\s*skip\s*$' {
                Write-LogMessage "- Skipped IPv4 configuration as requested in method (${nicPrefix}METHOD=${method})"
            }

            default {
                Write-LogMessage "- Unknown IPv4 method (${nicPrefix}METHOD=${method}), skipping configuration"
            }
        }

        # IPv6 Configuration Methods
        switch -Regex ($ip6Method) {
            '^\s*static\s*$' {
                if ($ip6) {
                    Enable-NetworkIPv6
                    Disable-NetworkIPv6Privacy

                    # Disable router discovery
                    Write-LogMessage "- Disable IPv6 router discovery"
                    netsh interface ipv6 set interface $na.NetConnectionId `
                        advertise=disabled routerdiscover=disabled | Out-Null

                    if ($?) {
                        Write-LogMessage "  ... Success"
                    }
                    else {
                        Write-LogMessage "  ... Failed"
                    }

                    # Remove old IPv6 addresses
                    Write-LogMessage "- Removing old IPv6 addresses"
                    if (Get-Command Remove-NetIPAddress -ErrorAction SilentlyContinue) {
                        # Windows 8.1 and Server 2012 R2 and up
                        # we want to remove everything except the link-local address
                        Remove-NetIPAddress -InterfaceAlias $na.NetConnectionId `
                            -AddressFamily IPv6 -Confirm:$false `
                            -PrefixOrigin Other, Manual, Dhcp, RouterAdvertisement `
                            -errorAction SilentlyContinue

                        if ($?) {
                            Write-LogMessage "  ... Success"
                        }
                        else {
                            Write-LogMessage "  ... Nothing to do"
                        }
                    }
                    else {
                        Write-LogMessage "  ... Not implemented"
                    }

                    # Set IPv6 Address
                    Write-LogMessage "- Set IPv6 Address"
                    netsh interface ipv6 add address $na.NetConnectionId $ip6/$ip6Prefix
                    if ($? -And $ip6ULA) {
                        netsh interface ipv6 add address $na.NetConnectionId $ip6ULA/64
                    }

                    if ($?) {
                        Write-LogMessage "  ... Success"
                    }
                    else {
                        Write-LogMessage "  ... Failed"
                    }

                    # Set IPv6 Gateway
                    if ($ip6Gw) {
                        if ($ip6Metric) {
                            Write-LogMessage "- Set IPv6 Gateway with metric"
                            netsh interface ipv6 add route ::/0 $na.NetConnectionId $ip6Gw metric="${ip6Metric}"
                        }
                        else {
                            Write-LogMessage "- Set IPv6 Gateway"
                            netsh interface ipv6 add route ::/0 $na.NetConnectionId $ip6Gw
                        }

                        if ($?) {
                            Write-LogMessage "  ... Success"
                        }
                        else {
                            Write-LogMessage "  ... Failed"
                        }
                    }

                    # Set IPv6 MTU
                    if ($mtu) {
                        Write-LogMessage "- Set IPv6 MTU: ${mtu}"
                        netsh interface ipv6 set interface $nic.InterfaceIndex mtu=$mtu

                        if ($?) {
                            Write-LogMessage "  ... Success"
                        }
                        else {
                            Write-LogMessage "  ... Failed"
                        }
                    }

                    # Remove old IPv6 DNS Servers
                    Write-LogMessage "- Removing old IPv6 DNS Servers"
                    netsh interface ipv6 set dnsservers $na.NetConnectionId source=static address=

                    if ($dns6) {
                        # Set IPv6 DNS Servers
                        Write-LogMessage "- Set IPv6 DNS Servers"
                        $dns6Servers = $dns6 -split " "
                        foreach ($dns6Server in $dns6Servers) {
                            netsh interface ipv6 add dnsserver $na.NetConnectionId address=$dns6Server
                        }
                    }

                    $setIpConf = $true

                    Test-ConnectionPing($ip6)
                }
                else {
                    Write-LogMessage "- No static IPv6 configuration provided, skipping"
                }
            }

            '^\s*(auto|dhcp)\s*$' {
                Enable-NetworkIPv6
                Disable-NetworkIPv6Privacy

                # Enable router discovery
                Write-LogMessage "- Enable IPv6 router discovery"
                netsh interface ipv6 set interface $na.NetConnectionId `
                    advertise=disabled routerdiscover=enabled | Out-Null

                # Run of DHCPv6 client is controlled by RA managed/other
                # flags, we can't independently enable/disable DHCPv6
                # client. So at least we release the address allocated
                # through DHCPv6 in auto mode. See
                # https://serverfault.com/questions/692291/disable-dhcpv6-client-in-windows
                if ($ip6Method -match '^\s*auto\s*$') {
                    Write-LogMessage "- Release DHCPv6 Lease (selected method auto, not dhcp!)"
                    ipconfig /release6 $na.NetConnectionId

                    if ($?) {
                        Write-LogMessage "  ... Success"
                    }
                    else {
                        Write-LogMessage "  ... Failed"
                    }
                }

                # Set IPv6 MTU
                if ($mtu) {
                    Write-LogMessage "- Set IPv6 MTU: ${mtu}"
                    Write-LogMessage "WARNING: MTU will be overwritten if announced as part of RA!"
                    netsh interface ipv6 set interface $nic.InterfaceIndex mtu=$mtu

                    if ($?) {
                        Write-LogMessage "  ... Success"
                    }
                    else {
                        Write-LogMessage "  ... Failed"
                    }
                }

                $setIpConf = $true
            }

            '^\s*disable\s*$' {
                Disable-NetworkIPv6
            }

            '\s*skip\s*$' {
                Write-LogMessage "- Skipped IPv6 configuration as requested in method (${nicPrefix}IP6_METHOD=${ip6Method})"
            }

            default {
                Write-LogMessage "- Unknown IPv6 method (${nicPrefix}IP6_METHOD=${ip6Method}), skipping configuration"
            }
        }

        ###

        # if no IP configuration happened, we skip
        # configuring additional IP addresses (aliases)
        if ($setIpConf -eq $false) {
            Write-LogMessage "- Skipped IP aliases configuration due to missing main IP"
            continue
        }

        # Get the aliases for the NIC in the Context
        $aliasIds = ($Context.Keys | Where-Object { $_ -match "^ETH${nicId}_ALIAS\d+_IP6?$" } | ForEach-Object { $_ -replace '(^ETH\d+_ALIAS|_IP$|_IP6$)', '' } | Sort-Object -Unique)

        foreach ($aliasId in $aliasIds) {
            $aliasPrefix = "ETH${nicId}_ALIAS${aliasId}"
            $aliasIp = $Context[$aliasPrefix + '_IP']
            $aliasNetmask = $Context[$aliasPrefix + '_MASK']
            $aliasIp6 = $Context[$aliasPrefix + '_IP6']
            $aliasIp6ULA = $Context[$aliasPrefix + '_IP6_ULA']
            $aliasIp6Prefix = $Context[$aliasPrefix + '_IP6_PREFIX_LENGTH']
            $detach = $Context[$aliasPrefix + '_DETACH']
            $external = $Context[$aliasPrefix + '_EXTERNAL']

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
                Write-LogMessage "- Set Additional Static IP (${aliasPrefix})"
                netsh interface ipv4 add address $nic.InterfaceIndex $aliasIp $aliasNetmask

                if ($?) {
                    Write-LogMessage "  ... Success"
                }
                else {
                    Write-LogMessage "  ... Failed"
                }
            }

            if ($aliasIp6 -and !$detach) {
                Write-LogMessage "- Set Additional IPv6 Address (${aliasPrefix})"
                netsh interface ipv6 add address $nic.InterfaceIndex $aliasIp6/$aliasIp6Prefix
                if ($? -And $aliasIp6ULA) {
                    netsh interface ipv6 add address $nic.InterfaceIndex $aliasIp6ULA/64
                }

                if ($?) {
                    Write-LogMessage "  ... Success"
                }
                else {
                    Write-LogMessage "  ... Failed"
                }
            }
        }

        if ($ip) {
            Test-ConnectionPing($ip)
        }
    }

    Write-Host "`r`n" -NoNewline
}

function Set-TimeZone {
    param (
        $Context
    )
    $timezone = $Context['TIMEZONE']

    if ($timezone) {
        Write-LogMessage "* Configuring time zone '${timezone}'"

        tzutil /s "${timezone}"

        if ($?) {
            Write-LogMessage '  ... Success'
        }
        else {
            Write-LogMessage '  ... Failed'
        }
    }
}

function Rename-Computer {
    param (
        $Context
    )
    # Initialize Variables
    $currentHostname = hostname
    $contextHostname = $Context["SET_HOSTNAME"]

    # SET_HOSTNAME was not set but maybe DNS_HOSTNAME was...
    if (! $contextHostname) {
        $dnsHostname = $Context["DNS_HOSTNAME"]

        if ($null -ne $dnsHostname -and $dnsHostname.ToUpper() -eq "YES") {

            # we will set our hostname based on the reverse dns lookup - the IP
            # in question is the first one with a set default gateway
            # (as is done by get_first_ip in addon-context-linux)

            Write-LogMessage "* Requested change of Hostname via reverse DNS lookup (DNS_HOSTNAME=YES)"
            $first_ip = (Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object { $null -ne $_.DefaultIPGateway }).IPAddress | Select-Object -First 1
            $contextHostname = [System.Net.Dns]::GetHostbyAddress($first_ip).HostName
            Write-LogMessage "- Resolved Hostname is: $contextHostname"
        }
        else {

            # no SET_HOSTNAME nor DNS_HOSTNAME - skip setting hostname
            return
        }
    }

    $splittedHostname = $contextHostname.split('.')
    $contextHostname = $splittedHostname[0]
    $contextDomain = $splittedHostname[1..$splittedHostname.length] -join '.'

    if ($contextDomain) {
        Write-LogMessage "* Changing Domain to $contextDomain"

        $networkConfig = Get-WmiObject Win32_NetworkAdapterConfiguration -filter "ipenabled = 'true'"
        $ret = $networkConfig.SetDnsDomain($contextDomain)

        if ($ret.ReturnValue) {

            # Returned Non Zero, Failed, No restart
            Write-LogMessage ("  ... Failed: " + $ret.ReturnValue.ToString())
        }
        else {

            # Returned Zero, Success
            Write-LogMessage "  ... Success"
        }
    }

    # Check for the .opennebula-renamed file
    $loggedHostname = ""
    if (Test-Path "$ctxDir\.opennebula-renamed") {
        Write-LogMessage "- Using the JSON file: $ctxDir\.opennebula-renamed"

        # Grab the JSON content
        $json = Get-Content -Path "$ctxDir\.opennebula-renamed" `
        | Out-String

        # Convert to a Hash Table and set the Logged Hostname
        try {
            $status = $json | ConvertFrom-Json
            $loggedHostname = $status.ComputerName
        }
        # Invalid JSON
        catch [System.ArgumentException] {
            Write-LogMessage " [!] Invalid JSON:"
            Write-Host $json.ToString()
        }
    }
    else {

        # no renaming was ever done - we fallback to our current Hostname
        $loggedHostname = $currentHostname
    }

    if (($currentHostname -ne $contextHostname) -and `
        ($contextHostname -eq $loggedHostname)) {

        # avoid rename->reboot loop - if we detect that rename attempt was done
        # but failed then we drop log message about it and finish...

        Write-LogMessage "* Computer Rename Attempted but failed:"
        Write-LogMessage "- Current: $currentHostname"
        Write-LogMessage "- Context: $contextHostname"
    }
    ElseIf ($contextHostname -ne $currentHostname) {

        # the current_name does not match the context_name, rename the computer

        Write-LogMessage "* Changing Hostname to $contextHostname"
        # Load the ComputerSystem Object
        $ComputerInfo = Get-WmiObject -Class Win32_ComputerSystem

        # Rename the computer
        $ret = $ComputerInfo.rename($contextHostname)

        $contents = @{}
        $contents["ComputerName"] = $contextHostname
        ConvertTo-Json $contents | Out-File "$ctxDir\.opennebula-renamed"

        # Check success
        if ($ret.ReturnValue) {

            # Returned Non Zero, Failed, No restart
            Write-LogMessage ("  ... Failed: " + $ret.ReturnValue.ToString())
            Write-Host "      Check the computername. "
            Write-Host "Possible Issues: The name cannot include control " `
                "characters, leading or trailing spaces, or any of " `
                "the following characters: `" / \ [ ] : | < > + = ; , ?"

        }
        else {

            # Returned Zero, Success
            Write-LogMessage "  ... Success"

            # Restart the Computer
            Write-LogMessage "  ... Rebooting"
            Restart-Computer -Force

            # Exit here so the script doesn't continue to run
            Exit 0
        }
    }
    else {

        # Hostname is set and correct
        Write-LogMessage "* Computer Name already set: $contextHostname"
    }

    Write-Host "`r`n" -NoNewline
}

function Enable-RemoteDesktop {
    Write-LogMessage "* Enabling Remote Desktop"
    # Windows 7 only - add firewall exception for RDP
    Write-LogMessage "- Enable Remote Desktop Rule Group"
    netsh advfirewall Firewall set rule group="Remote Desktop" new enable=yes

    # Enable RDP
    Write-LogMessage "- Enable Allow Terminal Services Connections"
    $ret = (Get-WmiObject -Class "Win32_TerminalServiceSetting" -Namespace root\cimv2\terminalservices).SetAllowTsConnections(1)
    if ($ret.ReturnValue) {
        Write-LogMessage ("  ... Failed: " + $ret.ReturnValue.ToString())
    }
    else {
        Write-LogMessage "  ... Success"
    }
    Write-Host "`r`n" -NoNewline
}

function Enable-SSH {
    Write-LogMessage "* Enabling SSH"
    # Get sshd service
    $serviceName = "sshd"
    $sshdService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    # Check if service is present
    if ($sshdService) {
        # Service is running and automatic start is enabled
        if ($sshdService.StartType -eq "Automatic" -and $sshdService.Status -eq "Running") {
            Write-LogMessage " ... Success (Service is already enabled and running )"
            return
        }
        # Enable autostart
        if ($sshdService.StartType -ne "Automatic") {
            Write-LogMessage "- Enabling automatic start for SSH service"
            Set-Service -Name $serviceName -StartupType Automatic
            if ($?) {
                Write-LogMessage "  ... Success"
            } else {
                Write-LogMessage "  ... Failed"
                return
            }
        }
        # Start service
        if ($sshdService.Status -ne "Running") {
            Write-LogMessage "- Starting SSH service"
            Start-Service -Name $serviceName
            if ($?) {
                Write-LogMessage "  ... Success"
            } else {
                Write-LogMessage "  ... Failed"
            }
        }
    } else {
        # OpenSSH.Server feature is not installed
        Write-LogMessage " ... Failed (OpenSSH Server is not installed)"
    }
}

function Enable-Ping {
    Write-LogMessage "* Enabling Ping"
    #Create firewall manager object
    New-Object -com hnetcfg.fwmgr

    # Get current profile
    $pro = $fwmgcalPolicy.CurrentProfile

    Write-LogMessage "- Enable Allow Inbound Echo Requests"
    $ret = $pro.IcmpSettings.AllowInboundEchoRequest = $true
    if ($ret) {
        Write-LogMessage "  ... Success"
    }
    else {
        Write-LogMessage "  ... Failed"
    }

    Write-Host "`r`n" -NoNewline
}

function Test-ConnectionPing {
    param (
        $IP,
        $Retries = 20
    )

    Write-LogMessage "- Ping Interface IP $IP"

    $ping = $false
    $retry = 0
    do {
        $retry++
        Start-Sleep -s 1
        $ping = Test-Connection -ComputerName $IP -Count 1 -Quiet -ErrorAction SilentlyContinue
    } while (!$ping -and ($retry -lt $Retries))

    if ($ping) {
        Write-LogMessage "  ... Success ($retry tries)"
    }
    else {
        Write-LogMessage "  ... Failed ($retry tries)"
    }
}

function Disable-NetworkIPv6Privacy {
    # Disable Randomization of IPv6 addresses (use EUI-64)
    Write-LogMessage "- Globally disable IPv6 Identifiers Randomization"
    netsh interface ipv6 set global randomizeidentifiers=disable

    if ($?) {
        Write-LogMessage "  ... Success"
    }
    else {
        Write-LogMessage "  ... Failed"
    }

    # Disable IPv6 Privacy Extensions (temporary addresses)
    Write-LogMessage "- Globally disable IPv6 Privacy Extensions"
    netsh interface ipv6 set privacy state=disabled

    if ($?) {
        Write-LogMessage "  ... Success"
    }
    else {
        Write-LogMessage "  ... Failed"
    }
}

function Enable-NetworkIPv6 {
    Write-LogMessage '- Enabling IPv6'

    Enable-NetAdapterBinding -Name $na.NetConnectionId -ComponentID ms_tcpip6

    if ($?) {
        Write-LogMessage "  ... Success"
    }
    else {
        Write-LogMessage "  ... Failed"
    }
}

function Disable-NetworkIPv6 {
    Write-LogMessage '- Disabling IPv6'

    Disable-NetAdapterBinding -Name $na.NetConnectionId -ComponentID ms_tcpip6

    if ($?) {
        Write-LogMessage "  ... Success"
    }
    else {
        Write-LogMessage "  ... Failed"
    }
}

function Invoke-ScriptSetExecution {
    param (
        $Context,
        $ContextPaths
    )
    Write-LogMessage "* Running Scripts"

    # Get list of scripts to run, " " delimited
    $initscripts = $Context["INIT_SCRIPTS"]

    if ($initscripts) {
        # Parse each script and run it
        foreach ($script in $initscripts.split(" ")) {

            # Sanitize the filename (drop any path from them and instead use our directory)
            $script = $ContextPaths.contextInitScriptPath + [System.IO.Path]::GetFileName($script.Trim())

            if (Test-Path $script) {
                Write-LogMessage "- $script"
                Set-EnvironmentContext($Context)
                Invoke-PowerShellWrapper "$script"
            }

        }
    }
    else {
        # Emulate the init.sh fallback behavior from Linux
        $script = $ContextPaths.contextInitScriptPath + "init.ps1"

        if (Test-Path $script) {
            Write-LogMessage "- $script"
            Set-EnvironmentContext($Context)
            Invoke-PowerShellWrapper "$script"
        }
    }

    # Execute START_SCRIPT or START_SCRIPT_64
    $startScript = $Context["START_SCRIPT"]
    $startScript64 = $Context["START_SCRIPT_BASE64"]

    if ($startScript64) {
        $startScript = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($startScript64))
    }

    if ($startScript) {

        # Save the script as .opennebula-startscript.ps1
        $startScriptPS = "$ctxDir\.opennebula-startscript.ps1"
        $startScript | Out-File $startScriptPS "UTF8"

        # Launch the Script
        Write-LogMessage "- $startScriptPS"
        Set-EnvironmentContext($Context)
        Invoke-PowerShellWrapper "$startScriptPS"
        Remove-File "$startScriptPS"
    }
    Write-Host "`r`n" -NoNewline
}

function Resize-Partition {
    param (
        $Disk,
        $Part
    )
    "select disk $Disk", "select partition $Part", "extend" | diskpart | Out-Null
}

function Resize-PartitionSet {
    param (
        $Context
    )
    Write-LogMessage "* Extend partitions"

    "rescan" | diskpart

    $disks = @()

    # Cmdlet 'Get-Partition' is not in older Windows/Powershell versions
    if (Get-Command -ErrorAction SilentlyContinue -Name Get-Partition) {
        if ([string]$Context['GROW_ROOTFS'] -eq '' -or $Context['GROW_ROOTFS'].ToUpper() -eq 'YES') {
            # Add at least system drive
            $drives = "$env:systemdrive $($Context['GROW_FS'])"
        }
        else {
            $drives = "$($Context['GROW_FS'])"
        }

        $driveLetters = (-split $drives | Select-String -Pattern "^(\w):?[\/]?$" -AllMatches | ForEach-Object { $_.matches.groups[1].Value } | Sort-Object -Unique)

        foreach ($driveLetter in $driveLetters) {
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
    else {
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
    foreach ($disk in $disks) {
        foreach ($partId in $disk.partIds) {
            if ($disk.name) {
                Write-LogMessage "- Extend ($($disk.name)) Disk: $($disk.diskId) / Part: $partId"
            }
            else {
                Write-LogMessage "- Extend Disk: $($disk.diskId) / Part: $partId"
            }
            Resize-Partition $disk.diskId $partId
        }
    }
}

function Invoke-ReportReady {
    param (
        $Context,
        $ContextLetter
    )
    $reportReady = $Context['REPORT_READY']
    $oneGateEndpoint = $Context['ONEGATE_ENDPOINT']
    $vmId = $Context['VMID']
    $token = $Context['ONEGATE_TOKEN']
    $retryCount = 3
    $retryWaitPeriod = 10

    if ($reportReady -and $reportReady.ToUpper() -eq 'YES') {
        Write-LogMessage '* Report Ready to OneGate'

        if (!$oneGateEndpoint) {
            Write-LogMessage '  ... Failed: ONEGATE_ENDPOINT not set'
            return
        }

        if (!$vmId) {
            Write-LogMessage '  ... Failed: VMID not set'
            return
        }

        if (!$token) {
            Write-LogMessage "  ... Token not set. Try file"
            $tokenPath = $ContextLetter + 'token.txt'
            if (Test-Path $tokenPath) {
                $token = Get-Content $tokenPath
            }
            else {
                Write-LogMessage "  ... Failed: Token file not found"
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
                    Write-LogMessage "  ... Use HTTPS for OneGateEndpoint report: $oneGateEndpoint"
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
                    Write-LogMessage '  ... Success'
                    break
                }
                else {
                    Write-LogMessage "  ... Failed: $($response.StatusCode)"
                }
            }
            catch {
                $errorMessage = $_.Exception.Message
                Write-LogMessage "  ... Failed: $errorMessage"
            }

            Write-LogMessage "  ... Report ready failed (${retryNumber}. try out of ${retryCount})"
            $retryNumber++
            if ($retryNumber -le $retryCount) {
                Write-LogMessage "  ... sleep for ${retryWaitPeriod} seconds and try again..."
                Start-Sleep -Seconds $retryWaitPeriod
            }
            else {
                Write-LogMessage "  ... All retries failed!"
                break
            }
        }
    }
}

function Dismount-ContextCD {
    param (
        $CdromDrive
    )
    if (-Not $CdromDrive) {
        return
    }

    $eject_cdrom = $context['EJECT_CDROM']

    if ($null -ne $eject_cdrom -and $eject_cdrom.ToUpper() -eq 'YES') {
        Write-LogMessage '* Ejecting context CD'
        try {
            #https://learn.microsoft.com/en-us/windows/win32/api/shldisp/ne-shldisp-shellspecialfolderconstants
            $ssfDRIVES = 0x11
            $sh = New-Object -ComObject "Shell.Application"
            $sh.Namespace($ssfDRIVES).Items() | Where-Object { $_.Type -eq "CD Drive" -and $_.Path -eq $CdromDrive.Name } | ForEach-Object {
                $_.InvokeVerb("Eject")
                Write-LogMessage " ... Ejected $($CdromDrive.Name)"
            }
        }
        catch {
            Write-LogMessage "  ... Failed to eject the CD: $_"
        }
    }
}

function Remove-File($file) {
    param (
        $File
    )
    if (![string]::IsNullOrEmpty($File) -and (Test-Path $File)) {
        Write-LogMessage "* Removing the file: ${File}"
        Remove-Item -Path $File -Force
    }
}

function Remove-Dir {
    param (
        $Dir
    )
    if (![string]::IsNullOrEmpty($Dir) -and (Test-Path $Dir)) {
        Write-LogMessage "* Removing the directory: ${Dir}"
        Remove-Item -Path $Dir -Recurse -Force
    }
}

function Remove-Context {
    param (
        $ContextPaths
    )
    if ($ContextPaths.contextDrive) {
        # Eject CD with 'context.sh' if requested
        Dismount-ContextCD $ContextPaths.contextDrive
    }
    else {
        # Delete 'context.sh' if not on CD-ROM
        Remove-File $ContextPaths.contextPath

        # and downloaded init scripts
        Remove-Dir $ContextPaths.contextInitScriptPath
    }
}

function Invoke-PowerShellWrapper {
    param (
        $Path
    )
    # source:
    #   - http://cosmonautdreams.com/2013/09/03/Getting-Powershell-to-run-in-64-bit.html
    #   - https://ss64.com/nt/syntax-64bit.html
    if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
        # This is only set in a x86 Powershell running on a 64bit Windows

        $realpath = [string]$(Resolve-Path "$Path")

        # Run 64bit powershell as a subprocess and there execute the command
        #
        # NOTE: virtual subdir 'sysnative' exists only when running 32bit binary under 64bit system
        & "$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile -Command "$realpath"
    }
    else {
        & "$Path"
    }
}

function Grant-SSHKeyAdmin {
    param (
        $AuthorizedKeys
    )

    $authorizedKeysPath = "$env:ProgramData\ssh\administrators_authorized_keys"


    $authoriozedKeysDir = Split-Path -Parent -Path $authorizedKeysPath
    if (!(Test-Path $authoriozedKeysDir)) {
        Write-LogMessage "- Directory $authoriozedKeysDir does not exist"
        Write-LogMessage "- Trying to create the directory $authoriozedKeysDir"
        New-Item -ItemType Directory -Path $authoriozedKeysDir
        if ($?) {
            Write-LogMessage "  ... Success"
        }
        else {
            Write-LogMessage "  ... Failed"
        }
    }

    # whitelisting
    Write-LogMessage "- Writing SSH key to $authorizedKeysPath"
    Set-Content $authorizedKeysPath $AuthorizedKeys

    if ($?) {
        # permissions
        icacls.exe $authorizedKeysPath /inheritance:r /grant Administrators:F /grant SYSTEM:F

        Write-LogMessage "  ... Success"
    }
    else {
        Write-LogMessage "  ... Failed"
    }

}

function Disable-SharedAdminSSHKeySet {
    $cfgtoRemoveRegex = ('Match Group administrators\r?\n' + 
                        ' {7}AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys(?:\r?\n)')
    $sshdConfigPath = "$env:PROGRAMDATA\ssh\sshd_config"
    $currentConfig = Get-Content $sshdConfigPath -Raw
    if ($currentConfig -match $cfgtoRemoveRegex) {
        $updatedConfig = $currentConfig -replace $cfgtoRemoveRegex
        Write-LogMessage "- Disabling use of default shared admins_authorized_keys for Administrators group"
        Set-Content -Path $sshdConfigPath -Value $updatedConfig
        if ($?) {
            Write-LogMessage "  ... Success"
        } else {
            Write-LogMessage "  ... Failed"
        }
        $sshdService = Get-Service -Name sshd -ErrorAction SilentlyContinue
        if ($sshdService.Status -eq "Running") {
            Restart-Service $sshdService
        }
    }
}

function Grant-SSHKeyStandard {
    param (
        $AuthorizedKeys,
        $Username
    )

    # Check if user profile directory exists
    $userProfilePath = "$env:systemdrive\Users\$Username"
    if ( !(Test-Path $userProfilePath)) {
        Write-LogMessage "  ... Failed (Userprofile directory $userProfilePath does not exists)"
        return
    }

    # prepare .ssh folder
    $sshFolderPath = "$userProfilePath\.ssh"
    if ( !(Test-Path $sshFolderPath)) {
        Write-LogMessage "- Creating .ssh folder in $userProfilePath"
        New-Item -Force -ItemType Directory -Path $sshFolderPath | Out-Null
        if ($?) {
            Write-LogMessage "  ... Success"
        }
        else {
            Write-LogMessage "  ... Failed"
            return
        }
    }

    # write the keys
    $authorizedKeysFilePath = "$userProfilePath\.ssh\authorized_keys"
    Write-LogMessage "- Writing key to $authorizedKeysFilePath"
    Set-Content -Path $authorizedKeysFilePath -Value $AuthorizedKeys
    if ($?) {
        Write-LogMessage "  ... Success"
    }
    else {
        Write-LogMessage "  ... Failed"
    }
}

function Grant-SSHKey {
    param (
        $AuthorizedKeys,
        $WinAdmin,
        $Username
    )

    Write-LogMessage "* Authorizing SSH_PUBLIC_KEY: ${AuthorizedKeys}"

    if ($WinAdmin -ieq "no") {
        Disable-SharedAdminSSHKeySet
        Grant-SSHKeyStandard $AuthorizedKeys $Username
    }
    else {
        Grant-SSHKeyAdmin $AuthorizedKeys
    }

}

################################################################################
# Main
################################################################################

# global variable pointing to the private .contextualization directory
$global:ctxDir = "$env:SystemDrive\.onecontext"

# Check, if above defined context directory exists
if ( !(Test-Path "$ctxDir") ) {
    mkdir "$ctxDir"
}

# Delete .old log file (if exist) - simple rotation
if (Test-Path "$ctxDir\opennebula-context-old.log") {
    Remove-Item "$ctxDir\opennebula-context-old.log"
}

# Move last logfile away - so we have a current log containing the output of the last boot
if ( Test-Path "$ctxDir\opennebula-context.log" ) {
    mv "$ctxDir\opennebula-context.log" "$ctxDir\opennebula-context-old.log"
}

# Start now logging to logfile
Start-Transcript -Append -Path "$ctxDir\opennebula-context.log" | Out-Null

Write-LogMessage "* Running Script: $($MyInvocation.MyCommand.Path)"

Set-ExecutionPolicy unrestricted -Force # not needed if already done once on the VM
[string]$computerName = "$env:computername"
[string]$ConnectionString = "WinNT://$computerName"

# Check the working WMI
if (-Not (Get-WMIObject -ErrorAction SilentlyContinue Win32_Volume)) {
    Write-LogMessage "- WMI not ready, exiting"
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
    $contextPaths = Wait-ForContext($checksum)

    # Parse context file
    $context = Get-ContextData $contextPaths.contextScriptPath

    # Execute the contextualization actions
    Resize-PartitionSet $context
    Set-TimeZone $context
    Add-LocalUser $context
    Enable-RemoteDesktop
    Enable-SSH
    Enable-Ping
    Set-NetworkConfiguration $context
    Rename-Computer $context
    Invoke-ScriptSetExecution $context $contextPaths
    Grant-SSHKey $context["SSH_PUBLIC_KEY"] $context["WINADMIN"] $context["USERNAME"]
    Invoke-ReportReady $context $contextPaths.contextLetter

    # Save the 'applied' context.sh checksum for the next recontextualization
    Write-LogMessage "* Calculating the checksum of the file: $($contextPaths.contextScriptPath)"
    $checksum = Get-FileHash -Algorithm SHA256 $contextPaths.contextScriptPath
    Write-LogMessage "  ... $($checksum.Hash)"
    # and remove the file itself
    Remove-File $contextPaths.contextScriptPath

    # Cleanup at the end
    Remove-Context $contextPaths

    Write-Host "`r`n" -NoNewline

} while ($true)

Stop-Transcript | Out-Null
