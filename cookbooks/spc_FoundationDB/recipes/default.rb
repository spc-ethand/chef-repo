#
# Cookbook Name:: spc_FoundationDB
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

log "Hello World! Boom!"

package 'httpd' do
	action :install
end

service 'httpd' do
	action [ :enable, :start ]
end

cookbook_file '/var/www/html/index.html' do
	source 'index.html'
	mode '0644'
end