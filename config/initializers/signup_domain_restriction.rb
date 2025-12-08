# frozen_string_literal: true

# Restrict signups to a specific email domain
# Set ALLOWED_SIGNUP_DOMAIN environment variable to configure the allowed domain
#
# Behavior:
# - When ALLOWED_SIGNUP_DOMAIN is set: only emails from that domain can sign up
# - When ALLOWED_SIGNUP_DOMAIN is not set: all signups are blocked (secure default)
# - Existing users can always log in, regardless of domain

class SignupDomainRestricted < StandardError; end

module SignupDomainRestriction
  def self.prepended(base)
    base.class_eval do
      validates :email_address, presence: true
      validate :email_domain_allowed, if: -> { email_address.present? }
    end
  end

  def create_identity
    unless valid?
      raise SignupDomainRestricted, "Sign ups are currently restricted"
    end

    super
  end

  private
    def email_domain_allowed
      allowed_domain = ENV["ALLOWED_SIGNUP_DOMAIN"].presence

      # If no domain is configured, behavior depends on environment:
      # - Test environment: allow all domains (backward compatible)
      # - Other environments: block all signups (secure default)
      if allowed_domain.blank?
        unless Rails.env.test?
          errors.add(:email_address, "signups are not currently available")
        end
        return
      end

      # Extract domain from email address
      email_domain = email_address.to_s.split("@").last&.downcase

      # Check if email domain matches the allowed domain
      unless email_domain == allowed_domain.downcase
        errors.add(:email_address, "is not from an allowed domain")
      end
    end
end

# Prepend the module to Signup class after models are loaded
Rails.application.config.to_prepare do
  Signup.prepend(SignupDomainRestriction)
end
