node default {
  # This is where you can declare classes for all nodes.
  # Example:
  #   class { 'my_class': }
  if $operatingsystem == "CumulusLinux" {
    netdev_device { $hostname: }
    include switchbase
  }
}

class switchbase {
 include motd
}

user { 'cumulus':
    ensure => 'present',
    groups => ['sudo', 'cumulus'],
    #require => User['cumulus'],
    home => '/home/cumulus',
    managehome => true,
    password => '$6$EnqL4.igPaPcRes$chd9AdyGweHJnZNrTZIjErjQwTrkr1c0ZVcbqzmwMKAlO/vltqa9DFi7C/e74F2Ms9LyeVKz3fo1SbsVkprzG1',
    shell => '/bin/bash',
}

#netdev_interface { "swp1":
#    ensure => (present),
#    active => (true),
#    admin => (up),
#    description => "swp1 interface",
#    speed => 1g,
#    duplex => (full),
#    mtu => 1500
#}

#netdev_l2_interface { "swp1":
#    ensure => (present),
#    active => (true),
#    description => "swp1 L2 interface",
#    tagged_vlans => (vlan  |  [vlan1, vlan2, vlan3, ...]),
#    untagged_vlan => vlan,
#    vlan_tagging => (enable | disable)
#} 

node "cumulus.cisco.com" {
    netdev_device { $hostname: }
    netdev_bridge
 { "Green":
        vlan_id => 500
    }
}