module Api
  module V1
    module Tenant
      class MaintenanceRequestsController < Api::V1::ApplicationController
        skip_before_action :require_management_workspace!
        before_action :require_tenant_workspace!
        before_action :set_tenant_profile
        before_action :set_maintenance_request, only: :show

        TENANT_STATUSES = {
          "open" => "submitted",
          "acknowledged" => "under_review",
          "awaiting_approval" => "under_review",
          "approved" => "under_review",
          "scheduled" => "scheduled",
          "in_progress" => "in_progress",
          "resolved" => "completed",
          "closed" => "completed",
          "rejected" => "closed",
          "disputed" => "under_review",
          "cancelled" => "closed"
        }.freeze

        FORBIDDEN_SUBMISSION_KEYS = %w[
          organization_id property_id unit_id room_id reported_by_id reported_by
          status source_type classification suggested_responsibility responsibility_status
          lease tenant assigned_to_id contractor_id estimated_cost approved_cost actual_cost
          currency approved_at approved_by_id responsibility_reviewed_at
          responsibility_reviewed_by_id scheduled_on target_completion_on
          approval_notes responsibility_notes resolution_notes rejection_reason
          cancellation_reason cost_allocations financial_entries
        ].freeze

        def index
          requests = tenant_requests
          render json: requests.map { |request| maintenance_request_payload(request) }
        end

        def show
          render json: maintenance_request_payload(@maintenance_request)
        end

        def create
          attributes = submission_params
          forbidden_keys = FORBIDDEN_SUBMISSION_KEYS & submitted_parameter_keys
          if forbidden_keys.any?
            return render json: {
              error: "Tenant submissions cannot set: #{forbidden_keys.join(', ')}."
            }, status: :unprocessable_entity
          end

          if attributes[:lease_id].blank?
            return render json: { error: "lease_id is required." }, status: :unprocessable_entity
          end

          if attributes[:description].blank?
            return render json: { error: "description is required." }, status: :unprocessable_entity
          end

          if attributes[:description].length > 10_000
            return render json: { error: "description must be 10,000 characters or fewer." }, status: :unprocessable_entity
          end

          lease = eligible_leases.find_by(id: attributes[:lease_id])
          return render_not_found unless lease

          request = MaintenanceRequest.create!(
            organization: current_organization,
            property: lease.property,
            unit: lease.unit,
            lease: lease,
            reported_by: current_user,
            title: attributes[:description].squish.truncate(120),
            description: attributes[:description],
            category: attributes[:category].presence,
            priority: attributes[:priority].presence || "medium",
            status: "open",
            source_type: "tenant_request",
            classification: "undetermined",
            suggested_responsibility: "unknown",
            responsibility_status: "pending_review",
            reported_at: Time.current
          )

          render json: maintenance_request_payload(request), status: :created
        rescue ActiveRecord::RecordInvalid => error
          render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
        end

        private

        def set_tenant_profile
          @tenant_profile = TenantProfile.joins(:party_account)
            .where(
              organization_id: current_organization.id,
              party_accounts: {
                organization_id: current_organization.id,
                user_id: current_user.id,
                status: "verified"
              }
            )
            .first
          render_not_found unless @tenant_profile
        end

        def eligible_leases
          Lease.joins(:property, :unit)
            .includes(:property, :unit)
            .where(
              organization_id: current_organization.id,
              tenant_id: @tenant_profile.party_id,
              status: "active",
              properties: { organization_id: current_organization.id },
              units: { organization_id: current_organization.id }
            )
            .where("properties.id = leases.property_id AND units.property_id = leases.property_id")
            .where("start_date <= ? AND (end_date IS NULL OR end_date >= ?)", Date.current, Date.current)
        end

        def tenant_requests
          return MaintenanceRequest.none unless @tenant_profile

          MaintenanceRequest.includes(:updates)
            .where(
              organization_id: current_organization.id,
              lease_id: eligible_leases.select(:id),
              reported_by_id: current_user.id,
              source_type: "tenant_request"
            )
            .order(reported_at: :desc, created_at: :desc)
        end

        def set_maintenance_request
          @maintenance_request = tenant_requests.find(params[:maintenance_request_id])
        end

        def submission_params
          params.require(:maintenance_request).permit(:lease_id, :description, :category, :priority)
        end

        def submitted_parameter_keys
          nested = params[:maintenance_request]
          keys = nested.respond_to?(:keys) ? nested.keys.map(&:to_s) : []
          keys + FORBIDDEN_SUBMISSION_KEYS.select { |key| params.key?(key) }
        end

        def maintenance_request_payload(request)
          {
            id: request.id,
            lease_id: request.lease_id,
            title: request.title,
            description: request.description,
            category: request.category,
            priority: request.priority,
            status: TENANT_STATUSES.fetch(request.status, "under_review"),
            submitted_at: request.reported_at,
            updates: request.updates.select { |update| update.status == "published" }
              .sort_by(&:published_at).reverse.map do |update|
                {
                  id: update.id,
                  update_type: update.update_type,
                  body: update.body,
                  published_at: update.published_at,
                  scheduled_start_at: update.scheduled_start_at,
                  scheduled_end_at: update.scheduled_end_at
                }
              end
          }
        end
      end
    end
  end
end
