define g_kubernetes::etcd::node::peer (
  Array[Stdlib::IP::Address::Nosubnet] $ips,
  String $schema,
  Integer $port,
) {}
