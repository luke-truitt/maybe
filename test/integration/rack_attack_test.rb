# frozen_string_literal: true

require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  test "rack attack is configured" do
    middleware_classes = Rails.application.middleware.map(&:klass)
    assert_includes middleware_classes, Rack::Attack, "Rack::Attack should be in middleware stack"
  end

  test "malicious requests are blocked" do
    blocklists = Rack::Attack.blocklists.keys
    assert_includes blocklists, "block malicious requests"
  end
end
