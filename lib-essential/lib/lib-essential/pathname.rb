#!/usr/bin/ruby

require 'pathname'

class Pathname

	# globs for the specified pattern in the specified path
	def glob(pattern, &block)
		res = []
		Dir.chdir(self) do
			Dir.glob(pattern) do |file|
				filepath = self.join(Pathname.new(file))
				block.call(filepath)
				res << filepath
			end
		end
		return res
	end

end
