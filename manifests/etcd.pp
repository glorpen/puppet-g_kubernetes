# @summary Configures ETCD
#
# @param firewall_mode
#   Open swarm ports to whole cluster_iface ('interface') or for each other peer node separately ('peer').
#
class g_kubernetes::etcd(
  Hash[String, Stdlib::Host] $servers,
  Stdlib::Host $cluster_addr,
  Integer $client_port = 2379,
  G_server::Side $client_side = 'internal',
  Integer $peer_port = 2380,
  G_server::Side $peer_side = 'internal',
  String $data_dir = '/var/lib/etcd',
  String $config_dir = '/etc/etcd',
  # Optional[String] $wal_dir = undef,
  Hash $options = {},
  Enum['present', 'absent'] $ensure = 'present',

  String $user = 'etcd',
  Optional[Stdlib::AbsolutePath] $unmanaged_etcd_bin = undef,

  Boolean $package_manage = true,
  String $package_version = '3.4.10',
  Optional[String] $package_checksum = undef,
  Boolean $service_manage = true,
  Boolean $manage_firewall = true,
  Enum['interface', 'peer'] $firewall_mode = 'interface',

  Optional[G_kubernetes::CertSource] $client_ca_cert = undef,
  Optional[G_kubernetes::CertSource] $client_cert = undef,
  Optional[G_kubernetes::CertSource] $client_key = undef,
  Boolean $client_cert_auth = false,
  Boolean $client_auto_tls = false,

  Optional[G_kubernetes::CertSource] $peer_ca_cert = undef,
  Optional[G_kubernetes::CertSource] $peer_cert = undef,
  Optional[G_kubernetes::CertSource] $peer_key = undef,
  Boolean $peer_cert_auth = false,
  Boolean $peer_auto_tls = false
) {
  include ::g_server

  # dont use system packages,
  # create user etcd and download given version from vendor

  $ssl_dir = "${config_dir}/ssl"
  $config_file = "${config_dir}/etc.yaml"

  if $package_manage {
    include ::g_kubernetes::etcd::package
  }

  if $service_manage {
    include ::g_kubernetes::etcd::service
  }

  include ::g_kubernetes::etcd::config

  if $manage_firewall {
    $rule_config = {
      'proto'  => tcp,
      'action' => accept,
    }

    if $firewall_mode == 'interface' {
      ['peer', 'client'].each | $type | {
        $side = getvar("::g_kubernetes::etcd::${type}_side")
        $port = getvar("::g_kubernetes::etcd::${type}_port")

        g_server::get_interfaces($side).each | $iface | {
          g_firewall { "006 Allow inbound ETCD ${type} from ${iface}":
            dport   => $port,
            iniface => $iface,
            *       => $rule_config
          }
        }
      }
    } else {
      g_server::get_interfaces($::g_kubernetes::etcd::client_side).each | $iface | {
        g_firewall { "006 Allow inbound ETCD client from ${iface}":
          dport   => $::g_kubernetes::etcd::client_port,
          iniface => $iface,
          *       => $rule_config
        }
      }

      firewallchain { 'ETCD-PEER:filter:IPv4': purge  => true }
      firewallchain { 'ETCD-PEER:filter:IPv6': purge  => true }

      g_server::get_interfaces($::g_kubernetes::etcd::peer_side).each | $iface | {
        g_firewall { "006 Allow inbound ETCD peer from nodes on ${iface}":
          jump    => 'ETCD-PEER',
          iniface => $iface
        }
      }

      $ips = g_server::get_interfaces($::g_kubernetes::etcd::peer_side).map | $iface | {
        $_network_info = $::facts['networking']['interfaces'][$iface]
        Hash(['', '6'].map |$t| {
          [
            $t,
            $_network_info["bindings${t}"].map | $c | {
              $c['address']
            }
          ]
        })
      }.reduce({'' => [], '6' => []}) | $memo, $c | {
        {
          '' => $memo[''] + $c[''],
          '6' => $memo['6'] + $c['6']
        }
      }

      $config = merge($rule_config, {
        dport => $::g_kubernetes::etcd::peer_port,
        tag => 'g_kubernetes::etcd::peer'
      })
      $rule_name = "006 Allow inbound ETCD peer from ${::fqdn}"

      if ($ips[''].length > 0) {
        @@g_firewall::ipv4 { $rule_name:
          source => $ips[''],
          *      => $config
        }
      }
      if ($ips['6'].length > 0) {
        @@g_firewall::ipv6 { $rule_name:
          source => $ips['6'],
          *      => $config
        }
      }

      puppetdb_query("resources[type, title, parameters]{exported=true and tag='g_kubernetes::etcd::peer' and certname !='${trusted['certname']}'}").each | $info | {
        ensure_resource($info['type'], $info['title'], merge($info['parameters'], {
          chain  => 'ETCD-PEER'
        }))
      }
    }
  }

  if $ensure == 'present' {
    Class['G_kubernetes::Etcd::Package']
    ->Class['G_kubernetes::Etcd::Config']
    ~>Class['G_kubernetes::Etcd::Service']
  } else {
    Class['G_kubernetes::Etcd::Service']
    ->Class['G_kubernetes::Etcd::Config']
    ->Class['G_kubernetes::Etcd::Package']
  }
}
