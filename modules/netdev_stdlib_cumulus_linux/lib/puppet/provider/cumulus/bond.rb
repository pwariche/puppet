require 'set'
module Cumulus
  class Bond

    BONDING_MASTERS = '/sys/class/net/bonding_masters'
    BOND = "/sys/class/net/%s/bonding/%s"

    attr_reader :name

    def initialize name
      unless Bond.exists? name
        raise ArgumentError.new "You need to create '#{name}' bond first"
      end
      @name = name
    end

    def slaves
      get_bonding_property('slaves').split
    end

    def slaves=(names)
      existing = Set.new slaves
      to_add = Set.new [names].flatten
      (existing - to_add).each {|i| remove_slave i}
      to_add.each {|i| add_slave i}
      slaves
    end

    def min_links
      get_bonding_property 'min_links'
    end

    def min_links=(value)
      set_bonding_property 'min_links', value
    end

    def add_slave name
      modify_slave "+#{name}"
      slaves
    end

    def remove_slave name
      modify_slave "-#{name}"
      slaves
    end

    class << self
      def exists? name
        self.all.include? name
      end

      def create name
        File.open(BONDING_MASTERS, 'a') {|f| f << "+#{name}"}
        self.new name
      end

      def destroy name
        File.open(BONDING_MASTERS, 'a') {|f| f << "-#{name}"}
      end

      def all
        File.read(BONDING_MASTERS).split
      end
    end

    private
    def modify_slave value
      # File.open(BOND % [@name, 'slaves'], 'a') {|f| f << value}
      set_bonding_property 'slaves', value
    end

    def get_bonding_property prop
      begin
        File.read(BOND % [@name, prop]).chomp
      rescue Errno::ENOENT
        nil
      end
    end

    def set_bonding_property prop, value
      begin
        File.open(BOND % [@name, prop], 'a') {|f| f << value}
      rescue Errno::ENOENT
        # nil
      end
    end

  end
end
