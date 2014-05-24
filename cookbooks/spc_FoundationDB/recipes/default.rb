#
# Cookbook Name:: spc_FoundationDB
# Recipe:: default
#
# Copyright 2014, StackPointCloud, Inc. 
#
# All rights reserved - Do Not Redistribute
#

#log "Installing HTTPd"

#package 'httpd' do
#	action :install
#end

#service 'httpd' do
#	action [ :enable, :start ]
#end

#cookbook_file '/var/www/html/index.html' do
#	source 'index.html'
#	mode '0644'
#end

# TEST Recipe

log "Setting up user and group"

group "foundationdb" do
  system true
end

user "foundationdb" do
  system true
  group "foundationdb"
  home "/var/lib/foundationdb"
  comment "FoundationDB"
  shell "/bin/false"
end

pkg_version = "2.0.5"

log "Installing Client"

client_pkg_file = case node['platform_family']
           when 'debian' then "foundationdb-clients_#{pkg_version}-1_amd64.deb"
           when 'rhel', 'fedora' then "foundationdb-clients-#{pkg_version}-1.x86_64.rpm"
           else raise "Cannot handle this platform yet" end

remote_file "#{Chef::Config[:file_cache_path]}/#{client_pkg_file}" do
  source "https://foundationdb.com/downloads/I_accept_the_FoundationDB_Community_License_Agreement/#{pkg_version}/#{client_pkg_file}"
end

package "foundationdb-clients" do
  version "#{pkg_version}-1"
  source "#{Chef::Config[:file_cache_path]}/#{client_pkg_file}"
  provider Chef::Provider::Package::Dpkg if node['platform_family'] == 'debian'
end

log "Installing Server"

server_pkg_file = case node['platform_family']
           when 'debian' then "foundationdb-server_#{pkg_version}-1_amd64.deb"
           when 'rhel', 'fedora' then "foundationdb-server-#{pkg_version}-1.x86_64.rpm"
           else raise "Cannot handle this platform yet" end

remote_file "#{Chef::Config[:file_cache_path]}/#{server_pkg_file}" do
  source "https://foundationdb.com/downloads/I_accept_the_FoundationDB_Community_License_Agreement/#{pkg_version}/#{server_pkg_file}"
end

package "foundationdb-server" do
  version "#{pkg_version}-1"
  source "#{Chef::Config[:file_cache_path]}/#{server_pkg_file}"
  provider Chef::Provider::Package::Dpkg if node['platform_family'] == 'debian'
end

log "Starting Server"

service 'foundationdb' do
	pattern "fdbmonitor"
	action [ :enable, :start ]
	supports :status => true, :restart => true
	subscribes :restart, 'file[/etc/foundationdb/fdb.cluster]'
end

# TODO 
# - install APIs for Ruby, Java, Node.js -> only if the customer chooses to use these languages. 
# 	- @ariel - We should ask the customer what language(s) they're using in their application before we 
#       	   initiate an architecture build. This ensures the correct APIs get added and no excess.
# - need to optimize the configuration for the instance we just built out, e.g. 1 FDB process per core. 
# 	- 4GB memory required per process, so we need to ensure that for every core we assign 4GB of memory
#   - all FDB machines should be identical
# 	- configuration file should be changed on the master then pushed to the other nodes, so we do the config once. 
