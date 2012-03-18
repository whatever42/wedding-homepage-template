#!/usr/bin/ruby

require 'test/unit'
require 'lib-essential/resource'


class ResourceTest < Test::Unit::TestCase

# def setup
# end

# def teardown
# end

	def test_resource_resolution
		actual = resolve_resource("lib-essential/resource.rb")
		assert_equal("./lib-essential/resource.rb", actual)
	end

	def test_resource_resolution_when_failure
		begin
		  resolve_resource("lib-essential/resource2.rb")
		  fail
		rescue LoadError => e
		  # expected
		end
	end
end

