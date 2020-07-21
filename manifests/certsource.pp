define g_kubernetes::certsource(
  G_kubernetes::CertSource $source,
  Hash $options = {}
) {
  if $source =~ Stdlib::Filesource {
    file { $title:
      source => $source,
      *      => $options
    }
  } elsif $source !~ Stdlib::Path {
    file { $title:
      content => $source,
      *       => $options
    }
  }
}
