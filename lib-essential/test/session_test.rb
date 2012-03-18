#!/usr/bin/ruby

require 'test/unit'
require 'lib-essential/session'




class SessionTest < Test::Unit::TestCase

# def setup
# end

# def teardown
# end

	def test_session
		sess1 = "hallo"
		assert_equal(nil, Session.current_env)
		Session.session(sess1) do
			assert_equal(sess1, Session.current_env)
		end
	end

	def test_session_init
		sess1 = "hallo2"
		assert_equal(nil, Session.current_env)
		session = Session.new(sess1)
		assert_equal(nil, Session.current_env)
		session.session() do
			assert_equal(sess1, Session.current_env)
		end
	end

	def test_session_recursive
		sess1 = "foo"
		sess2 = "bar"
		assert_equal(nil, Session.current_env)

		Session.session(sess1) do
			assert_equal(sess1, Session.current_env)
			assert_equal(nil, Session.current.parent)
			Session.session(sess2) do
				assert_equal(sess2, Session.current_env)
				assert_equal(sess1, Session.current.parent.env)
			end
		end
	end
end

