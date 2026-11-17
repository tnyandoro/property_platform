module Api
  module V1
    class TenantInvitationsController < ApplicationController
      before_action :require_management_workspace!

      def index
        invitations = TenantInvitation.where(organization_id: current_organization.id)
        invitations = invitations.where(property_id: params[:property_id]) if params[:property_id].present?
        invitations = invitations.order(created_at: :desc)

        visible_invitations = invitations.filter_map do |invitation|
          next unless current_user.authorized_for_property?(invitation.property, "invite_tenants")

          expire_if_due!(invitation)
          invitation_payload(invitation)
        end

        render json: { invitations: visible_invitations }
      end

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

        return email_not_configured unless email_delivery_configured?

        raw_token = SecureRandom.urlsafe_base64(32)
        invitation = TenantInvitation.new(
          organization: current_organization,
          tenant_party: lease.tenant,
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

        render json: invitation_payload(invitation), status: :created
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      rescue StandardError => error
        revoke_after_delivery_failure(invitation) if invitation&.persisted?
        Rails.logger.error("Tenant invitation delivery failed: #{error.class}: #{error.message}")
        render json: { error: "The invitation could not be delivered. Please try again." }, status: :bad_gateway
      end

      def resend
        invitation = authorized_invitation
        return unless invitation
        return email_not_configured unless email_delivery_configured?

        raw_token = SecureRandom.urlsafe_base64(32)

        invitation.with_lock do
          expire_if_due!(invitation)
          unless invitation.status == "pending"
            return render json: { error: "Only pending invitations can be resent. Create a new invitation instead." }, status: :conflict
          end

          invitation.update!(
            token_digest: Digest::SHA256.hexdigest(raw_token),
            expires_at: 7.days.from_now
          )
          TenantInvitationMailer.invitation(invitation, raw_token).deliver_now
        end

        render json: invitation_payload(invitation)
      rescue StandardError => error
        revoke_after_delivery_failure(invitation) if invitation&.persisted? && invitation.status == "pending"
        Rails.logger.error("Tenant invitation resend failed: #{error.class}: #{error.message}")
        render json: { error: "The invitation could not be resent. Please create a new invitation." }, status: :bad_gateway
      end

      def revoke
        invitation = authorized_invitation
        return unless invitation

        invitation.with_lock do
          expire_if_due!(invitation)
          unless invitation.status == "pending"
            return render json: { error: "Only pending invitations can be revoked." }, status: :conflict
          end

          invitation.update!(
            status: "revoked",
            revoked_by: current_user,
            revoked_at: Time.current
          )
        end

        render json: invitation_payload(invitation)
      end

      private

      def authorized_invitation
        invitation = TenantInvitation.where(organization_id: current_organization.id).find_by(id: params[:id])
        return render(json: { error: "Invitation not found" }, status: :not_found) unless invitation

        unless current_user.authorized_for_property?(invitation.property, "invite_tenants")
          render json: { error: "You are not authorised to manage this invitation" }, status: :forbidden
          return
        end

        invitation
      end

      def expire_if_due!(invitation)
        return unless invitation.status == "pending" && invitation.expires_at <= Time.current

        invitation.update!(
          status: "expired",
          expired_at: Time.current
        )
      end

      def invitation_payload(invitation)
        {
          id: invitation.id,
          lease_id: invitation.lease_id,
          property_id: invitation.property_id,
          email: invitation.target_email,
          status: invitation.status,
          created_at: invitation.created_at,
          expires_at: invitation.expires_at
        }
      end

      def email_delivery_configured?
        !Rails.env.production? || ENV["RESEND_API_KEY"].present?
      end

      def email_not_configured
        render json: { error: "Email delivery is not configured. Please contact the platform administrator." },
          status: :service_unavailable
      end

      def revoke_after_delivery_failure(invitation)
        return unless invitation.status == "pending"

        invitation.update(
          status: "revoked",
          revoked_by: current_user,
          revoked_at: Time.current
        )
      end

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
