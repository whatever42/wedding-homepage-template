#!/usr/bin/ruby

require 'webrick'

class Session

	def initialize
		@session_cookie_name = "SESSIONID"
		@max_sessions = 1000
		@session_timeout = 3600  # 1h

		@sessions = {}
	end

	def create_new(data)
		if (@sessions.size >= @max_sessions)
			remove_expired()
			raise RuntimeError.new("too many open sessions") if (@sessions.size >= @max_sessions)
		end
		id = generate_new_id()
		@sessions[id] = {:data => data, :touched => Time.now()}
		return id
	end

	def [](id)
		return nil unless @sessions.has_key?(id)
		now = Time.now()
		if (now - @sessions[id][:touched]) >= @session_timeout
			remove(id)
			return nil
		end
		@sessions[id][:touched] = now
		@sessions[id][:data]
	end

	def []=(id, value)
		return nil unless @sessions.has_key?(id)
		@sessions[id][:touched] = Time.now()
		@sessions[id][:data] = value
	end

	def remove(id)
		@sessions.delete(id)
	end

	def remove_expired()
		now = Time.now()
		@sessions.delete_if do |id, hash|
			(now - hash[:touched]) >= @session_timeout
		end
	end

	def generate_new_id()
		id = generate_new_id_int()
		while (@sessions.has_key?(id))
			id = generate_new_id_int()
		end
		return id
	end

	def add_session_cookie(resp, session_id)
		session_cookie = Cookie.new(@session_cookie_name, session_id)
		session_cookie.path = "/"
		session_cookie.expires = Time.now() + @session_timeout
		resp.cookies << session_cookie
	end

	def logout(resp, session_id)
		remove(session_id)
		session_cookie = Cookie.new(@session_cookie_name, "")
		session_cookie.path = "/"
		session_cookie.max_age = 0
		resp.cookies << session_cookie
	end

	def get_session_from_cookies(req)
		session_id = get_value_from_cookies(req, @session_cookie_name)
		return session_id, self[session_id]
	end

private

	def get_value_from_cookies(req, name)
		req.cookies.each do |cookie|
			if cookie.name == name
				return cookie.value
			end
		end
		return nil
	end

	def generate_new_id_int()
		rand(10**32).to_s
	end

end


