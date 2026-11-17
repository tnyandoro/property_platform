module Api
  module V1
    module Tenant
      class DashboardController < Api::V1::ApplicationController
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

        def show
          profile = tenant_profile
          return render json: { error: "Tenant profile not found" }, status: :not_found unless profile

          leases = eligible_leases(profile)
          lease_ids = leases.map(&:id)
          requests = tenant_requests(profile, lease_ids)

          render json: {
            profile: profile_payload(profile),
            tenancies: leases.map { |lease| tenancy_payload(lease) },
            maintenance_requests: requests.map { |request| maintenance_request_payload(request) },
            renewal_proposals: renewal_proposal_payloads(leases),
            notifications: notification_payloads(profile, lease_ids)
          }
        end

        private

        def tenant_profile
          TenantProfile.joins(party_account: :party)
            .includes(party_account: :party)
            .find_by(
              organization_id: current_organization.id,
              party_accounts: {
                organization_id: current_organization.id,
                user_id: current_user.id,
                status: "verified"
              },
              parties: { organization_id: current_organization.id }
            )
        end

        def eligible_leases(profile)
          Lease.joins(:property, :unit)
            .includes(:property, :unit, :documents, renewal_proposals: :document)
            .where(
              organization_id: current_organization.id,
              tenant_id: profile.party_id,
              status: "active",
              properties: { organization_id: current_organization.id },
              units: { organization_id: current_organization.id }
            )
            .where("properties.id = leases.property_id AND units.property_id = leases.property_id")
            .where("start_date <= ? AND (end_date IS NULL OR end_date >= ?)", Date.current, Date.current)
            .order(:end_date, :created_at)
        end

        def tenant_requests(profile, lease_ids)
          return MaintenanceRequest.none if lease_ids.empty?

          MaintenanceRequest.includes(:updates)
            .where(
              organization_id: current_organization.id,
              lease_id: lease_ids,
              reported_by_id: profile.user_id,
              source_type: "tenant_request"
            )
            .order(reported_at: :desc)
        end

        def profile_payload(profile)
          {
            first_name: current_user.first_name,
            last_name: current_user.last_name,
            email: current_user.email,
            phone_number: profile.phone_number,
            tenant_reference: profile.tenant_reference
          }
        end

        def tenancy_payload(lease)
          property = lease.property
          unit = lease.unit
          {
            status: lease.status,
            property: {
              name: property.name,
              description: property.description,
              address: {
                line_1: property.address_line_1,
                line_2: property.address_line_2,
                suburb: property.suburb,
                city: property.city,
                province: property.province,
                postal_code: property.postal_code,
                country: property.country
              }
            },
            premises: {
              unit: {
                unit_number: unit.unit_number,
                name: unit.name,
                unit_type: unit.unit_type,
                bedrooms: unit.bedrooms,
                bathrooms: unit.bathrooms,
                floor_area: unit.floor_area
              },
              room: nil
            },
            lease: {
              id: lease.id,
              status: lease.status,
              lease_type: lease.lease_type,
              start_date: lease.start_date,
              end_date: lease.end_date,
              agreed_rent: {
                amount: lease.monthly_rent,
                currency: lease.rent_currency
              },
              deposit_amount: lease.deposit_amount,
              notice_period_days: lease.notice_period_days,
              terms_summary: lease.terms_summary,
              shared_documents: shared_lease_documents(lease)
            }
          }
        end

        def shared_lease_documents(lease)
          lease.documents.select do |document|
            document.organization_id == current_organization.id && document.visibility == "tenant_visible"
          end.map do |document|
            {
              id: document.id,
              title: document.title,
              document_type: document.document_type,
              created_at: document.created_at
            }
          end
        end

        def renewal_proposal_payloads(leases)
          leases.flat_map do |lease|
            lease.renewal_proposals.filter_map do |proposal|
              next unless proposal.organization_id == current_organization.id &&
                proposal.lease_id == lease.id &&
                %w[offered accepted rejected expired].include?(proposal.status)

              shared_document = proposal.document if proposal.document &&
                proposal.document.organization_id == current_organization.id &&
                proposal.document.lease_id == lease.id &&
                proposal.document.visibility == "tenant_visible"
              {
                id: proposal.id,
                lease_id: lease.id,
                property_name: lease.property.name,
                status: proposal.status,
                proposed_start_date: proposal.proposed_start_date,
                proposed_end_date: proposal.proposed_end_date,
                proposed_rent: {
                  amount: proposal.proposed_monthly_rent,
                  currency: proposal.rent_currency
                },
                expires_at: proposal.expires_at,
                shared_document: shared_document && {
                  id: shared_document.id,
                  title: shared_document.title,
                  document_type: shared_document.document_type
                }
              }
            end
          end
        end

        def maintenance_request_payload(request)
          {
            id: request.id,
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

        def notification_payloads(profile, lease_ids)
          return [] if lease_ids.empty?

          profile.tenant_notifications
            .where(organization_id: current_organization.id)
            .includes(
              :lease,
              { lease_renewal_proposal: :lease },
              { lease_extension_request: :lease },
              maintenance_request_update: { maintenance_request: :lease }
            )
            .order(created_at: :desc)
            .limit(50)
            .filter_map do |notification|
              update = notification.maintenance_request_update
              next if update && update.status != "published"

              lease_id = notification.lease_id ||
                notification.lease_renewal_proposal&.lease_id ||
                notification.lease_extension_request&.lease_id ||
                update&.maintenance_request&.lease_id
              next unless lease_ids.include?(lease_id)

              {
                id: notification.id,
                notification_type: notification.notification_type,
                title: notification.title,
                body: notification.body,
                created_at: notification.created_at,
                read_at: notification.read_at
              }
            end
            .first(10)
        end
      end
    end
  end
end
