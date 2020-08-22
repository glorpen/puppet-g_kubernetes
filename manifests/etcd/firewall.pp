class g_kubernetes::etcd::firewall {

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
          dport   => $peer_port,
          iniface => $iface,
          *       => $rule_config
        }
      }
    }
    'node': {
      firewallchain { 'ETCD-PEER:filter:IPv4': purge  => true }
      firewallchain { 'ETCD-PEER:filter:IPv6': purge  => true }

      g_server::get_interfaces($peer_side).each | $iface | {
        g_firewall { "106 Allow inbound ETCD peer from nodes on ${iface}":
          jump    => 'ETCD-PEER',
          iniface => $iface
        }
      }

      puppetdb_query("resources[title, parameters]{
        exported=true and and certname!='${trusted['certname']}'
        and type='G_kubernetes::Etcd::Node::Peer' and parameters.ensure=='present'
      }").each | $info | {
        $info['parameters']['ips'].each | $index, $ip | {
          g_firewall { "106 Allow inbound ETCD peer from ${info['title']} #${index}":
            source        => $ip,
            proto_from_ip => $ip,
            dport         => $peer_port,
            chain         => 'ETCD-PEER',
            *             => $rule_config
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
          dport   => $client_port,
          iniface => $iface,
          *       => $rule_config
        }
      }
    }
    'node': {
      firewallchain { 'ETCD-CLIENT:filter:IPv4': purge  => true }
      firewallchain { 'ETCD-CLIENT:filter:IPv6': purge  => true }

      g_server::get_interfaces($peer_side).each | $iface | {
        g_firewall { "106 Allow inbound ETCD client from nodes on ${iface}":
          jump    => 'ETCD-CLIENT',
          iniface => $iface
        }
      }

      puppetdb_query("resources[title, parameters]{
        exported=true and certname !='${trusted['certname']}'
        and type='G_kubernetes::Etcd::Client'
      }").each | $info | {
        $info['parameters']['ips'].each | $index, $ip | {
          g_firewall { "106 Allow inbound ETCD client from ${title} #${index}":
            source        => $ip,
            proto_from_ip => $ip,
            chain         => 'ETCD-CLIENT',
            dport         => $client_port,
            *             => $rule_config
          }
        }
      }
    }
    default: {}
  }
}
