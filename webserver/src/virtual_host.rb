#!/usr/bin/ruby

require 'webrick'

module WEBrick

  class VirtualHostServer < HTTPServer

    def initialize(config)
      super(config)
      @virtual_hosts = []
    end

    def virtual_host(server)
      @virtual_hosts << server
    end

    def service(req, res)
      if server = lookup_server(req)
        server.service(req, res)
      else
        super
      end
    end

    def lookup_server(req)
      @virtual_hosts.find{|server|
	pattern = server[:host_pattern]
	if pattern.instance_of?(String)
		pattern == req.host
	else
		pattern =~ req.host
	end
      }
    end

  end

  class VirtualHost < HTTPServer

    def initialize(options)
      options[:DoNotListen] = true
      super(options)
    end

  end

end

