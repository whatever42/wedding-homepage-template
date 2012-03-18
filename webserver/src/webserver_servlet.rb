#!/usr/bin/ruby

require 'webrick'

class WebServerServlet < WEBrick::HTTPServlet::AbstractServlet
	
	@@servlet_path = nil

	def initialize(server, *options)
		super(server, *options)
		#@logger = create_logger()
	end

	def servlet_path
		@@servlet_path
	end

	def self.servlet_path
		@@servlet_path
	end

	def self.servlet_path=(path)
		@@servlet_path = path
	end

	def self.mounting_arguments(server_info, config)
		[server_info, config]
	end

	def config
		@options[1]
	end

	def info
		@options[0]
	end

	def redirect(resp, url)
	      resp['location'] = url
	      resp.body = "<a href='#{url}'>#{url}</a>"
	      resp.status = 303
	end

private

	def create_logger()
		Log.new(determine_log_file, config[:log_level] || Log::INFO)
	end

	def determine_log_file
		if config[:log_file]
			log_path = Pathname.new(config[:log_file])
			return log_path.to_s if log_path.absolute?
			return "#{info[:log_base_dir]}/#{log_path.to_s}"
		end
		return "#{info[:log_base_dir]}/#{config[:name]}.log"
	end

end

