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
    return authentication_required unless payload
    return authentication_required if token_revoked?(payload)

    user_id = token_value(payload, "user_id")
    user = User.find_by(id: user_id)
    return authentication_required unless user

    workspace = token_value(payload, "workspace").presence || "management"
    organization_id = token_value(payload, "organization_id")

    case workspace
    when "management"
      membership = resolve_management_membership(
        user,
        organization_id,
        token_value(payload, "membership_id")
      )
      return authentication_required unless membership

      Current.user = user
      Current.organization = membership.organization
      Current.membership = membership
      Current.workspace = "management"
    when "tenant"
      organization = resolve_tenant_organization(user, organization_id)
      return authentication_required unless organization && tenant_account?(user, organization)

      Current.user = user
      Current.organization = organization
      Current.membership = nil
      Current.workspace = "tenant"
    when "owner"
      organization = resolve_owner_organization(user, organization_id)
      return authentication_required unless organization && owner_account?(user, organization)

      Current.user = user
      Current.organization = organization
      Current.membership = nil
      Current.workspace = "owner"
    else
      authentication_required
    end
  end

  def issue_token(user, organization:, workspace:, membership: nil)
    expires_at = 24.hours.from_now
    payload = {
      token_id: SecureRandom.uuid,
      expires_at: expires_at.to_i,
      user_id: user.id,
      organization_id: organization.id,
      workspace: workspace
    }
    payload[:membership_id] = membership.id if membership

    Rails.application.message_verifier(:authentication).generate(
      payload,
      purpose: :access_token,
      expires_at: expires_at
    )
  end

  def require_management_workspace!
    return if Current.workspace == "management"

    render json: { error: "Management workspace required" }, status: :forbidden
  end

  def require_tenant_workspace!
    return if Current.workspace == "tenant"

    render json: { error: "Tenant workspace required" }, status: :forbidden
  end

  def require_owner_workspace!
    return if Current.workspace == "owner"

    render json: { error: "Owner workspace required" }, status: :forbidden
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

  def token_revoked?(payload)
    token_id = token_value(payload, "token_id")
    return true if token_id.blank?

    AccessTokenRevocation.active.exists?(token_id: token_id)
  end

  def token_value(payload, key)
    return unless payload

    payload[key] || payload[key.to_sym]
  end

  def resolve_management_membership(user, organization_id, membership_id)
    membership = if organization_id.present?
      user.membership_for(organization_id)
    else
      memberships = user.organization_memberships.active.order(:created_at, :id).limit(2).to_a
      memberships.one? ? memberships.first : nil
    end

    return unless membership
    return if membership_id.present? && membership.id.to_s != membership_id.to_s

    membership
  end

  def resolve_tenant_organization(user, organization_id)
    return Organization.find_by(id: organization_id) if organization_id.present?

    organization_ids = eligible_tenant_profiles(user).map(&:organization_id).uniq
    return unless organization_ids.one?

    Organization.find_by(id: organization_ids.first)
  end

  def tenant_account?(user, organization)
    return false unless user.email_verified_at.present?

    eligible_tenant_profiles(user, organization).any?
  end

  def eligible_tenant_profiles(user, organization = nil)
    profiles = TenantProfile.joins(:party_account)
      .where(
        party_accounts: {
          user_id: user.id,
          status: "verified"
        }
      )
    profiles = profiles.where(organization_id: organization.id) if organization

    profiles.select do |profile|
      Lease.where(
        organization_id: profile.organization_id,
        tenant_id: profile.party_id,
        status: "active"
      ).where(
        "start_date <= ? AND (end_date IS NULL OR end_date >= ?)",
        Date.current,
        Date.current
      ).exists?
    end
  end

  def resolve_owner_organization(user, organization_id)
    if organization_id.present?
      organization = Organization.find_by(id: organization_id)
      return organization if organization && owner_account?(user, organization)

      return
    end

    organization_ids = eligible_owner_ownerships(user).distinct.pluck("property_ownerships.organization_id")
    return unless organization_ids.one?

    Organization.find_by(id: organization_ids.first)
  end

  def owner_account?(user, organization)
    return false unless user.email_verified_at.present?

    eligible_owner_ownerships(user, organization).exists?
  end

  def eligible_owner_ownerships(user, organization = nil)
    ownerships = PropertyOwnership.joins(:party)
      .joins(
        "INNER JOIN party_accounts ON party_accounts.party_id = property_ownerships.party_id " \
        "AND party_accounts.organization_id = property_ownerships.organization_id"
      )
      .where(
        property_ownerships: { verification_status: "verified" },
        party_accounts: { user_id: user.id, status: "verified" }
      )
      .merge(PropertyOwnership.active_on(Date.current))
    ownerships = ownerships.where(property_ownerships: { organization_id: organization.id }) if organization

    ownerships
  end

  def authentication_required
    render json: { error: "Authentication required" }, status: :unauthorized
  end
end
