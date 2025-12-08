require "test_helper"

class SignupTest < ActiveSupport::TestCase
  test "validates email format for identity creation" do
    signup = Signup.new(email_address: "not-an-email")
    assert_not signup.valid?(:identity_creation)
    assert signup.errors[:email_address].any?

    signup = Signup.new(email_address: "valid@example.com")
    assert signup.valid?(:identity_creation)
  end

  test "#create_identity" do
    signup = Signup.new(email_address: "brian@example.com")

    magic_link = nil
    assert_difference -> { Identity.count }, 1 do
      assert_difference -> { MagicLink.count }, 1 do
        magic_link = signup.create_identity
      end
    end

    assert_kind_of MagicLink, magic_link
    assert_empty signup.errors
    assert signup.identity
    assert signup.identity.persisted?

    signup_existing = Signup.new(email_address: "brian@example.com")

    assert_no_difference -> { Identity.count } do
      assert_difference -> { MagicLink.count }, 1 do
        magic_link = signup_existing.create_identity
      end
    end

    assert_kind_of MagicLink, magic_link

    signup_invalid = Signup.new(email_address: "")
    assert_raises do
      signup_invalid.create_identity
    end
  end

  test "#create_identity with allowed domain restriction" do
    original_value = ENV["ALLOWED_SIGNUP_DOMAIN"]
    ENV["ALLOWED_SIGNUP_DOMAIN"] = "allowed.com"

    begin
      # Allowed domain succeeds
      signup_allowed = Signup.new(email_address: "user@allowed.com")
      assert_difference -> { Identity.count }, 1 do
        assert signup_allowed.create_identity
      end
      assert_empty signup_allowed.errors

      # Disallowed domain fails
      signup_blocked = Signup.new(email_address: "user@other.com")
      assert_raises SignupDomainRestricted do
        signup_blocked.create_identity
      end
      assert_not_empty signup_blocked.errors[:email_address]
    ensure
      ENV["ALLOWED_SIGNUP_DOMAIN"] = original_value
    end
  end

  test "#create_identity without domain restriction blocks all signups in production" do
    original_value = ENV["ALLOWED_SIGNUP_DOMAIN"]
    ENV.delete("ALLOWED_SIGNUP_DOMAIN")

    begin
      # Stub Rails.env.test? to return false (simulate production)
      Rails.env.stubs(:test?).returns(false)

      # When env var is not set in production, all domains are blocked
      signup = Signup.new(email_address: "user@anydomain.com")
      assert_raises SignupDomainRestricted do
        signup.create_identity
      end
      assert_not_empty signup.errors[:email_address]
    ensure
      ENV["ALLOWED_SIGNUP_DOMAIN"] = original_value
    end
  end

  test "#create_identity with empty domain restriction blocks all signups in production" do
    original_value = ENV["ALLOWED_SIGNUP_DOMAIN"]
    ENV["ALLOWED_SIGNUP_DOMAIN"] = ""

    begin
      # Stub Rails.env.test? to return false (simulate production)
      Rails.env.stubs(:test?).returns(false)

      # Empty string should block all signups in production
      signup = Signup.new(email_address: "user@anydomain.com")
      assert_raises SignupDomainRestricted do
        signup.create_identity
      end
      assert_not_empty signup.errors[:email_address]
    ensure
      ENV["ALLOWED_SIGNUP_DOMAIN"] = original_value
    end
  end

  test "#create_identity domain validation is case insensitive" do
    original_value = ENV["ALLOWED_SIGNUP_DOMAIN"]
    ENV["ALLOWED_SIGNUP_DOMAIN"] = "allowed.com"

    begin
      # Test uppercase domain is accepted
      signup_upper = Signup.new(email_address: "user1@ALLOWED.COM")
      assert_difference -> { Identity.count }, 1 do
        assert signup_upper.create_identity
      end
      assert_empty signup_upper.errors

      # Test mixed case domain is accepted
      signup_mixed = Signup.new(email_address: "user2@Allowed.Com")
      assert_difference -> { Identity.count }, 1 do
        assert signup_mixed.create_identity
      end
      assert_empty signup_mixed.errors
    ensure
      ENV["ALLOWED_SIGNUP_DOMAIN"] = original_value
    end
  end

  test "#complete" do
    Account.any_instance.expects(:setup_customer_template).once

    Current.without_account do
      signup = Signup.new(full_name: "Kevin", identity: identities(:kevin))

      assert signup.complete

      assert signup.account
      assert signup.user
      assert_equal "Kevin", signup.user.name

      signup_invalid = Signup.new(
        full_name: "",
        identity: identities(:kevin)
      )
      assert_not signup_invalid.complete
      assert_not_empty signup_invalid.errors[:full_name]
    end
  end

  test "#complete with invalid data" do
    Current.without_account do
      signup = Signup.new
      assert_not signup.complete
      assert signup.errors[:full_name].any?
      assert signup.errors[:identity].any?
      assert_nil signup.account
      assert_nil signup.user
    end
  end
end
