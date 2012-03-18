#!/usr/bin/ruby

class Servlets

	@@servlets = {}
	@@path_index = {}

	def self.add_servlet(desc)
		key = desc[:name]
		path = desc[:path]
		raise RuntimeError.new("servlet description incomplete") unless key and path
		if @@servlets.has_key?(key)
			if desc[:version] > @@servlets[key][:version]
				@@servlets[key] = desc
				@@path_index[path] = desc
			end
			puts "WARNING: duplicate servlet #{key}. using version #{@@servlets[key][:version]}"
		else
			@@servlets[key] = desc
			@@path_index[path] = desc
		end
	end

	def self.get_servlet_by_name(name)
		@@servlets[name]
	end

	def self.get_servlet_by_path(path)
		@@path_index[path]
	end

end

module Kernel
	def require_servlet(servlet_dir)
		servlet_filename = "#{servlet_dir}/#{SERVLET_MAIN_FILENAME}"
		raise RuntimeError.new("servlet #{servlet_dir} could not be found") unless File.exists?(servlet_filename)
		return if Servlets.get_servlet_by_path(servlet_dir)		# servlet already loaded?

		puts "loading servlet #{servlet_dir}"
		old_path = WebServerServlet.servlet_path
		WebServerServlet.servlet_path = "#{FileUtils.pwd}/#{servlet_dir}"
		$: << servlet_dir
		servlet_desc = eval(File.read(servlet_filename), nil, servlet_filename)
		servlet_desc[:path] = servlet_dir
		Servlets.add_servlet(servlet_desc)
		WebServerServlet.servlet_path = old_path
	end
end
