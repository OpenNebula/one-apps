# frozen_string_literal: true

# Attribute sets whose rendered frr.conf is pinned by spec/fixtures/golden/<name>.conf.
module GoldenCases
    P    = 'ONEAPP_VNF_BGP_'
    BASE = { "#{P}ENABLED" => 'YES', "#{P}ASN" => '65010', "#{P}ROUTER_ID" => '10.99.37.2' }.freeze

    N0 = { "#{P}NEIGHBOR0_ADDRESS" => '10.99.37.1', "#{P}NEIGHBOR0_ASN" => '65100' }.freeze
    N1 = { "#{P}NEIGHBOR1_ADDRESS" => '10.99.37.3', "#{P}NEIGHBOR1_ASN" => '65101' }.freeze
    V6 = { "#{P}NEIGHBOR1_ADDRESS" => 'fd77::21', "#{P}NEIGHBOR1_ASN" => '65002' }.freeze

    STATIC = { 'ONEAPP_VNF_STATIC_ROUTES' => '2001:db8::/32 via fd77::1, 1.1.1.1/32 via 172.16.100.1' }.freeze

    O  = 'ONEAPP_VNF_OSPF_'
    OB = { "#{O}ENABLED" => 'YES', "#{O}ROUTER_ID" => '10.99.37.2', "#{O}INTERFACE0_NAME" => 'eth1' }.freeze

    def self.bgp(*parts) = parts.reduce(BASE.dup) { |acc, part| acc.merge(part) }

    CASES = {
        'bgp-minimal' => { attrs: bgp(N0) },
        'bgp-neighbor-options' => {
            attrs: bgp(N0, "#{P}NEIGHBOR0_DESCRIPTION" => 'MCCP uplink', "#{P}NEIGHBOR0_PASSWORD" => 's3cret',
                           "#{P}NEIGHBOR0_TIMERS" => '10 30', "#{P}NEIGHBOR0_UPDATE_SOURCE" => 'eth1',
                           "#{P}NEIGHBOR0_MAX_PREFIX" => '1000')
        },
        'bfd-default' => { attrs: bgp(N0, "#{P}NEIGHBOR0_BFD" => 'YES') },
        'bfd-profile' => { attrs: bgp(N0, "#{P}NEIGHBOR0_BFD" => 'YES', "#{P}NEIGHBOR0_BFD_TIMERS" => '5 200 200') },
        'prefix-lists' => {
            attrs: bgp(N0, "#{P}NEIGHBOR0_IMPORT_PREFIXES" => '0.0.0.0/0,10.0.0.0/8 le 24',
                           "#{P}NEIGHBOR0_EXPORT_PREFIXES" => '192.0.2.0/24', "#{P}NEIGHBOR0_LOCAL_PREF" => '200',
                           "#{P}NEIGHBOR0_MED" => '50', "#{P}NEIGHBOR0_PREPEND" => '2')
        },
        'ha-backup' => {
            attrs: bgp(N0, "#{P}NEIGHBOR0_MED" => '50', "#{P}NEIGHBOR0_PREPEND" => '1',
                           "#{P}BACKUP_PREPEND" => '2', "#{P}BACKUP_MED" => '300'),
            ha_state: :backup
        },
        'two-v4-neighbors' => { attrs: bgp(N0, N1) },
        'ipv6-only' => {
            attrs: bgp({ "#{P}NEIGHBOR0_ADDRESS" => 'fd77::21', "#{P}NEIGHBOR0_ASN" => '65002' },
                       "#{P}NETWORKS" => '2001:db8::/48')
        },
        'dual-stack' => {
            attrs: bgp(N0, V6, "#{P}REDISTRIBUTE" => 'connected,static', "#{P}NETWORKS" => '10.20.0.0/24, 2001:db8::/48')
        },
        'deny-other-family' => {
            attrs: bgp({ "#{P}NEIGHBOR0_ADDRESS" => 'fd77::21', "#{P}NEIGHBOR0_ASN" => '65002' },
                       "#{P}NEIGHBOR0_IMPORT_PREFIXES" => '192.0.2.0/24')
        },
        'ipv6-bfd-profile-iface' => {
            attrs: bgp({ "#{P}NEIGHBOR0_ADDRESS" => 'fd77::21', "#{P}NEIGHBOR0_ASN" => '65002' },
                       "#{P}NEIGHBOR0_BFD" => 'YES', "#{P}NEIGHBOR0_BFD_TIMERS" => '5 200 200',
                       "#{P}NEIGHBOR0_UPDATE_SOURCE" => 'eth1')
        },
        'static-only' => { attrs: STATIC.dup },
        'static-and-bgp' => { attrs: bgp(N0, STATIC) },
        'networks-redistribute' => {
            attrs: bgp(N0, "#{P}NETWORKS" => '10.20.0.0/24', "#{P}REDISTRIBUTE" => 'connected,static,kernel')
        },
        'header-only' => { attrs: { 'ONEAPP_VNF_STATIC_ROUTES' => 'NONE' } },
        'bgp-disabled-with-keys' => {
            attrs: { "#{P}ENABLED" => 'NO', "#{P}ASN" => '65010' }.merge(STATIC)
        },
        'ospf-minimal' => { attrs: OB.dup },
        'ospf-two-interfaces' => {
            attrs: OB.merge("#{O}INTERFACE0_AREA" => '0.0.0.1', "#{O}INTERFACE1_NAME" => 'eth2', "#{O}INTERFACE1_COST" => '25')
        },
        'ospf-passive' => { attrs: OB.merge("#{O}INTERFACE0_PASSIVE" => 'YES') },
        'ospf-p2p-timers' => {
            attrs: OB.merge("#{O}INTERFACE0_NETWORK_TYPE" => 'point-to-point', "#{O}INTERFACE0_HELLO_INTERVAL" => '5',
                            "#{O}INTERFACE0_DEAD_INTERVAL" => '20')
        },
        'ospf-auth-bfd' => { attrs: OB.merge("#{O}INTERFACE0_PASSWORD" => 'sekret', "#{O}INTERFACE0_BFD" => 'YES') },
        'ospf-default-originate-always' => { attrs: OB.merge("#{O}DEFAULT_ORIGINATE" => 'ALWAYS') },
        'ospf-redistribute' => {
            attrs: OB.merge("#{O}REDISTRIBUTE" => 'connected static', "#{O}DEFAULT_ORIGINATE" => 'YES')
        },
        'ospf-ha-backup' => {
            attrs: OB.merge("#{O}INTERFACE0_COST" => '20', "#{O}BACKUP_COST" => '150'), ha_state: :backup
        },
        'ospf-ha-backup-external' => {
            attrs: OB.merge("#{O}INTERFACE0_COST" => '20', "#{O}BACKUP_COST" => '150', "#{O}REDISTRIBUTE" => 'connected static',
                            "#{O}DEFAULT_ORIGINATE" => 'ALWAYS'),
            ha_state: :backup
        },
        'ospf-shared-router-id' => {
            attrs: { "#{O}ENABLED" => 'YES', "#{O}INTERFACE0_NAME" => 'eth1', 'ONEAPP_VNF_FRR_ROUTER_ID' => '10.99.37.9' }
        },
        'static-ospf-bgp' => { attrs: bgp(N0, STATIC, OB) },
        'ospf-disabled-with-keys' => {
            attrs: { "#{O}ENABLED" => 'NO', "#{O}INTERFACE0_NAME" => 'eth1', "#{O}INTERFACE0_COST" => 'x' }.merge(STATIC)
        }
    }.freeze
end
