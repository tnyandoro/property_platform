module Api
  module V1
    module Tenant
      class InvitationsController < ApplicationController
        skip_before_action :authenticate_user!
        skip_before_action :require_management_workspace!

        def show
          invitation = invitation_for_token
          return invalid_invitation unless invitation

          if invitation.expires_at <= Time.current
            invitation.update!(status: "expired", expired_at: Time.current)
            return render json: { error: "This invitation has expired" }, status: :gone
          end

          return invalid_invitation unless invitation.valid_for_activation?

          render json: {
            email: invitation.target_email,
            organisation: invitation.organization.name,
            property: invitation.property.name,
            lease_start_date: invitation.lease.start_date,
            lease_end_date: invitation.lease.end_date
          }
        end

        def accept
          invitation = invitation_for_token
          return invalid_invitation unless invitation

          invitation.with_lock do
            if invitation.expires_at <= Time.current
              invitation.update!(status: "expired", expired_at: Time.current)
              return render json: { error: "This invitation has expired" }, status: :gone
            end
            return invalid_invitation unless invitation.valid_for_activation?

            if User.where(email: invitation.target_email).exists?
              return render json: { error: "An account already exists for this email. Please contact the organisation to link your existing account." }, status: :conflict
            end

            attributes = params.require(:user)
            user = nil

            ActiveRecord::Base.transaction do
              user = User.new(
                email: invitation.target_email,
                first_name: attributes[:first_name],
                last_name: attributes[:last_name],
                password: attributes[:password],
                password_confirmation: attributes[:password_confirmation],
                email_verified_at: Time.current
              )
              user.skip_initial_organization_membership = true
              user.save!

              party_account = PartyAccount.create!(
                organization: invitation.organization,
                party: invitation.tenant_party,
                user: user,
                status: "verified",
                verified_by: invitation.invited_by,
                verified_at: Time.current
              )

              TenantProfile.create!(
                organization: invitation.organization,
                party_account: party_account
              )

              invitation.update!(
                status: "accepted",
                accepted_user: user,
                accepted_at: Time.current
              )
            end

            render json: {
              message: "Your tenant account has been activated. You can now sign in.",
              email: user.email
            }, status: :created
          end
        rescue ActiveRecord::RecordInvalid => error
          render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
        rescue ActionController::ParameterMissing => error
          render json: { error: error.message }, status: :unprocessable_entity
        end

        private

        def invitation_for_token
          token = params[:token].to_s
          return if token.blank? || token.length > 256

          TenantInvitation.find_by(token_digest: Digest::SHA256.hexdigest(token))
        end

        def invalid_invitation
          render json: { error: "This invitation is invalid or is no longer available" }, status: :not_found
        end
      end
    end
  end
end
