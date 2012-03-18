#!/usr/bin/ruby

require 'webrick'
require 'fileutils'
require 'pathname'

require 'src/virtual_host'
require 'src/webserver_servlet'
require 'src/ruby_essentials'
require 'src/servlets'

include WEBrick

CONFIG_FILES = ["config/webrick.config"]
DEFAULT_CONFIG = {
	:root_dir => FileUtils.pwd(),
	:Port => 8080,
	:daemonize => false,
	:log_base_dir => FileUtils.pwd(),
	:log_file => "webrick.log",
	:log_level => Log::DEBUG,
	:servlets => [],
	:virtual_hosts => []
}
DEFAULT_VIRTUAL_HOST_CONFIG = {
	:root_dir => FileUtils.pwd(),
	:log_base_dir => FileUtils.pwd(),
	:log_file => "webrick.log",
	:log_level => Log::DEBUG,
	:servlets => [],
	:virtual_hosts => []
}
SERVLET_DIR = 'servlets'
SERVLET_MAIN_FILENAME = 'servlet.rb'
LIBS_DIR = 'libs'

$: << LIBS_DIR
require 'lib-message/message'

def start_webrick(config, virtual = false, &block)
  # TODO: build a seperate config for WEBRick
  # default: listen on port 8080
  config.update(:Port => 8080) unless config[:Port] and !virtual
  config.update(:ServerType => WEBrick::Daemon) if config[:daemonize] and !virtual
  if config[:log_file]
	log_path = Pathname.new(config[:log_file])
	config[:log_file] = "#{config[:log_base_dir]}/#{config[:log_file]}" unless log_path.absolute?
	log_level = config[:log_level] || Log::INFO
	log_dir = File.dirname(config[:log_file])
	FileUtils.mkdir_p(log_dir) unless File.exists?(log_dir)
  	config.update(:Logger => Log.new(config[:log_file], log_level))
  end
  if config[:message_file]
    Message.init(config[:message_file])
  end
  if virtual
    server = VirtualHost.new(config)
  else
    server = VirtualHostServer.new(config)
  end
  block.call(server, config)
  if config[:virtual_hosts]
    config[:virtual_hosts].each do |host_config|
      host = start_webrick(host_config, true, &block)
      server.virtual_host(host)
    end
  end
  return server if virtual
  ['INT', 'TERM'].each {|signal| 
    trap(signal) {server.shutdown}
  }
  server.start
end


def merge_servlets(old, new)
	return old.deep_clone unless new
	return new.deep_clone unless old
	res = old.deep_clone
	hash = {}
	res.each_with_index do |servlet, index|
		key = servlet[:name]
		raise RuntimError.new("servlet does already exist #{servlet[:name].inspect}") if hash.has_key?(key)
		hash[key] = index
	end
	new.each do |servlet|
		key = servlet[:name]
		if hash.has_key?(key)
			index = hash[key]
			res[index] = res[index].update(servlet)
		else
			res << servlet.deep_clone
		end
	end
	return res
end

def merge_virtual_hosts(old, new)
	old = old.deep_clone
	new = new.deep_clone
	res = []
	old.each do |host|
		res << merge_configs(DEFAULT_VIRTUAL_HOST_CONFIG, host)
	end
	unless new
		return res
	end
	hash = {}
	res.each_with_index do |host, index|
		raise RuntimError.new("virtual host does already exist #{host[:name].inspect}") if hash.has_key?(host[:name])
		hash[host[:name]] = index
	end
	new.each do |host|
		key = host[:name]
		if hash.has_key?(key)
			index = hash[key]
			res[index] = merge_configs(res[index], host)
		else
			res << result = merge_configs(DEFAULT_VIRTUAL_HOST_CONFIG, host)
		end
	end
	return res
end

def merge_configs(old, new)
	old = old.deep_clone
	new = new.deep_clone
	servlets = merge_servlets(old[:servlets], new[:servlets])
	virtual_hosts = merge_virtual_hosts(old[:virtual_hosts], new[:virtual_hosts])

	res = old.update(new)
	res[:servlets] = servlets
	res[:virtual_hosts] = virtual_hosts
	res
end

def load_config()
	config = DEFAULT_CONFIG
	CONFIG_FILES.each do |config_file|
		if File.exists?(config_file)
			puts "loading config file #{config_file}"
			config = merge_configs(config, eval(File.read(config_file), nil, config_file))
		else
			puts "config file #{config_file} could not be found"
		end
	end
	return config
end

def load_servlets
	servlet_dirs = Dir.glob("#{SERVLET_DIR}/*")
	servlet_dirs.each do |servlet_dir|
		require_servlet(servlet_dir)
	end
end


# Main

load_servlets()
server_config = load_config()

start_webrick(server_config) do |server, config|
	server_info = {
		:log_base_dir => config[:log_base_dir]
	}
	config[:servlets].each do |servlet_config|
		name = servlet_config[:name]
		servlet_desc = Servlets.get_servlet_by_name(name)
		raise RuntimeError.new("Servlet #{name} not found") unless servlet_desc
		puts "mounting servlet #{name} to #{servlet_config[:mountpoint]} on #{config[:name] || "root"}"
		servlet_config[:config][:name] ||= servlet_config[:name]
		arguments = servlet_desc[:servlet].mounting_arguments(server_info, servlet_config[:config])
		server.mount(servlet_config[:mountpoint], servlet_desc[:servlet], *arguments)
	end
end


