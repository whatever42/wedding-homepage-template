#!/usr/bin/ruby

require 'yaml'
require 'digest/md5'

class Authentication

	def initialize(filename, hash = true)
		@filename = filename
		@hash = hash
		load_passwords()
	end
	
	def load_passwords()
		@passwd = YAML.load(File.read(@filename))
	end

	def save_passwords()
		File.open(@filename, "w") do |f|
			f.print(@passwd.to_yaml)
		end
	end

	def authenticate(user, pass)
		return nil unless @passwd.has_key?(user)
		pass = hash_password(pass) if @hash
		if @passwd[user][:pass] == pass
			return @passwd[user].dup
		end
	end

	def change_password(user, old_pass, new_pass)
		return false unless authenticate(user, old_pass)
		return false unless new_pass.size > 0
		new_pass = hash_password(new_pass.to_s) if @hash
		@passwd[user][:pass] = new_pass.to_s
		save_passwords()
		return true
	end

	def hash_password(plain)
		digest = Digest::MD5.new
		digest.update(plain)
		return digest.hexdigest
	end

end
