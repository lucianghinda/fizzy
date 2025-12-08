require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    untenanted do
      get new_session_path
    end

    assert_response :success
  end

  test "create" do
    identity = identities(:kevin)

    untenanted do
      assert_difference -> { MagicLink.count }, 1 do
        post session_path, params: { email_address: identity.email_address }
      end

      assert_redirected_to session_magic_link_path
      assert_nil flash[:magic_link_code]
    end
  end

  test "create for a new user" do
    untenanted do
      assert_difference -> { MagicLink.count }, +1 do
        assert_difference -> { Identity.count }, +1 do
          post session_path,
            params: { email_address: "nonexistent-#{SecureRandom.hex(6)}@example.com" }
        end
      end

      assert_redirected_to session_magic_link_path
      assert MagicLink.last.for_sign_up?
    end
  end

  test "create with invalid email address" do
    # Avoid Sentry exceptions when attackers try to stuff invalid emails. The browser performs form
    # field validation that should normally prevent this from occurring, so I'm not worried about
    # returning proper validation errors.
    without_action_dispatch_exception_handling do
      untenanted do
        assert_no_difference -> { Identity.count } do
          post session_path, params: { email_address: "not-a-valid-email" }
        end

        assert_response :unprocessable_entity
      end
    end
  end

  test "destroy" do
    sign_in_as :kevin

    untenanted do
      delete session_path

      assert_redirected_to new_session_path
      assert_not cookies[:session_token].present?
    end
  end

  test "create for existing user bypasses domain restriction" do
    identity = identities(:kevin)
    original_value = ENV["ALLOWED_SIGNUP_DOMAIN"]
    ENV["ALLOWED_SIGNUP_DOMAIN"] = "allowed.com"

    begin
      untenanted do
        # Existing user can log in even if their domain is not allowed
        assert_difference -> { MagicLink.count }, +1 do
          post session_path, params: { email_address: identity.email_address }
        end

        assert_redirected_to session_magic_link_path
      end
    ensure
      ENV["ALLOWED_SIGNUP_DOMAIN"] = original_value
    end
  end

  test "create for new user with allowed domain" do
    original_value = ENV["ALLOWED_SIGNUP_DOMAIN"]
    ENV["ALLOWED_SIGNUP_DOMAIN"] = "allowed.com"

    begin
      untenanted do
        assert_difference -> { Identity.count }, +1 do
          post session_path, params: { email_address: "newuser@allowed.com" }
        end

        assert_redirected_to session_magic_link_path
      end
    ensure
      ENV["ALLOWED_SIGNUP_DOMAIN"] = original_value
    end
  end

  test "create for new user with disallowed domain will fail" do
    original_value = ENV["ALLOWED_SIGNUP_DOMAIN"]
    ENV["ALLOWED_SIGNUP_DOMAIN"] = "allowed.com"

    begin
      untenanted do
        assert_no_difference -> { Identity.count } do
          post session_path, params: { email_address: "newuser@blocked.com" }
        end

        assert_response :unprocessable_entity
      end
    ensure
      ENV["ALLOWED_SIGNUP_DOMAIN"] = original_value
    end
  end

  test "create for new user without domain restriction blocks sign in in production" do
    original_value = ENV["ALLOWED_SIGNUP_DOMAIN"]
    ENV.delete("ALLOWED_SIGNUP_DOMAIN")

    begin
      Rails.env.stubs(:test?).returns(false)

      untenanted do
        assert_no_difference -> { Identity.count } do
          post session_path, params: { email_address: "newuser@anydomain.com" }
        end

        assert_response :unprocessable_entity
      end
    ensure
      ENV["ALLOWED_SIGNUP_DOMAIN"] = original_value
    end
  end
end
