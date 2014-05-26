#
# Cookbook Name:: spc_FoundationDB
# Recipe:: default
#
# Copyright 2014, StackPointCloud, Inc. 
#
# All rights reserved - Do Not Redistribute
#

log "Setting up the coordinator"

execute "Configure Coordinator External Access" do
	command "/usr/lib/foundationdb/make_public.py"
end

service 'foundationdb' do
	action :restart
end