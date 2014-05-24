actions :execute
default_action :execute

attribute :command, :kind_of => String, :name_attribute => true
attribute :timeout, :kind_of => Integer, :default => nil