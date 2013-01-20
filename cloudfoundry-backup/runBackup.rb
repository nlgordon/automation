#!/usr/bin/env ruby

require "rubygems"
require "yaml"
require "socket"
require "net/http"
require "multi_json"
require "fileutils"

require "cfoundry"
require "json"
require "tunnel-vmc-plugin/tunnel"

config = JSON.parse(File.open("/opt/config/cloudfoundry").read)

config["servers"].each do |server, target|
  puts "Backing up #{server}"

  parsed = JSON.parse(File.open("/opt/auth/#{server}.auth").read)
  
  serverBackupDir = "/var/backups/#{server}"
  
  if !File.directory?(serverBackupDir)
    Dir.mkdir(serverBackupDir)
  end
  
  date = Date.today.to_s
  
  backupDir = "#{serverBackupDir}/#{date}"
  
  if !File.directory?(backupDir)
    Dir.mkdir(backupDir)
  end
  
  credentials = {
    :username => parsed["user"],
    :password => parsed["password"]
  }
  
  client = CFoundry::Client.new(target, nil)
  #client.trace = true
  
  puts "Logging in"
  client.login(credentials)
  
  puts "Getting instances"
  instances = client.service_instances(:depth => 2)
  
  if instances.empty?
    puts "No instances"
    exit
  end
  
  instances.each do |service|
    if service.vendor = "mysql"
      puts "#{service.name}"
      tunnel = CFTunnel.new(client, service)
      puts "Picking Port"
      port = tunnel.pick_port!("10000")
      conn_info = tunnel.open!
      puts "Tunnel Open"
      tunnel.wait_for_start
      output = "#{backupDir}/backups-#{service.name}.sql"
      
      command = "mysqldump --protocol=TCP --host=localhost --port=#{port} --user=#{conn_info["username"]} --password=#{conn_info["password"]} #{conn_info["name"]} > #{output}"
      puts "Backing up #{service.name}"
      system(command)
    end
  end
end
