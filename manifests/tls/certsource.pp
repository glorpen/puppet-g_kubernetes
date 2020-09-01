define g_kubernetes::tls::certsource(
  G_kubernetes::CertSource $source,
  Hash $options = {}
) {
  if $source =~ Stdlib::Absolutepath or $source == Undef {
    if $source != Undef and $source != $title {
      fail('When using absolute paths as CertSource source parameter it should be the same as title or be undefined')
    }
    if defined(File[$title]) {
      File[$title]
      ~>G_kubernetes::Tls::Certsource[$title]
    }
  } elsif $source =~ Stdlib::Filesource {
    file { $title:
      source => $source,
      *      => $options
    }
  } else {
    file { $title:
      content => $source,
      *       => $options
    }
  }
}
