class g_kubernetes::vault::firewall {

  $peer_port = $::g_kubernetes::vault::peer_port
  $peer_side = $::g_kubernetes::vault::peer_side
  $api_port = $::g_kubernetes::vault::api_port
  $api_side = $::g_kubernetes::vault::api_side

  case $::g_kubernetes::vault::peer_firewall_mode {
    'interface': {
      g_server::get_interfaces($peer_side).map | $iface | {
        g_firewall { "105 allow Vault server-server communication on ${iface}":
          dport   => $peer_port,
          iniface => $iface
        }
      }
    }
    'peer': {
      puppetdb_query("resources[title, parameters] {
        type='G_kubernetes::Vault::Peer' and exported=true and parameters.ensure='present'
      }").each | $info | {
        g_server::get_interfaces($peer_side).map | $iface | {
          $info['parameters']['ips'].each | $index, $ip | {
            g_firewall::ipv4 { "105 allow Vault api communication on ${iface} for ${info['title']} #${index}":
              dport         => $peer_port,
              iniface       => $iface,
              source        => $ip,
              action        => 'accept',
              proto_from_ip => $ip
            }
          }
        }
      }
    }
    default: {}
  }

  case $::g_kubernetes::vault::api_firewall_mode {
    'interface': {
      g_server::get_interfaces($api_side).map | $iface | {
        g_firewall { "105 allow Vault api communication on ${iface}":
          dport   => $api_port,
          iniface => $iface,
          action  => 'accept'
        }
      }
    }
    'client': {
      puppetdb_query("resources[title, parameters] {
        type='G_kubernetes::Vault::Client' and exported=true
      }").each | $info | {
        g_server::get_interfaces($api_side).map | $iface | {
          $info['parameters']['ips'].each | $index, $ip | {
            g_firewall { "105 allow Vault api communication on ${iface} for ${info['title']} #${index}":
              dport         => $api_port,
              iniface       => $iface,
              source        => $ip,
              action        => 'accept',
              proto_from_ip => $ip
            }
          }
        }
      }
    }
    default: {}
  }
}
