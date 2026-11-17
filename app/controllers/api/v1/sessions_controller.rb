module Api
  module V1
    class SessionsController < ApplicationController
      skip_before_action :authenticate_user!, only: %i[create destroy]
      skip_before_action :require_management_workspace!, only: %i[create destroy]

      def create
        @workspace = params[:workspace].presence || "management"
        return invalid_login unless %w[management tenant].include?(@workspace)

        user = matching_user
        return invalid_login unless user&.authenticate(params[:password].to_s)

        render json: {
          token: issue_token(
            user,
            organization: @organization,
            workspace: @workspace,
            membership: @membership
          ),
          user: user_payload(user)
        }, status: :created
      end

      def destroy
        payload = verified_token
        token_id = token_value(payload, "token_id")
        user = User.find_by(id: token_value(payload, "user_id"))
        expires_at = token_value(payload, "expires_at").to_i

        if token_id.present? && user && expires_at > Time.current.to_i
          AccessTokenRevocation.create_or_find_by!(token_id: token_id) do |revocation|
            revocation.user = user
            revocation.expires_at = Time.zone.at(expires_at)
          end
          AccessTokenRevocation.where("expires_at <= ?", Time.current).delete_all
        end

        head :no_content
      end

      private

      def matching_user
        users = User.where(email: params[:email].to_s.strip.downcase)
        organization_id = params[:organization_id].to_s
        if organization_id.present? && !organization_id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
          return
        end

        if @workspace == "management"
          if organization_id.present?
            users = users.joins(:organization_memberships).where(
              organization_memberships: {
                organization_id: organization_id,
                status: "active"
              }
            ).distinct
          end

          matches = users.limit(2).to_a
          return unless matches.one?

          user = matches.first
          @membership = resolve_management_membership(user, organization_id.presence, nil)
          @organization = @membership&.organization
          user if @membership
        elsif @workspace == "tenant"
          if organization_id.present?
            users = users.joins(party_accounts: :tenant_profile).where(
              party_accounts: {
                organization_id: organization_id,
                status: "verified"
              },
              tenant_profiles: { organization_id: organization_id }
            ).distinct
          end

          matches = users.limit(2).to_a
          return unless matches.one?

          user = matches.first
          @organization = resolve_tenant_organization(user, organization_id.presence)
          user if @organization && tenant_account?(user, @organization)
        end
      end

      def user_payload(user)
        {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          organization_id: @organization.id,
          workspace: @workspace,
          membership_id: @membership&.id,
          membership_role: @membership&.role
        }
      end

      def invalid_login
        render json: { error: "Invalid email, password, or organization" }, status: :unauthorized
      end
    end
  end
end
