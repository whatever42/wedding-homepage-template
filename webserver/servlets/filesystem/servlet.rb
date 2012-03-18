#!/usr/bin/ruby

require 'webrick'
require 'src/webserver_servlet'
require 'fileutils'

class WEBrick::HTTPServlet::FileHandler

	@@path = WebServerServlet.servlet_path

	def self.mounting_arguments(server_info, config)
		doc_root = config[:doc_root] 
		doc_root = "#{@@path}/#{config[:doc_root]}" unless config[:doc_root] =~ /^\//
		config.delete(:doc_root)
		# DEBUG
		puts "doc_root=#{doc_root}"
		[doc_root, config]
	end

end

{
	:name => "filesystem",
	:version => "0.01",
	:servlet => WEBrick::HTTPServlet::FileHandler
}

