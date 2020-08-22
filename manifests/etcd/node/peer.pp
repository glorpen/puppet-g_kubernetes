define g_kubernetes::etcd::node::peer (
  Array[Stdlib::IP::Address::Nosubnet] $ips,
  Enum['http','https'] $scheme,
  Integer $port,
) {}
