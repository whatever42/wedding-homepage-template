#!/usr/bin/ruby

require 'test/unit'
require 'lib-essential/execute'




class ExecuteTest < Test::Unit::TestCase

# def setup
# end

# def teardown
# end

	def test_sub_cmd_stdout_return
		list = run_sub_cmd(:cmd => "ls", :stdout => :return)
		assert_equal(`ls`, list)
	end

	def test_sub_cmd_argument_expansion
		actual = run_sub_cmd(:cmd => ["echo", "$PATH"], :stdout => :return)
		assert_equal("$PATH\n", actual);
		actual = run_sub_cmd(:cmd => "echo $PWD", :stdout => :return)
		assert_equal(Dir.pwd() + "\n", actual);
	end

	def test_sub_cmd_block
		actual = run_sub_cmd(:stdout => :return, :stderr => :return) do
			puts "foo"
			$stderr.puts "bar"
		end
		assert_equal(["foo\n", "bar\n"], actual)
	end

	def test_sub_cmd_stdout2stderr
		actual = run_sub_cmd(:stderr => :return) do
			run_sub_cmd(:cmd => "ls", :stdout => $stderr)
		end
		assert_equal(`ls`, actual)
	end

	def test_pid_info
		info = ProcessInfo.new
		Thread.new do
			while info.pid == nil
				sleep 0.3
			end
			Process.kill("INT", info.pid)
		end
		actual = run_sub_cmd(:info => info, :stdout => :return) do
			repeat = true
			trap("INT") do
				puts "interrupted by SIGINT"
				repeat = false
			end
			while repeat
			end
		end
		assert_equal("interrupted by SIGINT\n", actual)
	end


end

