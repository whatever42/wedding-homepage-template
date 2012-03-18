#!/usr/bin/ruby

require 'test/unit'
require 'lib-essential/report'




class ReportTest < Test::Unit::TestCase

# def setup
# end

# def teardown
# end

	class MyReporter < Reporter
		reports(:some_problem => [:thing, " is wrong in ", :location],
			:advice => ["you should ", :action, " ", :object])
	end

	class AnotherReporter < Reporter
		reports(:some_problem => [:object, " is about to be ", :verb])
	end

	def test_report_when_ok
		report = MyReporter.new().assemble()
		assert_equal(true, report.ok?)
		assert_equal(0, report.size)
	end

	def test_report_when_something_happened
		reporter = MyReporter.new()
		reporter.report_some_problem(:thing => "something", :location => "Marseilles", :subreport => AnotherReporter.new().assemble())
		reporter.report_advice(:action => "drink", :object => "some tea", :data => :hallo)
		report = reporter.assemble()

		assert_equal(false, report.ok?)
		assert_equal(2, report.size)
		report.each do |message|
			case message
			when MyReporter::MyReport::SomeProblemMessage
				assert_equal("something is wrong in Marseilles", message.to_s)
				assert_equal([:thing, :location, :subreport] - message.keys, [])
				assert_equal("something", message.thing)
				assert_equal(true, message.has_subreport?)
				assert_equal(AnotherReporter.new().assemble(), message.subreport)
			when MyReporter::MyReport::AdviceMessage
				assert_equal("you should drink some tea", message.to_s)
				assert_equal([:data, :action, :object] - message.keys, [])
				assert_equal("drink", message.action)
				assert_equal(true, message.has_data?)
				assert_equal(:hallo, message.data)
			else
				raise RuntimeError.new("unknown message type")
			end
		end
	end

	def test_report_when_undefined
		reporter = MyReporter.new()
		begin
			reporter.report_some_problem(:location => "Marseilles")
		rescue RuntimeError => e
			assert_equal("hash does not fit message", e.message)
		end
		begin
			reporter.report_some_problem(:thing => "something", :location => "Marseilles", :think => "don't think")
		rescue RuntimeError => e
			assert_equal("hash does not fit message", e.message)
		end
	end

end

