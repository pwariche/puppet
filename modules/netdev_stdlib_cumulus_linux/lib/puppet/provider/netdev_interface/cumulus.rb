$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),"..","..",".."))
require 'puppet/provider/cumulus/cumulus_parent'
require 'puppet/provider/cumulus/network_interfaces'

Puppet::Type.type(:netdev_interface).provide(:cumulus, :parent => Puppet::Provider::Cumulus) do

  commands :ethtool  => '/sbin/ethtool', :iplink => '/sbin/ip'

  mk_resource_methods

  def create
    case resource[:name]
    when /(swp\d+)\.(\d+)/
      iplink(['link', 'add', 'link', $1, 'name',
        resource[:name], 'type', 'vlan', 'id', $2])
      @property_flush = resource.to_hash
      flush
      @property_hash[:ensure] = :present
    end
    exists? ? (return true) : (return false)
  end

  def destroy
    # raise NotImplementedError "Interface destruction is not implemented."
    exists? ? (return false) : (return true)
  end

  def admin=(value)
    @property_flush[:admin] = value
  end

  def mtu=(value)
    @property_flush[:mtu] = value
  end

  def speed=(value)
    @property_flush[:speed] = value
  end

  def duplex=(value)
    @property_flush[:duplex] = value
  end

  def apply
    ip_options = []
    eth_options = []
    if @property_flush
      (ip_options << resource[:admin]) if @property_flush[:admin]
      (ip_options << 'mtu' << resource[:mtu]) if @property_flush[:mtu]
    end
    unless ip_options.empty?
      ip_options.unshift ['link', 'set', resource[:name]]
      iplink ip_options
    end

    if @property_flush
      (eth_options << 'speed' << LinkSpeed.to_ethtool(resource[:speed])) if @property_flush[:speed]
      case @property_flush[:duplex]
      when 'full', 'half'
        (eth_options << 'duplex' << resource[:duplex] << 'autoneg' << 'off')
      when 'auto'
        (eth_options << 'autoneg' << 'on')
      end
    end
    unless eth_options.empty?
      eth_options.unshift ['-s', resource[:name]]
      ethtool eth_options
    end
  end

  def persist
    if @property_flush
      network_interfaces = NetworkInterfaces.parse
      res_net_interface = network_interfaces[resource[:name]]
      res_net_interface.onboot = true if @property_flush[:admin]
      res_net_interface.mtu = resource[:mtu] if @property_flush[:mtu]
      res_net_interface.speed = LinkSpeed.to_ethtool(@property_flush[:speed]) if @property_flush[:speed]
      res_net_interface.duplex = resource[:duplex] if @property_flush[:duplex]
      network_interfaces.flush
    end
  end

  class << self

    def instances
      interfaces.collect { |i| new(i.merge({:ensure => :present}) ) }
    end

  end

end
