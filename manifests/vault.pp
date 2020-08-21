class g_kubernetes::vault (
  Enum['present', 'absent'] $ensure = 'present',
  String $package_version = '1.5.0',
  Optional[String] $package_checksum = undef,
  Optional[Array[String]] $etcd_urls = undef,
  Stdlib::AbsolutePath $config_dir = '/etc/vault',

  Integer $cluster_port = 8201,
  G_server::Side $cluster_side = 'internal',
  Integer $api_port = 8200,
  G_server::Side $api_side = 'internal',

  Boolean $disable_mlock = false,
  String $log_level = 'warn',
  G_kubernetes::Duration $default_lease_ttl = '768h',
  G_kubernetes::Duration $max_lease_ttl = '768h',
  G_kubernetes::Duration $default_max_request_duration = '90s',

  Optional[G_kubernetes::CertSource] $node_cert = undef,
  Optional[G_kubernetes::CertSource] $node_key = undef,
  Optional[G_kubernetes::CertSource] $client_ca_cert = undef,

  Enum['interface', 'peer', 'none'] $firewall_cluster_mode = 'interface',
  Enum['interface', 'peer', 'none'] $firewall_api_mode = 'interface',
) {
  $ssl_dir = "${config_dir}/ssl"

  $cluster_ip = g_server::get_interfaces($cluster_side).map | $iface | {
    $::facts['networking']['interfaces'][$iface]['ip']
  }[0]

  g_kubernetes::vault::peer { $::trusted['certname']:
    ensure => $ensure,
    ips    => [$cluster_ip]
  }

  include ::g_kubernetes::vault::package
  include ::g_kubernetes::vault::config
  include ::g_kubernetes::vault::service

  if $ensure == 'present' {
    Class[::g_kubernetes::vault::package]
    ->Class[::g_kubernetes::vault::config]

    Class[::g_kubernetes::vault::config]
    ~>Class[::g_kubernetes::vault::service]

    Class[::g_kubernetes::vault::package]
    ~>Class[::g_kubernetes::vault::service]

    case $firewall_cluster_mode {
      'interface': {
        g_server::get_interfaces($cluster_side).map | $iface | {
          g_firewall { "105 allow Vault server-server communication on ${iface}":
            dports  => [$cluster_port],
            iniface => $iface
          }
        }
      }
      'peer': {
        puppetdb_query("resources[title, parameters] {
          type='G_kubernetes::Vault::Peer' and parameters.ensure='present'
        }").each | $info | {
          g_server::get_interfaces($cluster_side).map | $iface | {
            $info['parameters']['ips'].each | $ip | {
              g_firewall::ipv4 { "105 allow Vault api communication on ${iface} for ${info['title']}":
                dports        => [$cluster_port],
                iniface       => $iface,
                source        => $ip,
                action        => 'ACCEPT',
                proto_from_ip => $ip
              }
            }
          }
        }
      }
      default: {}
    }

    case $firewall_api_mode {
      'interface': {
        g_server::get_interfaces($api_side).map | $iface | {
          g_firewall { "105 allow Vault api communication on ${iface}":
            dports  => [$api_port],
            iniface => $iface,
            action  => 'ACCEPT'
          }
        }
      }
      'peer': {
        puppetdb_query("resources[title, parameters] {
          type='G_kubernetes::Vault::Client'
        }").each | $info | {
          g_server::get_interfaces($api_side).map | $iface | {
            $info['parameters']['ips'].each | $ip | {
              g_firewall { "105 allow Vault api communication on ${iface} for ${info['title']}":
                dports        => [$api_port],
                iniface       => $iface,
                source        => $ip,
                action        => 'ACCEPT',
                proto_from_ip => $ip
              }
            }
          }
        }
      }
      default: {}
    }
  } else {
    Class[::g_kubernetes::vault::service]
    ->Class[::g_kubernetes::vault::config]
    ->Class[::g_kubernetes::vault::package]
  }
}
