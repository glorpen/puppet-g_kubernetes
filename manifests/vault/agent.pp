class g_kubernetes::vault::agent(
  Stdlib::HTTPUrl $vault_address,
  String $role_id,
  String $role_secret,
  Enum['present', 'absent'] $ensure = 'present',
  Stdlib::AbsolutePath $config_dir = '/etc/vault-agent',
  Optional[String] $version = undef,
  Optional[String] $checksum = undef,
  Optional[String] $mount_path = undef,
  Optional[String] $namespace = undef,
  Hash[String, G_kubernetes::Vault::Template] $templates = {},
  G_kubernetes::Duration $wrap_ttl = '1h'
){
  if defined(Class['g_kubernetes::vault']) {
    if $version != undef or $checksum != undef {
      fail('Package parameters are already defined by g_kubernetes::vault')
    }
  } else {
    class { 'g_kubernetes::vault::package':
      ensure   => $ensure,
      version  => $version,
      checksum => $checksum
    }
  }

  $_vault_token = "${config_dir}/.token"
  $templates_dir = "${config_dir}/templates"

  $ensure_directory = $ensure?{
    'present' => 'directory',
    default => 'absent'
  }
  file { [$config_dir, $templates_dir]:
    ensure  => $ensure_directory,
    purge   => true,
    recurse => true,
    force   => true
  }

  if $role_id and $role_secret {
    $_role_id_file = "${config_dir}/.role-id"
    $_role_secret_file = "${config_dir}/.role-secret"
    file { $_role_id_file:
      ensure  => $ensure,
      content => $role_id
    }
    file { $_role_secret_file:
      ensure  => $ensure,
      content => $role_secret
    }

    $auth_method = 'approle'
    $auth_config = {
      'role_id_file_path' => $_role_id_file,
      'secret_id_file_path' => $_role_secret_file,
      'remove_secret_id_file_after_reading' => false
    }
  }

  $_common_template_config = {
    'create_dest_dirs'     => false,
    'error_on_missing_key' => true,
  }

  $templates_config = $templates.map |$name, $conf| {
    $template_path = "${templates_dir}/${name}.ctpl"

    file { $template_path:
      ensure  => $ensure,
      source  => $conf['source'],
      content => $conf['content']
    }

    $wait_before_render = pick($conf['wait_before_render'], 0)
    $wait_before_command = pick($conf['wait_before_command'], 0)

    merge({
      'source'               => $template_path,
      'destination'          => $conf['destination'],
      'perms'                => $conf['perms'],
      'backup'               => $conf['backup'] == true,
      'command'              => $conf['command'],
      'command_timeout'      => pick($conf['command_timeout'], '30s'),
      'left_delimiter'       => pick($conf['left_delimiter'], '{{'),
      'right_delimiter'      => pick($conf['right_delimiter'], '}}'),
      'wait'                 => "${wait_before_render}:${wait_before_command}"
    }, $_common_template_config)
  }

  $config = to_json_pretty({
    'vault' => {
      'address' => $vault_address,
    },
    'auto_auth' => {
      'method' => {
        'wrap_ttl' => $wrap_ttl,
        'namespace' => $namespace,
        'mount_path' => $mount_path?{
          undef => "auth/${auth_method}",
          default => $mount_path
        },
        'type' => $auth_method,
        'config' => $auth_config
      },
      'sink' => [
        {
          'type' => 'file',
          'config' => {
            'path' => $_vault_token
          }
        }
      ]
    },
    'template' => $templates_config
  })
}
