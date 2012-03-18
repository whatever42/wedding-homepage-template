#!/usr/bin/ruby

require 'webrick'
require 'src/webserver_servlet'
require 'contents'

class TestServlet < WebServerServlet

	@@path = servlet_path

	def do_GET(req, resp)
		info = @options[0]
		config = @options[1]

		resp.body = TestContents::CONTENTS + " - " + config[:testvalue] + " - " + @@path
		raise HTTPStatus::OK
	end

	alias_method :do_POST, :do_GET    # let's accept POST request too.

end

{
	:name => "test",
	:version => "0.01",
	:servlet => TestServlet
}

