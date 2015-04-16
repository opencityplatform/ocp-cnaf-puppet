# Puppet Keepalived

## Starting Module

We develope this module starting the:
[arioch/keepalived module in puppetlabs] https://forge.puppetlabs.com/arioch/keepalived

## Document HAProxy Keepalived:

* [Documentation](http://support.severalnines.com/entries/23612682-Install-HAProxy-and-Keepalived-Virtual-IP-) 

## Requirements

* [concat module](https://github.com/ripienaar/puppet-concat)

## Tested on...

* SL6
* CentOs 6

the module should works fine also with:
* Debian 7 (Wheezy)
* Debian 6 (Squeeze)
* RHEL6

## Example usage with foreman

### Donwload the module from git and copy the module in the puppet module directory:

    $ git clone https://github.com/opencityplatform/ocp-cnaf-puppet.git
    $ cp -r keepalived /etc/puppet/environments/production/modules/

### Import the module in foreman

Inside foreman web application go ti Configure -> Puppet classes
Push the import button. (Import from <puppetmester host>
Check the Add to keepalived line and click Import.

### Configure the module with your parameters:

You can change all the parameter you want in all the class. But the mandatory ones are:

* In keepalived::global_defs module set the parameter notification email to an email address of the clusters administrator.
* In keepalived::vrrp::instance check the interface, by deafult is eth0, but could be em1 or eth1 or something else
* In keepalived::vrrp::instance the priority for the fist host is 100 remember to put higher priority for the other host in cluster
* In keepalived::vrrp::instance set the unicast_peers like and array of ip adresses of your servers in the cluster like: ["192.168.10.15","192.168.10.16","192.168.10.17"]
* In keepalived::vrrp::instance set the virtual_ipaddress this is the VIP of the cluster
* In keepalived::vrrp::script set the name variable for example chk_haproxy
* In keepalived::vrrp::script set the script variable for example with the script (killall -0 haproxy) useful for check haproxy processes

### Assign to each host in the cluster the modules

* enter in host page. Choose the host designed to be part of cluster keepalived (haproxy)
* Edit the host
* Go to Puppet classes
* Add the classes: keepalived, keepalived::global_defs, keepalived::vrrp::instance, keepalived::vrrp::script
* If you are configuring the second or thrid host go to Parameters tabs and override the priority to higher value i.e. 101 or 110
* Run puppet agent -t on the host, or wait 20 minutes puppet will run automaticaly.

## Configure the module with puppet without using foreman:

This configuration will fail-over when:

a. Master node is unavailable

```puppet
node /node01/ {
  include keepalived

  keepalived::vrrp::instance { 'VI_50':
    interface         => 'eth1',
    state             => 'MASTER',
    virtual_router_id => '50',
    priority          => '101',
    auth_type         => 'PASS',
    auth_pass         => 'secret',
    virtual_ipaddress => [ '10.0.0.1/29' ],
    track_interface   => ['eth1','tun0'], # optional, monitor these interfaces.
  }
}

node /node02/ {
  include keepalived

  keepalived::vrrp::instance { 'VI_50':
    interface         => 'eth1',
    state             => 'BACKUP',
    virtual_router_id => '50',
    priority          => '100',
    auth_type         => 'PASS',
    auth_pass         => 'secret',
    virtual_ipaddress => [ '10.0.0.1/29' ],
    track_interface   => ['eth1','tun0'], # optional, monitor these interfaces.
  }
}
```

### Add floating routes

```puppet
node /node01/ {
  include keepalived

  keepalived::vrrp::instance { 'VI_50':
    interface         => 'eth1',
    state             => 'MASTER',
    virtual_router_id => '50',
    priority          => '101',
    auth_type         => 'PASS',
    auth_pass         => 'secret',
    virtual_ipaddress => [ '10.0.0.1/29' ],
    virtual_routes    => [ { to  => '168.168.2.0/24', via => '10.0.0.2' },
                           { to  => '168.168.3.0/24', via => '10.0.0.3' } ]
  }
}
```

### Detect application level failure

This configuration will fail-over when:

a. NGinX daemon is not running<br>
b. Master node is unavailable

```puppet
node /node01/ {
  include ::keepalived

  keepalived::vrrp::script { 'check_nginx':
    script => '/usr/bin/killall -0 nginx',
  }

  keepalived::vrrp::instance { 'VI_50':
    interface         => 'eth1',
    state             => 'MASTER',
    virtual_router_id => '50',
    priority          => '101',
    auth_type         => 'PASS',
    auth_pass         => 'secret',
    virtual_ipaddress => '10.0.0.1/29',
    track_script      => 'check_nginx',
  }
}

node /node02/ {
  include ::keepalived

  keepalived::vrrp::script { 'check_nginx':
    script => '/usr/bin/killall -0 nginx',
  }

  keepalived::vrrp::instance { 'VI_50':
    interface         => 'eth1',
    state             => 'BACKUP',
    virtual_router_id => '50',
    priority          => '100',
    auth_type         => 'PASS',
    auth_pass         => 'secret',
    virtual_ipaddress => '10.0.0.1/29',
    track_script      => 'check_nginx',
  }
}
```

### Global definitions

```puppet
class { 'keepalived::global_defs':
  ensure                  => present,
  notification_email      => 'no@spam.tld',
  notification_email_from => 'no@spam.tld',
  smtp_server             => 'localhost',
  smtp_connect_timeout    => '60',
  router_id               => 'your_router_instance_id',
}
```

### Soft-restart the Keepalived daemon

```puppet
class { '::keepalived':
  service_restart => 'service keepalived reload',     # When using SysV Init
  # service_restart => 'systemctl reload keepalived', # When using SystemD
}
```

### Opt out of having the service managed by the module

```puppet
class { '::keepalived':
  service_manage => false,
}
```

### Unicast instead of Multicast

**caution: unicast support has only been added to Keepalived since version 1.2.8**

By default Keepalived will use multicast packets to determine failover conditions.
However, in many cloud environments it is not possible to use multicast because of
network restrictions. Keepalived can be configured to use unicast in such environments:

```puppet
  keepalived::vrrp::instance { 'VI_50':
    interface         => 'eth1',
    state             => 'BACKUP',
    virtual_router_id => '50',
    priority          => '100',
    auth_type         => 'PASS',
    auth_pass         => 'secret',
    virtual_ipaddress => '10.0.0.1/29',
    track_script      => 'check_nginx',
    unicast_source_ip => $::ipaddress_eth1,
    unicast_peers     => ['10.0.0.1', '10.0.0.2']
  }
```
The 'unicast\_source\_ip' parameter is optional as Keepalived will bind to the specified interface by default.
The 'unicast\_peers' parameter contains an array of ip addresses that correspond to the failover nodes.


