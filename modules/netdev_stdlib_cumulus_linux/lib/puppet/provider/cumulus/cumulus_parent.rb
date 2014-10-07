$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),"..","..",".."))
require 'puppet/provider/cumulus/bond'
require 'puppet/provider/cumulus/network_interfaces'

class Puppet::Provider::Cumulus < Puppet::Provider

  SYSFS_NET_PATH = "/sys/class/net"
  NAME_SEP = '_'
  DEFAULT_AGING_TIME = 300

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def apply
    ## Apply runtime configuration
    Puppet.debug("'apply' was not implemented.")
  end

  def persist
    # Persist configuration
    Puppet.debug("'persist' was not implemented.")
  end

  def flush
    Puppet.debug("Flush with property_flush=#{@property_flush}")
    if @property_flush
      apply
      persist
    end
    @property_hash = resource.to_hash
  end

  def routes
    self.routes
  end

  def netmask_to_prefix value
    netmask = IPAddr.new value
    if netmask.ipv4?
      s = netmask.to_i ^ IPAddr::IN4MASK.to_i
      prefix = 32
    elsif netmask.ipv6?
      s = netmask.to_i ^ IPAddr::IN6MASK.to_i if netmask.ipv6?
      prefix = 128
    end

    while s > 0
      s >>= 1
      prefix -= 1
    end
    prefix.to_s
  end

  class << self

    DUPLEX_ALLOWED_VALUES = ['auto', 'full', 'half']

    def duplex_to_netdev value
      value = value.downcase
      if DUPLEX_ALLOWED_VALUES.include? value
        value
      else
        raise TypeError, "Duplex must be one of the values [#{DUPLEX_ALLOWED_VALUES.join ','}]"
      end

    end
    def value text, key, separator=''
      $1 if text =~ /#{key}#{separator}\s*(\S*)/i
    end

    def link_master name
      $1 if iplink(['-oneline','link', 'show', name ]).match(/master\s+(\S+)/)
    end

    def interfaces
      # iplink(['-oneline','link','show']).lines.select {|i| /link\/ether/ =~ i}.
      # each.collect do |intf|
      #   _, name, params = intf.split(':', 3).map {|c| c.strip }
      #   name, _ = name.split '@' #take care of the sub-interfaces in format "eth1.100@eth1"
      #   out = ethtool(name)
      #   duplex = value(out, 'duplex', ':')
      #   duplex = duplex ? duplex_to_netdev(duplex) : :absent
      #   speed = value(out, 'speed', ':')
      #   speed = speed ? LinkSpeed.to_netdev(speed): :absent
      #   {:name => name,
      #    :description => name,
      #    :mtu => value(params, 'mtu').to_i,
      #    :up => value(params, 'state').downcase,
      #    :duplex => duplex,
      #    :speed => speed,
      #    :ensure => :present}
      # end
      ip_link_addr.map do |name, data|
        #take care of the sub-interfaces in format "eth1.100@eth1"
        name = name.split('@')[0]
        ethtool_output = ethtool(name)
        auto_neg = value(ethtool_output, 'Auto-negotiation', ':')
        if auto_neg and auto_neg == 'on'
          duplex = :auto
        else
          duplex = value(ethtool_output, 'duplex', ':') || :absent
          duplex = duplex_to_netdev(duplex) if duplex != :absent
        end
        {
          :name => name,
          :description => name,
          :mtu => data['mtu'].to_i,
          :admin => data['state'].downcase,
          :duplex => duplex,
          :speed => LinkSpeed.to_netdev(data['speed']),
        }
      end
    end

    def l2_interfaces
      bridge_names = self.bridges.map {|i| i[:name]}
      interface_names = self.interfaces.map {|i| i[:name]}
      l2_interfaces = interface_names - bridge_names
      l2_interfaces.collect do |i|
        {:name => i,
         :ensure => :present,
         # :vlan_tagging => :enabled,
         :untagged_vlan => (link_master(i) || :absent),
         :tagged_vlans => Dir[File.join SYSFS_NET_PATH, i + '.*'].collect do |subi|
           link_master(File.basename subi)
        end.compact}
      end
    end

    def bridges
      bridge_names = Dir[File.join SYSFS_NET_PATH, '*'].
        select{|dir| File.directory? File.join dir, 'bridge'}.
        collect{|br| File.basename br }

      bridge_names.each.collect do |bridge_name|
        _, vlan_id = bridge_name.split NAME_SEP
        aging_time = File.read(File.join SYSFS_NET_PATH, bridge_name, 'bridge', 'ageing_time')
        {:ensure => :present,
         :name => bridge_name,
         :no_mac_learning => (aging_time.to_i) / 100 == 0,
         :vlan_id => (vlan_id or :absent)}
      end
    end

    def lags
      Cumulus::Bond.all.collect do |name|
        bond = Cumulus::Bond.new name
        {
          :name => bond.name,
          :ensure => :present,
          :links => bond.slaves,
          :minimum_links => bond.min_links
        }
      end
    end

    # def routes
    #   iplink(['route', 'list']).lines.collect do |r|
    #     route_parts = r.split
    #     {'route' => route_parts.shift}.merge(Hash[route_parts.each_slice(2).to_a])
    #   end
    # end

    def ip_link_addr
      intfs = {}
      iplink(['-oneline', 'addr', 'show']).lines.each do |line|
        line = line.chomp.delete '\\'
        line_split = line.split
        line_split.shift
        name = line_split.shift.chomp ':'
        #take care of the sub-interfaces in format "eth1.100@eth1"
        name = name.split('@')[0]
        options = line_split.shift if line_split.first.match(/<.+>/)
        intfs[name] ||= {}
        intfs[name].merge!(Hash[line_split.each_slice(2).to_a])
        intfs[name].delete_if { |k, v| v.nil? }
      end
      intfs
    end



    def prefetch(resources)
      raise "Implement self.instances or override prefetch" if not instances
      instances.each do |prov|
        if resource = resources[prov.name]
          resource.provider = prov
        end
      end
      # Puppet.debug("Prefetch->#{resources}")
      # interfaces = instances
      # resources.each do |name, params|
      #   if provider = interfaces.find { |interface| interface.name == params[:name] }
      #     resources[name].provider = provider
      #   end
      # end
    end
  end

end
