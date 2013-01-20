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

file = File.open("/opt/auth/api.cloudfoundry.com.auth")
parsed = JSON.parse(file.read)

date = Date.today.to_s

backupDir = "/var/backups/api.cloudfoundry.com/#{date}"

if !File.directory?(backupDir)
  Dir.mkdir(backupDir)
end

credentials = {
  :username => parsed["user"],
  :password => parsed["password"]
}

client = CFoundry::Client.new("https://api.cloudfoundry.com", nil)
#client.trace = true

p "Loggin in"
client.login(credentials)

p "Getting instances"
instances = client.service_instances(:depth => 2)

if instances.empty?
  p "No instances"
  exit
end

instances.each do |service|
  if service.vendor = "mysql"
    p "#{service.name}"
    tunnel = CFTunnel.new(client, service)
    p "Picking Port"
    port = tunnel.pick_port!("10000")
    conn_info = tunnel.open!
    p "Tunnel Open"
    tunnel.wait_for_start
    output = "#{backupDir}/backups-#{service.name}.sql"
    
    command = "mysqldump --protocol=TCP --host=localhost --port=#{port} --user=#{conn_info["username"]} --password=#{conn_info["password"]} #{conn_info["name"]} > #{output}"
    p "Backing up #{service.name}"
    system(command)
  end
end