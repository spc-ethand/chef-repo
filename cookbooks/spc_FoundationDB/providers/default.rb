action :execute do
  cmd = "fdbcli --exec '#{@new_resource.command}'"
  cmd += " --timeout #{@new_resource.timeout}" if @new_resource.timeout

  execute "#{@new_resource.name}" do
    command cmd
  end
end