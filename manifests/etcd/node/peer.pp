define g_kubernetes::etcd::node::peer (
  Arary[Stdlib::IP::Address::Nosubnet] $ips,
  String $schema,
  Integer $port,
  Enum['present', 'absent'] $ensure = 'present',
) {}
