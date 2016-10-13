application rgbank (
  $lb_port      = '80',
  $db_username  = 'test',
  $db_password  = 'test',
  $use_docker   = false,
  $docker_image = 'ccaum/rgbank-web',
) {

  $db_component   = collect_component_titles($nodes, Rgbank::Db)[0] #Assume we only have one
  $web_components = collect_component_titles($nodes, Rgbank::Web)
  $load_component = collect_component_titles($nodes, Rgbank::Load)[0] #Assume we only have one

  rgbank::db { $db_component:
    user     => $db_username,
    password => $db_password,
    export   => Database[$db_component],
  }

  $web_https = $web_components.map |$comp_name| {
    $http = Http["rgbank-web-${comp_name}"]

    rgbank::web { $comp_name:
      use_docker   => $use_docker,
      docker_image => $docker_image,
      listen_port  => $use_docker ? {
        true  =>  seeded_rand('65535', $comp_name),
        false => '80'
      },
      consume      => Database[$db_component],
      export       => $http,
    }

    #Return HTTP service resource
    $http
  }

  rgbank::load { $load_component:
    balancermembers => $web_https,
    port            => $lb_port,
    require         => $web_https,
    export          => Http[$load_component],
  }
}
