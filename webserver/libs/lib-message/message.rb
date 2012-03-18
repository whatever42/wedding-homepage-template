#!/usr/bin/ruby

class Message

	@@logger = nil

	def self.init(filename)
		@@logger = Log.new(filename)
	end

	def self.info(msg)
		@@logger.info(msg) if @@logger
	end

end