module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def current_user
    Current.user
  end

  def current_organization
    Current.organization
  end

  def authenticate_user!
    payload = verified_token
    user_id = payload && (payload["user_id"] || payload[:user_id])
    Current.user = User.find_by(id: user_id)
    Current.organization = Current.user&.organization

    return if Current.user

    render json: { error: "Authentication required" }, status: :unauthorized
  end

  def issue_token(user)
    Rails.application.message_verifier(:authentication).generate(
      { user_id: user.id },
      purpose: :access_token,
      expires_in: 24.hours
    )
  end

  def verified_token
    token = request.headers["Authorization"].to_s.delete_prefix("Bearer ").presence
    return if token.blank?

    Rails.application.message_verifier(:authentication).verified(
      token,
      purpose: :access_token
    )
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end
end