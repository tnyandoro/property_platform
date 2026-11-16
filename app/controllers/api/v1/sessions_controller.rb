module Api
  module V1
    class SessionsController < ApplicationController
      skip_before_action :authenticate_user!, only: :create

      def create
        workspace = params[:workspace].presence || "management"
        return invalid_login unless %w[management tenant].include?(workspace)

        user = matching_user
        return invalid_login unless user&.authenticate(params[:password].to_s)
        return invalid_login if workspace == "tenant" && !tenant_account?(user)

        render json: {
          token: issue_token(user),
          user: user_payload(user, workspace)
        }, status: :created
      end

      def destroy
        head :no_content
      end

      private

      def matching_user
        users = User.where(email: params[:email].to_s.strip.downcase)
        organization_id = params[:organization_id].to_s
        if organization_id.present?
          return unless organization_id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)

          users = users.where(organization_id: organization_id)
        end
        matches = users.limit(2).to_a
        matches.one? ? matches.first : nil
      end

      def tenant_account?(user)
        return false unless user.email_verified_at.present?

        TenantProfile.joins(:party_account).where(
          organization_id: user.organization_id,
          party_accounts: {
            organization_id: user.organization_id,
            user_id: user.id,
            status: "verified"
          }
        ).exists?
      end

      def invalid_login
        render json: { error: "Invalid email, password, or organization" }, status: :unauthorized
      end

      def user_payload(user, workspace)
        {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          organization_id: user.organization_id,
          workspace: workspace
        }
      end
    end
  end
end
