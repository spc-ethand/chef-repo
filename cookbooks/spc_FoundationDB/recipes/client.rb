#
# Cookbook Name:: spc_FoundationDB
# Recipe:: client
#
# Copyright 2014, StackPointCloud, Inc. 
#
# All rights reserved - Do Not Redistribute
#

pkg_version = "2.0.5"
pkg_file = case node['platform_family']
           when 'debian' then "foundationdb-clients_#{pkg_version}-1_amd64.deb"
           when 'rhel', 'fedora' then "foundationdb-clients-#{pkg_version}-1.x86_64.rpm"
           # when 'mac_os_x' ...
           # when 'windows' ...
           else raise "Cannot handle this platform yet" end

remote_file "#{Chef::Config[:file_cache_path]}/#{pkg_file}" do
  source "https://foundationdb.com/downloads/I_accept_the_FoundationDB_Community_License_Agreement/#{pkg_version}/#{pkg_file}"
end

package "foundationdb-clients" do
  version "#{pkg_version}-1"
  source "#{Chef::Config[:file_cache_path]}/#{pkg_file}"
  provider Chef::Provider::Package::Dpkg if node['platform_family'] == 'debian'
end

if node.attribute?('fdb')
  directory "/etc/foundationdb" do
  end

  if cluster_name = node['fdb']['cluster']
    cluster_item = data_bag_item('fdb_cluster', cluster_name)
    cluster_desc = cluster_name.gsub(/[^a-zA-Z0-9_]/,'_')
    cluster_id = cluster_item['unique_id']
    prefix = "#{cluster_desc}:#{cluster_id}"

    coordinators = []
    search(:node, "fdb_cluster:#{cluster_name}") do |cnode|
      (cnode['fdb']['server'] or []).each do |serv|
        if serv['coordinator']
          addr = "#{cnode['ipaddress']}:#{serv['id']}" 
          addr += ":tls" if cluster_item['tls']
          coordinators << addr
        end
      end
    end
    coordinators.sort!

    update_file = true
    if File.exists?('/etc/foundationdb/fdb.cluster') &&
       (node['fdb']['server'] || []).detect {|s| s['coordinator'] }
      old_cluster = IO.read('/etc/foundationdb/fdb.cluster')
      if old_cluster =~ /(.+)@(.+)/ && prefix == $1
        old_coordinators = $2.split(',')
        # Change an existing cluster via command line.
        unless coordinators == old_coordinators
          command = "coordinators #{coordinators.join(' ')}"
          fdb command do
            
          end
          # That will generate a new id that needs to go back into the data bag item.
          ruby_block "update cluster_item" do
            block do
              cluster_name = node['fdb']['cluster']
              cluster_item = data_bag_item('fdb_cluster', cluster_name)
              cluster_desc = cluster_name.gsub(/[^a-zA-Z0-9_]/,'_')
              cluster_id = cluster_item['unique_id']
              new_cluster = IO.read('/etc/foundationdb/fdb.cluster')
              if new_cluster =~ /(.+):(.+)@.+/ && cluster_desc == $1 && cluster_id != $2
                cluster_id = $2
                cluster_item['unique_id'] = cluster_id
                cluster_item.save
              end
            end
          end
        end
        update_file = false
      end
    end
    if update_file
      # Just update file.
      file "/etc/foundationdb/fdb.cluster" do
        content "#{prefix}@#{coordinators.join(',')}"
        mode "0644"
      end
    end
  end

end