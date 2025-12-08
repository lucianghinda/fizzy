require "test_helper"

class SignupsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    untenanted do
      get new_signup_path

      assert_response :success
    end
  end

  test "new for an authenticated user" do
    identity = identities(:kevin)
    sign_in_as identity

    untenanted do
      get new_signup_path

      assert_redirected_to new_signup_completion_path
    end
  end

  test "create" do
    email_address = "newuser-#{SecureRandom.hex(6)}@example.com"

    untenanted do
      assert_difference -> { Identity.count }, +1 do
        assert_difference -> { MagicLink.count }, +1 do
          post signup_path, params: { signup: { email_address: email_address } }
        end
      end

      assert_redirected_to session_magic_link_path
    end
  end

  test "create with invalid email address" do
    without_action_dispatch_exception_handling do
      untenanted do
        assert_no_difference -> { Identity.count } do
          assert_no_difference -> { MagicLink.count } do
            post signup_path, params: { signup: { email_address: "not-a-valid-email" } }
          end
        end

        assert_response :unprocessable_entity
      end
    end
  end

  test "create for an authenticated user" do
    identity = identities(:kevin)
    sign_in_as identity

    untenanted do
      assert_no_difference -> { Identity.count } do
        assert_no_difference -> { MagicLink.count } do
          post signup_path,
            params: { signup: { email_address: identity.email_address } }
        end
      end

      assert_redirected_to new_signup_completion_path
    end
  end

  test "create with allowed domain" do
    original_value = ENV["ALLOWED_SIGNUP_DOMAIN"]
    ENV["ALLOWED_SIGNUP_DOMAIN"] = "allowed.com"

    begin
      untenanted do
        assert_difference -> { Identity.count }, +1 do
          post signup_path, params: { signup: { email_address: "user@allowed.com" } }
        end

        assert_redirected_to session_magic_link_path
      end
    ensure
      ENV["ALLOWED_SIGNUP_DOMAIN"] = original_value
    end
  end

  test "create with disallowed domain" do
    original_value = ENV["ALLOWED_SIGNUP_DOMAIN"]
    ENV["ALLOWED_SIGNUP_DOMAIN"] = "allowed.com"

    begin
      untenanted do
        assert_no_difference -> { Identity.count } do
          post signup_path, params: { signup: { email_address: "user@blocked.com" } }
        end

        assert_response :unprocessable_entity
      end
    ensure
      ENV["ALLOWED_SIGNUP_DOMAIN"] = original_value
    end
  end

  test "create without domain restriction blocks all signups in production" do
    original_value = ENV["ALLOWED_SIGNUP_DOMAIN"]
    ENV.delete("ALLOWED_SIGNUP_DOMAIN")

    begin
      # Stub Rails.env.test? to return false (simulate production)
      Rails.env.stubs(:test?).returns(false)

      untenanted do
        assert_no_difference -> { Identity.count } do
          post signup_path, params: { signup: { email_address: "user@anydomain.com" } }
        end

        assert_response :unprocessable_entity
      end
    ensure
      ENV["ALLOWED_SIGNUP_DOMAIN"] = original_value
    end
  end
end
