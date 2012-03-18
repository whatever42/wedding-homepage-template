#!/usr/bin/ruby

module Template

	def use_template(filename, hash = {})
		content = File.read(filename)
		return content unless hash
		hash.each_pair do |key, value|
			content = content.gsub(key, value)
		end
		return content
	end

end
