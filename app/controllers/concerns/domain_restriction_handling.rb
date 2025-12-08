# frozen_string_literal: true

# Handle domain restriction errors in controllers
module DomainRestrictionHandling
  extend ActiveSupport::Concern

  included do
    rescue_from SignupDomainRestricted, with: :handle_signup_domain_restricted
  end

  private
    def handle_signup_domain_restricted(exception)
      if request.path == signup_path
        # For signup page, re-render the form with error
        @signup = Signup.new(email_address: params.dig(:signup, :email_address))
        @signup.validate
        render "signups/new", status: :unprocessable_entity
      else
        # For session/login page, redirect with alert
        redirect_to new_session_path, alert: "Sign ups are currently restricted"
      end
    end
end
