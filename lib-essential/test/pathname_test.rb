#!/usr/bin/ruby

require 'test/unit'
require 'lib-essential/pathname'




class PathnameTest < Test::Unit::TestCase

	def test_glob
		path = Pathname.new("test")
		res = path.glob("pathname*") do |item|
			assert_equal(Pathname.new("test/pathname_test.rb"), item)
		end
		assert_equal([Pathname.new("test/pathname_test.rb")], res)
	end

end
