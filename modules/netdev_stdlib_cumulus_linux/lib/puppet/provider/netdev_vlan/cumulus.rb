$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),"..","..",".."))
require 'puppet/provider/cumulus/cumulus_parent'
require 'puppet/provider/cumulus/network_interfaces'


Puppet::Type.type(:netdev_vlan).provide(:cumulus, :parent => Puppet::Provider::Cumulus) do

  commands :brctl => '/sbin/brctl', :iplink => '/sbin/ip'

  NAME_SEP = '_'
  DEFAULT_AGING_TIME = 300
  DEFAULT_BRIDGE_OPTIONS = {
    'bridge_stp' => ['on'],
    'bridge_maxwait' => [5],
    'bridge_ageing' => [200],
    'bridge_fd' => [30],
  }

  mk_resource_methods

  def create
    unless resource[:name] =~ /^\w+#{NAME_SEP}\d+/
      raise ArgumentError, "VLAN name must be in format <name>#{NAME_SEP}<VLAN ID>"
    end
    Puppet.debug("#{resource.type}.create #{resource[:name]}")
    create_bridge(resource[:name])
  end

  def destroy
    Puppet.debug("#{resource.type}.destroy #{resource[:name]}")
    destroy_bridge(resource[:name])
  end

  # def vlan_id=(value)
  #   # raise "VLAN ID can not be changed."
  #   @property_flush[:vlan_id] = value
  # end

  def no_mac_learning=(value)
    @property_flush[:no_mac_learning] = value
  end

  def ageing
    #To disable mac learning set ageing time to zero
    #Otherwise set to default (300 seconds)
    @property_flush[:no_mac_learning] ? 0 : DEFAULT_AGING_TIME
  end

  def apply
    brctl(['setageing', resource[:name], ageing]) if @property_flush[:no_mac_learning]
  end

  def persist
    network_interfaces = NetworkInterfaces.parse
    network_interfaces[resource[:name]].options['bridge_ageing'] = [ageing]
    network_interfaces.flush
  end


  def create_bridge(name)
    brctl(['addbr', name])
    iplink(['link', 'set', 'dev', name, 'up'])

    network_interfaces = NetworkInterfaces.parse

    bridge = network_interfaces[name]
    bridge.family = 'inet'
    bridge.method = 'manual'
    bridge.onboot = true
    bridge.options.update(DEFAULT_BRIDGE_OPTIONS)

    network_interfaces.flush
  end

  def destroy_bridge(name)
    brctl(['delbr', name])
    network_interfaces = NetworkInterfaces.parse
    network_interfaces[name] = nil
    network_interfaces.flush
  end

  class << self
    def instances
      bridges.collect { |i| new(i) }
    end
  end

end
