#
# Cookbook Name:: spc_FoundationDB
# Recipe:: sql_layer
#
# Copyright 2014, StackPointCloud, Inc. 
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'spc_FoundationDB::client'

# Make sure apt-get update is done.
include_recipe 'apt' if node['platform_family'] == 'debian'

# This doesn't install any package and so doesn't satisfy the SQL layer's dependency.
#node.override['java']['install_flavor'] = 'oracle'
#node.override['java']['oracle']['accept_oracle_download_terms'] = true
node.override['java']['jdk_version'] = '7'
node.override['java']['openjdk_packages'] = ['openjdk-7-jre-headless'] if node['platform_family'] == 'debian'
include_recipe 'java'

pkg_version = "1.9.3"
pkg_file = case node['platform_family']
           when 'debian' then "fdb-sql-layer_#{pkg_version}-1_all.deb"
           when 'rhel', 'fedora' then "fdb-sql-layer-#{pkg_version}-1.el6.noarch.rpm"
           # when 'mac_os_x' ...
           # when 'windows' ...
           else raise "Cannot handle this platform yet" end

remote_file "#{Chef::Config[:file_cache_path]}/#{pkg_file}" do
  source "https://s3.amazonaws.com/foundationdb/downloads/I_accept_the_FoundationDB_Community_License_Agreement/sql-layer/#{pkg_version}/#{pkg_file}"
end

package "fdb-sql-layer" do
  version "#{pkg_version}-1"
  source "#{Chef::Config[:file_cache_path]}/#{pkg_file}"
  provider Chef::Provider::Package::Dpkg if node['platform_family'] == 'debian'
end

service "fdb-sql-layer" do
  action :nothing
  supports :status => true, :restart => true
end