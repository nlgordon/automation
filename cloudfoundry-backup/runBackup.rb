#!/usr/bin/env ruby

require "rubygems"
require "yaml"
require "socket"
require "net/http"
require "multi_json"

require "cfoundry"
require "json"
require "tunnel-vmc-plugin/tunnel"

require "aws/s3"

config = JSON.parse(File.open("/opt/config/cloudfoundry").read)

s3Config = JSON.parse(File.open("/opt/config/dreamhost-objects").read)
s3Auth = JSON.parse(File.open("/opt/auth/#{s3Config["server"]}.auth").read)

puts "Connecting to dreamhost - #{s3Config["server"]}"

AWS::S3::Base.establish_connection!(
        :server            => s3Config["server"],
        :use_ssl           => true,
        :access_key_id     => s3Auth["access_key_id"],
        :secret_access_key => s3Auth["secret_access_key"]
)
puts "Connected"

puts "Getting Bucket #{s3Config["backup-bucket"]}"
bucket = AWS::S3::Bucket.find(s3Config["backup-bucket"])

puts "Bucket Retrieved"
  
config["servers"].each do |server, target|
  puts "Backing up #{server}"

  parsed = JSON.parse(File.open("/opt/auth/#{server}.auth").read)
  
  date = DateTime.now.to_s
  
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
      
      backupObject = "#{server}/#{service.name}/#{date}.sql"
      
      command = "mysqldump --protocol=TCP --host=localhost --port=#{port} --user=#{conn_info["username"]} --password=#{conn_info["password"]} #{conn_info["name"]}"
      puts "Backing up #{service.name}"
      pipe = IO.popen(command, "r")
      results = pipe.read
      
      pipe.close
      
      p $?
      
      if (!$?.exitstatus)
        puts "Error backing up"
        exit
      end
      
      puts "Pushing to Dreamhost as #{backupObject}"
      AWS::S3::S3Object.store(
              backupObject,
              results,
              s3Config["backup-bucket"],
              :content_type => 'text/plain'
      )
      
      puts "Done"
    end
  end
end

