# @api private
class g_kubernetes::vault::config {
  include ::stdlib

  $api_port = $::g_kubernetes::vault::api_port
  $peer_port = $::g_kubernetes::vault::peer_port
  $ssl_dir = $::g_kubernetes::vault::ssl_dir
  $node_key = $::g_kubernetes::vault::node_key
  $node_cert = $::g_kubernetes::vault::node_cert
  $client_ca_cert = $::g_kubernetes::vault::client_ca_cert
  $conf_d_dir = $::g_kubernetes::vault::conf_d_dir
  $ensure = $::g_kubernetes::vault::ensure
  $export_etcd_client = $::g_kubernetes::vault::export_etcd_client

  $ensure_directory = $ensure?{
    'present' => 'directory',
    default => 'absent'
  }
  file { [$::g_kubernetes::vault::config_dir, $conf_d_dir]:
    ensure  => $ensure_directory,
    purge   => true,
    recurse => true,
    force   => true
  }

  if $::g_kubernetes::vault::etcd_urls == undef {
    $etcd_urls = flatten(puppetdb_query("resources[parameters]{exported=true and type='G_kubernetes::Etcd::Node::Peer' }").map | $info | {
      $info['parameters']['client_ips'].map |$ip| {
        "${info['parameters']['client_scheme']}://${ip}:${info['parameters']['client_port']}"
      }
    })
  } else {
    $etcd_urls = $::g_kubernetes::vault::etcd_urls
  }

  if $export_etcd_client {
    @@g_kubernetes::etcd::node::client { $::trusted['certname']:
      ips => $::g_kubernetes::vault::peer_ips
    }
  }

  if $node_cert and $node_key {
    $tls_node_options = {
      'tls_disable' => false,
      'tls_cert_file' => g_kubernetes::certpath($ssl_dir, 'peer-cert', $node_cert), # peer cert + CA cert
      'tls_key_file' => g_kubernetes::certpath($ssl_dir, 'peer-key', $node_key),
    }
  } else {
    $tls_node_options = {
      'tls_disable' => true
    }
  }

  if $client_ca_cert {
    $tls_client_options = {
      'tls_client_ca_file' => g_kubernetes::certpath($ssl_dir, 'client-ca-cert', $client_ca_cert),
      'tls_disable_client_certs' => false,
      'tls_require_and_verify_client_cert' => true
    }
  } else {
    $tls_client_options = {
      'tls_disable_client_certs' => true,
      'tls_require_and_verify_client_cert' => false
    }
  }

  g_kubernetes::vault::config::object { 'storage':
    ensure => $ensure,
    config => {
      'storage'   => {
        'etcd' => {
          'address'    => $etcd_urls.join(','),
          'ha_enabled' => true,
          'path'       => '/vault/'
        }
      }
    }
  }

  g_kubernetes::vault::config::object { 'telemetry':
    ensure => $ensure,
    config => {
      'telemetry' => {
        'usage_gauge_period'        => '10m',
        'maximum_gauge_cardinality' => 500,
        'disable_hostname'          => false,
        'enable_hostname_label'     => false
      },
    }
  }

  g_kubernetes::vault::config::object { 'other':
    ensure => $ensure,
    config => {
      # 'ui'                           => false,
      'log_level'                    => $::g_kubernetes::vault::log_level,
      'default_lease_ttl'            => $::g_kubernetes::vault::default_lease_ttl,
      'max_lease_ttl'                => $::g_kubernetes::vault::max_lease_ttl,
      'default_max_request_duration' => $::g_kubernetes::vault::default_max_request_duration,
    }
  }

  g_kubernetes::vault::config::object { 'cluster':
    ensure => $ensure,
    config => {
      'cluster_addr' => "https://${::g_kubernetes::vault::peer_ips[0]}:${peer_port}", # schema is ignored
      'listener'     => {
        'tcp' => merge(
          {
            'address'         => "0.0.0.0:${api_port}",
            'cluster_address' => "0.0.0.0:${peer_port}",
          },
          $tls_node_options,
          $tls_client_options
        )
      }
    }
  }
}
