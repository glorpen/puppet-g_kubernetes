function g_kubernetes::certpath(
  Stdlib::Path $ssl_dir,
  String $name,
  Optional[G_kubernetes::CertSource] $source = undef
){
  case $source {
    undef: { undef }
    Stdlib::Path: { $source }
    default: { "${ssl_dir}/${name}.pem" }
  }
}
