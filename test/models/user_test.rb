require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes email and authenticates with a password" do
    organization = Organization.create!(name: "Acme Properties")
    user = organization.users.create!(
      email: "  AGENT@EXAMPLE.COM ",
      first_name: "Ada",
      last_name: "Agent",
      password: "correct horse battery staple"
    )

    assert_equal "agent@example.com", user.email
    assert user.authenticate("correct horse battery staple")
    assert_not user.authenticate("wrong password")
    assert_equal organization, user.organization
  end
end