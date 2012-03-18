#!/usr/bin/ruby

require 'fileutils'
require 'pathname'

require 'lib-message/message'

class FileStorage

	def initialize(path, size, logger, interval, mailserver, email)
		@path = path
		@size = size
		@logger = logger
		@clean = true
		@interval = interval
		@mailserver = mailserver
		@email = email
		start_watch_thread(@interval)
	end

	def store(username, filename, contents)
		return unless filename.size > 0
		raise RuntimeError.new("storage space exceeded") if contents.size > free()
		dir = "#{@path}/#{username}"
		FileUtils.mkdir_p(dir) unless File.directory?(dir)
		fname = "#{dir}/#{filename}"
		raise RuntimeError.new("file not in upload dir") unless is_in?(dir, fname)
		@logger.info("user #{username} uploaded file #{filename}")
		@clean = false
		File.open(fname, "w") do |file|
			file.print(contents)
		end
	end

	def remove(username, filename)
		return unless filename.size > 0
		dir = "#{@path}/#{username}"
		fname = "#{dir}/#{filename}"
		raise RuntimeError.new("file not in upload dir") unless is_in?(dir, fname)
		raise RuntimeError.new("could not find file #{CGI.escapeHTML(filename)}") unless File.exists?(fname)
		@logger.info("user #{username} deleted file #{filename}")
		FileUtils.rm(fname)
	end

	def size
		@size
	end

	def used
		return 0 unless File.directory?(@path)
		unless `du --block-size=1 -s #{@path}`.chomp =~ /(\d+)\t/
			raise RuntimeError.new("could not determine free space")
		end
		return Integer($1)
	end

	def free
		@size - used()
	end

	def list(username)
		dir = "#{@path}/#{username}"
		return [] unless File.directory?(dir)
		list = []
		FileUtils.cd(dir) do
			list = Dir.glob("*")
		end
		return list
	end

	def clean?
		@clean
	end

	def clean!
		@clean = true
	end

private

	def is_in?(dir, sub)
		dir = Pathname.new(dir).cleanpath
		sub = Pathname.new(sub).cleanpath
		while !sub.root?
			return true if sub == dir
			sub = sub.parent
		end
		return false
	end

	def start_watch_thread(interval)
		Thread.abort_on_exception = true
		Thread.start(self, interval) do |storage, interval|
			@logger.info("watch thread started with interval = #{interval.inspect}")
			while true
				sleep(interval)
				unless storage.clean?
					storage.clean!
					send_notification()
				end
			end
		end
	end

public

	def send_notification()
		Message.info("File Storage dirty! - please clean it up.")
	end

=begin
	def self.send_mail(host, from, to, subject, body)
		# DEBUG
		puts "in send_mail"
		mailtext = "From: #{from}\r\nTo: #{to}\r\nSubject: #{subject}\r\n\r\n#{body}"

		# DEBUG
		puts mailtext

		Net::SMTP.start(host) do |smtp|
			smtp.sendmail(mailtext, from, [to])
		end
	end
=end

end
