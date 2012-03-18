#!/usr/bin/ruby

class Reporter

	class Report

		class Message

			class List < Array

				def to_s
					self.join("\n")
				end
		      
			end

			def initialize(hash)
				@hash = hash
			end

			def [](key)
				@hash[key]
			end

			def keys
				@hash.keys
			end

			def to_s
				raise RuntimeError.new("classes inheriting from Reporter::Report::Message should override the to_s() method")
			end

			def has_subreport?
				@hash.has_key?(:subreport)
			end

			def subreport
				@hash[:subreport]
			end

			def has_data?
				@hash.has_key?(:data)
			end

			def data
				@hash[:data]
			end

			def ==(o)
				return false unless o.keys.size == @hash.keys.size
				return o.keys.all? { |key| @hash[key] == o[key] }
			end

		end

		def initialize(messages)
			@messages = messages
		end

		def ok?
			@messages.size == 0
		end

		def each(&block)
			@messages.each(&block)
		end

		def [](i)
			@messages[i]
		end

		def size
			@messages.size
		end

		def ==(o)
			return false unless o.size == size
			o.each do |msg|
				return false unless @messages.include?(msg)
			end
			return true
		end

		def +(o)
			self.class.new(@messages + o.messages)
		end

		def messages
			@messages
		end
		protected :messages
	end

	def initialize()
		@messages = []
	end

	def self.reports(message_hash)
		report_class = get_or_create_report_class()

		message_hash.each_pair do |key, gene|
			# create message class
			properties = gene.select{ |part| part.is_a?(Symbol) }
			message_class = Class.new(Report::Message)
			properties.each do |prop|
				self.create_method(message_class, prop) { self[prop] }
			end
			self.create_method(message_class, :to_s) do
				gene.map do |item|
					@hash.has_key?(item) ? @hash[item].to_s : item.to_s
				end.join("")
			end
			report_class.const_set("#{self.camelcase(key.to_s)}Message", message_class)

			# create report_ method
			define_method(("report_" + key.to_s).to_sym) { |hash| report(hash, message_class, message_hash[key]) }
		end
	end

	def report(hash, message_class, gene)
		unless hash_fits_message(hash, gene)
			raise RuntimeError.new("hash does not fit message") 
		end
		@messages << message_class.new(hash)
		return self
	end

	def assemble()
		Report.new(@messages.clone)
	end

	def ok?
		@messages.size == 0
	end

private

	def self.create_method(clazz, name, &block)
		clazz.send(:define_method, name, &block)
	end

	def self.get_or_create_report_class()
		report_class_name = self.name.split("::")[-1]
		report_class_name = $1 if report_class_name =~ /^(.*)Reporter$/
		report_class_name += "Report"

		if self.const_defined?(report_class_name.to_sym)
			return self.const_get(report_class_name.to_sym)
		else
			report_class = Class.new(Report)
			self.const_set(report_class_name, report_class)
			return report_class
		end
	end

	def self.camelcase(str)
		res = str.gsub(/_(.)/) { |match| $1.upcase }
		res = res[0,1].upcase + res[1,res.size]
	end

	def hash_fits_message(hash, gene)
		return false unless hash.keys.all?{ |key| [:data, :subreport].include?(key) or gene.include?(key) }
		return false unless gene.select{ |part| part.is_a?(Symbol) }.all?{ |sym| hash.has_key?(sym) }
		return true
	end

end
