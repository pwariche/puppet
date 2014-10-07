$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),"..","..",".."))
require 'puppet/provider/cumulus/cumulus_parent'
require 'puppet/provider/cumulus/network_interfaces'

Puppet::Type.type(:netdev_route).provide(:cumulus, :parent => Puppet::Provider::Cumulus) do

  commands :iplink => '/sbin/ip'

  mk_resource_methods

  def create
    ip_options = to_options resource
    ip_options.unshift 'route', 'add'
    iplink ip_options
  end

  def destroy
    iplink ['route', 'delete', resource[:name]]
  end

  def nexthop=(value)
    @property_flush[:nexthop] = value
  end

  def gateway=(value)
    @property_flush[:gateway] = value
  end

  def interface=(value)
    @property_flush[:interface] = value
  end

  def apply
    ip_options = to_options(@property_flush) if @property_flush
    unless not ip_options or ip_options.empty?
      ip_options.unshift ['route', 'add']
      iplink ip_options
    end
  end

  def persist
    # Let the ip route commadn work out details, just pull the values
    route = self.class.routes.find {|r| r['route'] == resource[:name]}
    if route['dev']
      network_interfaces = NetworkInterfaces.parse
      intf = network_interfaces[route['dev']]
      route_up_str = "route add -net #{route['route']}"
      route_up_str += "gw #{@resource[:gateway]}" if @resource[:gateway]
      intf.options['up'] << route_up_str
      network_interfaces.flush
    end
  end

  def to_options h
    #convert resource to options
    options = []
    options << h[:name] if h[:name]
    options << 'nexthop' << 'via' << h[:nexthop] if h[:nexthop]
    options << 'via' << h[:gateway] if h[:gateway]
    options << 'dev' << h[:interface] if h[:interface]
    options
  end

  def self.routes
    Puppet.debug "self.routes"
    iplink(['route', 'list']).lines.collect do |r|
      route_parts = r.split
      {'route' => route_parts.shift}.merge(Hash[route_parts.each_slice(2).to_a])
    end
  end

  def self.instances
    routes.collect do |r|
      # route, netmask = r['route']. split '/'
      new({
            :name => r['route'],
            # :route => route,
            # :netmask => netmask,
            :nexthop => r['via'],
            :gateway => r['via'] || :absent,
            :interface => r['dev'],
            :ensure => :present
      })
    end
  end

end
