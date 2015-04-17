# class percona master
# this class is set just for the first host.

class percona::master inherits percona {

  exec { 'init percona db':
    command => 'mysql_install_db',
    path    => [ '/bin', '/usr/bin' ],
    unless  => "test -f ${percona::datadir}/${percona::percona_host_table}",
    require => [File[$percona::percona_conf],File[$percona::datadir]],
    timeout => 0
  }

  exec { $percona::percona_service:
    command => 'service mysql start --wsrep-new-cluster',
    path    => [ '/bin', '/usr/bin', '/sbin', '/usr/sbin', ],
    require => [File[$percona::percona_conf],Exec['init percona db'],File[$percona::datadir]],
  }

  exec { 'init user sstuser':
    command => "mysql -u root -e \"CREATE USER \'${percona::wsrep_sst_user}\'@\'localhost\' IDENTIFIED BY \'${percona::wsrep_sst_password}\';\"",
    path    => [ '/bin', '/usr/bin' ],
    unless  => "test -f ${percona::datadir}/first/db.opt",
    require => Exec[$percona::percona_service]
  } ->
  exec { 'grant privileges':
    command => "mysql -u root -e \"GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO \'${percona::wsrep_sst_user}\'@\'localhost\';\"",
    path    => [ '/bin', '/usr/bin' ],
    unless  => "test -f ${percona::datadir}/first/db.opt",
    require => Exec[$percona::percona_service],
  } ~>
  exec { 'grant process':
    command => "mysql -u root -e \"GRANT PROCESS ON *.* TO 'clustercheckuser'@'localhost' IDENTIFIED BY 'CLUSTERCHECK_PWD'; FLUSH PRIVILEGES;\"",
    path    => [ '/bin', '/usr/bin' ],
    unless  => "test -f ${percona::datadir}/first/db.opt",
    require => Exec[$percona::percona_service],
  } ~>
  exec { 'create a firt database':
    command => "mysql -u root -e \"CREATE DATABASE first\"",
    path    => [ '/bin', '/usr/bin' ],
    unless  => "test -f ${percona::datadir}/first/db.opt",
    require => Exec[$percona::percona_service],
  }

  if ($percona::root_password) {
    exec {'set-percona-root-password':
      command => "mysqladmin -u root password \"${percona::root_password}\"",
      path    => ['/usr/bin'],
      onlyif  => 'mysqladmin -u root status 2>&1 > /dev/null',
      require => Exec[$percona::percona_service]
    }
  }
}
