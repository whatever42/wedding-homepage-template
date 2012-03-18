#!/usr/bin/ruby


class Session
	attr_reader :thread, :parent, :env

	def initialize(env)
		@env = env
		@thread = Thread.current
		@parent = @thread[:session]
	end

	def session()
		raise RuntimeError.new("must be created in same thread it was created in") unless @thread == Thread.current
		@thread[:session] = self
		begin
			yield
		ensure
			@thread[:session] = @parent
		end
	end

	def self.session(env, &block)
		self.new(env).session(&block)
	end

	def self.current
		Thread.current[:session]
	end

	def self.current_env
		session = Thread.current[:session]
		return nil unless session
		return session.env
	end
end
