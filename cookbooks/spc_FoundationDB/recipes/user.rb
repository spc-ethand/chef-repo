#
# Cookbook Name:: spc_FoundationDB
# Recipe:: user
#
# Copyright 2014, StackPointCloud, Inc. 
#
# All rights reserved - Do Not Redistribute
#

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