module Api
  module V1
    class OrganizationMembershipsController < ApplicationController
      before_action :require_organization_administrator!
      before_action :set_membership, only: %i[update destroy]

      def index
        memberships = current_organization.organization_memberships
          .includes(:user)
          .order(:created_at)

        render json: { memberships: memberships.map { |membership| serialize(membership) } }
      end

      def create
        user = find_user
        return if performed?

        role = params.dig(:membership, :role).presence || "member"
        membership = current_organization.organization_memberships.find_by(user_id: user.id)

        if membership&.active?
          return render json: { error: "User is already an active member" }, status: :conflict
        end

        if membership
          saved = membership.update(role: role, status: "active")
          status = :ok
        else
          membership = current_organization.organization_memberships.new(
            user: user,
            role: role,
            status: "active"
          )
          saved = membership.save
          status = :created
        end

        if saved
          render json: { membership: serialize(membership) }, status: status
        else
          render json: { errors: membership.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        membership_params = params.require(:membership)
        next_role = membership_params[:role].presence || @membership.role
        next_status = membership_params[:status].presence || @membership.status

        unless OrganizationMembership::ROLES.include?(next_role) &&
            OrganizationMembership::STATUSES.include?(next_status)
          return render json: { error: "Invalid membership role or status" }, status: :unprocessable_entity
        end

        if removing_last_administrator?(@membership, next_role, next_status)
          return last_administrator_response
        end

        @membership.role = next_role
        @membership.status = next_status
        if @membership.save
          render json: { membership: serialize(@membership) }
        else
          render json: { errors: @membership.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        if removing_last_administrator?(@membership, @membership.role, "revoked")
          return last_administrator_response
        end

        if @membership.update(status: "revoked")
          render json: { membership: serialize(@membership) }
        else
          render json: { errors: @membership.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def require_organization_administrator!
        return if Current.membership&.administrator? || current_user.platform_administrator?

        render json: { error: "Organization administrator access required" }, status: :forbidden
      end

      def set_membership
        @membership = current_organization.organization_memberships.find_by(id: params[:id])
        return if @membership

        render json: { error: "Membership not found" }, status: :not_found
      end

      def find_user
        membership_params = params.require(:membership)
        if membership_params[:user_id].present?
          user = User.find_by(id: membership_params[:user_id])
          return user if user

          render json: { error: "User not found" }, status: :not_found
        elsif membership_params[:email].present?
          users = User.where(email: membership_params[:email].to_s.strip.downcase).limit(2).to_a
          return users.first if users.one?

          if users.many?
            render json: { error: "Email matches multiple user identities; provide user_id" }, status: :conflict
          else
            render json: { error: "User not found" }, status: :not_found
          end
        else
          render json: { error: "Provide user_id or email" }, status: :bad_request
        end
      end

      def removing_last_administrator?(membership, next_role, next_status)
        return false unless membership.active? && membership.administrator?
        return false if next_role == "administrator" && next_status == "active"

        current_organization.organization_memberships.active.where(role: "administrator").count <= 1
      end

      def last_administrator_response
        render json: { error: "The organization must retain at least one active administrator" },
               status: :unprocessable_entity
      end

      def serialize(membership)
        user = membership.user
        {
          id: membership.id,
          user: {
            id: user.id,
            email: user.email,
            first_name: user.first_name,
            last_name: user.last_name
          },
          role: membership.role,
          status: membership.status,
          created_at: membership.created_at,
          updated_at: membership.updated_at
        }
      end
    end
  end
end
