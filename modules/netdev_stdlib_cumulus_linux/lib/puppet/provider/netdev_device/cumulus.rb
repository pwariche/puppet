Puppet::Type.type(:netdev_device).provide(:cumulus) do
  confine :operatingsystem => :cumuluslinux

  def exists?
    true
  end

  def create
    raise "Can not create"
  end

  def destroy
    raise "Can not destroy"
  end

end
