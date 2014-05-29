#
# Cookbook Name:: spc-base
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'ntp'
include_recipe 'iptables'
include_recipe 'logrotate'
