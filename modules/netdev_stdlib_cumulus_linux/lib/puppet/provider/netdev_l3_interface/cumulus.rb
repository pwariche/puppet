require 'ipaddr'
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),"..","..",".."))
require 'puppet/provider/cumulus/cumulus_parent'
require 'puppet/provider/cumulus/network_interfaces'

Puppet::Type.type(:netdev_l3_interface).provide(:cumulus, :parent => Puppet::Provider::Cumulus) do

  commands :iplink => '/sbin/ip'

  mk_resource_methods

  def create
    exists? ? (return true) : (return false)
  end

  def destroy
    exists? ? (return false) : (return true)
  end

  def method=(value)
    @property_flush[:method] = value
  end

  def ipaddress=(value)
    @property_flush[:ipaddress] = value
  end

  def netmask=(value)
    @property_flush[:netmask] = value
  end

  def apply
    ip_options = []
    if @property_flush
      (ip_options << @property_flush[:ipaddress]) if @property_flush[:ipaddress]
      (ip_options << ip_options.pop + '/' + netmask_to_prefix(@property_flush[:netmask])) if @property_flush[:netmask]
    end
    unless ip_options.empty?
      ip_options.unshift ['addr', 'add']
      ip_options += ['dev', resource[:name]]
      iplink ip_options
    end
  end

  def persist
    if @property_flush
      network_interfaces = NetworkInterfaces.parse
      intf = network_interfaces[resource[:name]]
      intf.ip_address = @property_flush[:ipaddress] if @property_flush[:ipaddress]
      intf.method = @property_flush[:method] if @property_flush[:method]
      intf.netmask = @property_flush[:netmask] if @property_flush[:netmask]
      # intf.gateway = @property_flush[:gateway] if @properJJty_flush[:gateway]
      network_interfaces.flush
    end
  end

  def self.instances
    interfaces = NetworkInterfaces.parse
    ip_link_addr.collect do |name,v|
      inet = v['inet']  if v['inet']
      inet = v['inet6'] if not inet and v['inet6']
      if inet
        ipaddress = inet.split('/')[0]
        netmask = IPAddr.new(inet).inspect.split('/')[1].chomp('>')
      end
      method = interfaces[name].method if interfaces.contains?(name)
      new({:name => name,
           :ensure => :present,
           :ipaddress => ipaddress || :absent,
           :netmask => netmask || :absent,
           :method =>  method || :absent,
           })
    end
  end

  # def netmask_to_prefix value
  #   netmask = IPAddr.new value
  #   if netmask.ipv4?
  #     s = netmask.to_i ^ IPAddr::IN4MASK.to_i
  #     prefix = 32
  #   elsif netmask.ipv6?
  #     s = netmask.to_i ^ IPAddr::IN6MASK.to_i if netmask.ipv6?
  #     prefix = 128
  #   end

  #   while s > 0 do
  #       s >>= 1
  #       prefix -= 1
  #     end
  #     prefix.to_s
  #   end

end
