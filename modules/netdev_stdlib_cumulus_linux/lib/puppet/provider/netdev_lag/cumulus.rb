$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),"..","..",".."))
require 'puppet/provider/cumulus/bond'
require 'puppet/provider/cumulus/cumulus_parent'
require 'puppet/provider/cumulus/network_interfaces'

Puppet::Type.type(:netdev_lag).provide(:cumulus, :parent => Puppet::Provider::Cumulus) do

  # commands :ip => '/sbin/ip'

  NET_CLASS = '/sys/class/net'
  BONDING_MASTERS = '/sys/class/net/bonding_masters'

  mk_resource_methods

  # def active=(value)
  # @property_flush[:active] = value
  # end

  def minimum_links=(value)
    @property_flush[:minimum_links] = value
  end

  def links=(value)
    @property_flush[:links] = value
  end

  def create
    Cumulus::Bond.create resource[:name]
  end

  def destroy
    Cumulus::Bond.destroy resource[:name]
  end

  def apply
    bond = Cumulus::Bond.new resource[:name]
    bond.slaves = @property_flush[:links] if @property_flush[:links]
    bond.min_links = @property_flush[:minimum_links] if @property_flush[:minimum_links]
    # iplink(['link', 'set', resource[:name], to_updown(@property_flush[:active])]) if @property_flush[:active]
  end

  def persist
    if @property_flush
      network_interfaces = NetworkInterfaces.parse
      bond = network_interfaces[resource[:name]]
      # bond.onboot = @property_flush[:active] if @property_flush[:active]
      bond.options['bond-slaves'] = [@property_flush[:links].join ' '] if @property_flush[:links]
      bond.options['bond-min-links'] = [@property_flush[:minimum_links]] if @property_flush[:minimum_links]
      network_interfaces.flush
    end
  end


  def self.instances
    lags.collect { |i| new(i) }
  end

  private

  def to_updown value
    if value and (value == true)
      'up'
    else
      'down'
    end
  end

end
