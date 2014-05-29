require 'ipaddr'
require 'json'

def crowbar?
  !defined?(Chef::Recipe::Barclamp).nil?
end

def mon_nodes
  if crowbar?
    mon_roles = search(:role, 'name:crowbar-* AND run_list:role\[ceph-mon\]')
    unless mon_roles.empty?
      search_string = mon_roles.map { |role_object| 'roles:' + role_object.name }.join(' OR ')
      search_string = "(#{search_string}) AND ceph_config_environment:#{node['ceph']['config']['environment']}"
    end
  else
    search_string = "ceph_is_mon:true AND chef_environment:#{node.chef_environment}"
  end

  if use_cephx? && !node['ceph']['encrypted_data_bags']
    search_string = "(#{search_string}) AND (ceph_bootstrap_osd_key:*)"
  end
  search(:node, search_string)
end

def osd_secret
  if node['ceph']['encrypted_data_bags']
    secret = Chef::EncryptedDataBagItem.load_secret(node['ceph']['osd']['secret_file'])
    return Chef::EncryptedDataBagItem.load('ceph', 'osd', secret)['secret']
  else
    return mon_nodes[0]['ceph']['bootstrap_osd_key']
  end
end

# If public_network is specified
# we need to search for the monitor IP
# in the node environment.
# 1. We look if the network is IPv6 or IPv4
# 2. We look for a route matching the network
# 3. We grab the IP and return it with the port
def find_node_ip_in_network(network, nodeish = nil)
  nodeish = node unless nodeish
  net = IPAddr.new(network)
  nodeish['network']['interfaces'].each do |_iface, addrs|
    addresses = addrs['addresses'] || []
    addresses.each do |ip, params|
      return ip_address_to_ceph_address(ip, params) if ip_address_in_network?(ip, params, net)
    end
  end
  nil
end

def ip_address_in_network?(ip, params, net)
  if params['family'] == 'inet'
    net.include?(ip) && params.key?('broadcast')     # is primary ip on iface
  elsif params['family'] == 'inet6'
    net.include?(ip)
  else
    false
  end
end

def ip_address_to_ceph_address(ip, params)
  if params['family'].eql?('inet6')
    return "[#{ip}]:6789"
  elsif params['family'].eql?('inet')
    return "#{ip}:6789"
  end
end

def mon_addresses
  mon_ips = []

  if File.exist?("/var/run/ceph/ceph-mon.#{node['hostname']}.asok")
    mon_ips = quorum_members_ips
  else
    mons = []
    # make sure if this node runs ceph-mon, it's always included even if
    # search is laggy; put it first in the hopes that clients will talk
    # primarily to local node
    mons << node if node['ceph']['is_mon']

    mons += mon_nodes
    if crowbar?
      mon_ips = mons.map { |node| Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, 'admin').address }
    else
      if node['ceph']['config']['global'] && node['ceph']['config']['global']['public network']
        mon_ips = mons.map { |nodeish| find_node_ip_in_network(node['ceph']['config']['global']['public network'], nodeish) }
      else
        mon_ips = mons.map { |node| node['ipaddress'] + ':6789' }
      end
    end
  end
  mon_ips.reject { |m| m.nil? }.uniq
end

def mon_secret
  if node['ceph']['encrypted_data_bags']
    secret = Chef::EncryptedDataBagItem.load_secret(node['ceph']['mon']['secret_file'])
    Chef::EncryptedDataBagItem.load('ceph', 'mon', secret)['secret']
  elsif !mon_nodes.empty?
    mon_nodes[0]['ceph']['monitor-secret']
  elsif node['ceph']['monitor-secret']
    node['ceph']['monitor-secret']
  else
    Chef::Log.info('No monitor secret found')
    nil
  end
end

def quorum_members_ips
  mon_ips = []
  cmd = Mixlib::ShellOut.new("ceph --admin-daemon /var/run/ceph/ceph-mon.#{node['hostname']}.asok mon_status")
  cmd.run_command
  cmd.error!

  mons = JSON.parse(cmd.stdout)['monmap']['mons']
  mons.each do |k|
    mon_ips.push(k['addr'][0..-3])
  end
  mon_ips
end

QUORUM_STATES = %w(leader, peon)
def quorum?
  # "ceph auth get-or-create-key" would hang if the monitor wasn't
  # in quorum yet, which is highly likely on the first run. This
  # helper lets us delay the key generation into the next
  # chef-client run, instead of hanging.
  #
  # Also, as the UNIX domain socket connection has no timeout logic
  # in the ceph tool, this exits immediately if the ceph-mon is not
  # running for any reason; trying to connect via TCP/IP would wait
  # for a relatively long timeout.

  cmd = Mixlib::ShellOut.new("ceph --admin-daemon /var/run/ceph/ceph-mon.#{node['hostname']}.asok mon_status")
  cmd.run_command
  cmd.error!

  state = JSON.parse(cmd.stdout)['state']
  QUORUM_STATES.include?(state)
end

# Cephx is on by default, but users can disable it.
# type can be one of 3 values: cluster, service, or client.  If the value is none of the above, set it to cluster
def use_cephx?(type = nil)
  # Verify type is valid
  type = 'cluster' if %w(cluster service client).index(type).nil?

  # CephX is enabled if it's not configured at all, or explicity enabled
  node['ceph']['config'].nil? ||
    node['ceph']['config']['global'].nil? ||
    node['ceph']['config']['global']["auth #{type} required"] == 'cephx'
end
