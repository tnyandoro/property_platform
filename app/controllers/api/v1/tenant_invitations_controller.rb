module Api
  module V1
    class TenantInvitationsController < ApplicationController
      before_action :require_management_workspace!

      def create
        attributes = params.require(:tenant_invitation)
        lease = Lease.where(organization_id: current_organization.id).find_by(id: attributes[:lease_id])
        return render json: { error: "Eligible lease not found" }, status: :not_found unless eligible_lease?(lease)

        property = lease.property
        unless current_user.authorized_for_property?(property, "invite_tenants")
          return render json: { error: "You are not authorised to invite tenants for this property" }, status: :forbidden
        end

        email = attributes[:email].to_s.strip.downcase
        unless URI::MailTo::EMAIL_REGEXP.match?(email)
          return render json: { error: "A valid tenant email address is required" }, status: :unprocessable_entity
        end

        if User.where(email: email).exists?
          return render json: { error: "An account already exists for this email. Contact the organisation to link the existing account." }, status: :conflict
        end

        if TenantInvitation.pending.where(
          organization_id: current_organization.id,
          lease_id: lease.id,
          target_email: email
        ).exists?
          return render json: { error: "A pending invitation already exists for this lease and email" }, status: :conflict
        end

        if Rails.env.production? && !ENV["RESEND_API_KEY"].present?
          return render json: { error: "Email delivery is not configured. Please contact the platform administrator." }, status: :service_unavailable
        end

        raw_token = SecureRandom.urlsafe_base64(32)
        invitation = TenantInvitation.new(
          organization: current_organization,
          tenant_party: Party.find(lease.tenant_id),
          property: property,
          lease: lease,
          invited_by: current_user,
          target_email: email,
          token_digest: Digest::SHA256.hexdigest(raw_token),
          status: "pending",
          expires_at: 7.days.from_now
        )

        invitation.save!
        TenantInvitationMailer.invitation(invitation, raw_token).deliver_now

        render json: {
          id: invitation.id,
          email: invitation.target_email,
          status: invitation.status,
          expires_at: invitation.expires_at
        }, status: :created
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      rescue StandardError => error
        if invitation&.persisted? && invitation.status == "pending"
          invitation.update(status: "revoked", revoked_by: current_user, revoked_at: Time.current)
        end
        Rails.logger.error("Tenant invitation delivery failed: #{error.class}: #{error.message}")
        render json: { error: "The invitation could not be delivered. Please try again." }, status: :bad_gateway
      end

      private

      def eligible_lease?(lease)
        lease.present? &&
          lease.status == "active" &&
          lease.start_date <= Date.current &&
          (lease.end_date.nil? || lease.end_date >= Date.current) &&
          lease.property_id.present? &&
          lease.tenant_id.present?
      end
    end
  end
end
