#
# Cookbook Name:: spc-web
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'apache2::mod_ssl'
include_recipe 'apache2::mod_rewrite'
include_recipe 'apache2::mod_deflate'
include_recipe 'apache2::mod_headers'
include_recipe 'apache2::iptables'
include_recipe 'apache2::logrotate'
