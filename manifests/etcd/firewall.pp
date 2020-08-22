class g_kubernetes::etcd::firewall {

  $ensure = $::g_kubernetes::etcd::ensure
  $peer_firewall_mode = $::g_kubernetes::etcd::peer_firewall_mode
  $peer_side = $::g_kubernetes::etcd::peer_side
  $peer_port = $::g_kubernetes::etcd::peer_port
  $client_firewall_mode = $::g_kubernetes::etcd::client_firewall_mode
  $client_side = $::g_kubernetes::etcd::client_side
  $client_port = $::g_kubernetes::etcd::client_port

  $rule_config = {
    'proto'  => 'tcp',
    'action' => 'accept',
  }

  case $peer_firewall_mode {
    'interface': {
      g_server::get_interfaces($peer_side).each | $iface | {
        g_firewall { "106 Allow inbound ETCD peer from ${iface}":
          ensure  => $ensure,
          dport   => $peer_port,
          iniface => $iface,
          *       => $rule_config
        }
      }
    }
    'node': {
      puppetdb_query("resources[title, parameters]{
        exported=true and certname!='${trusted['certname']}'
        and type='G_kubernetes::Etcd::Node::Peer'
      }").each | $info | {
        g_server::get_interfaces($peer_side).each | $iface | {
          $info['parameters']['ips'].each | $index, $ip | {
            g_firewall { "106 Allow inbound ETCD peer from ${info['title']} #${index} on ${iface}":
              ensure        => $ensure,
              source        => $ip,
              proto_from_ip => $ip,
              dport         => $peer_port,
              *             => $rule_config
            }
          }
        }
      }
    }
    default: {}
  }

  case $client_firewall_mode {
    'interface': {
      g_server::get_interfaces($client_side).each | $iface | {
        g_firewall { "106 Allow inbound ETCD client from ${iface}":
          ensure  => $ensure,
          dport   => $client_port,
          iniface => $iface,
          *       => $rule_config
        }
      }
    }
    'node': {
      puppetdb_query("resources[title, parameters]{
        exported=true and certname !='${trusted['certname']}'
        and type='G_kubernetes::Etcd::Node::Client'
      }").each | $info | {
        g_server::get_interfaces($client_side).each | $iface | {
          $info['parameters']['ips'].each | $index, $ip | {
            g_firewall { "106 Allow inbound ETCD client from ${info['title']} #${index} on ${iface}":
              ensure        => $ensure,
              source        => $ip,
              proto_from_ip => $ip,
              dport         => $client_port,
              *             => $rule_config
            }
          }
        }
      }
    }
    default: {}
  }
}
