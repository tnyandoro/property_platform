module Api
  module V1
    class MaintenanceRequestsController < PropertyResourcesController
      include MaintenanceSerialization
      include DocumentSerialization
      include PropertyManagerAuthorization

      before_action :set_request, only: %i[show update acknowledge submit_for_approval approve reject schedule start complete close cancel dispute_responsibility allocate_costs add_financial_entry]

      def index
        return head :forbidden unless MaintenanceRequestPolicy.new(current_user, property).index?

        requests = property.maintenance_requests.includes(:cost_allocations, :financial_entries, :documents)
          .order(reported_at: :desc, created_at: :desc)
        if params[:status].present?
          statuses = params[:status].split(",")
          return render json: { error: "Invalid status filter." }, status: :bad_request unless (statuses - MaintenanceRequest::STATUSES).empty?

          requests = requests.where(status: statuses)
        end
        requests = requests.where(priority: params[:priority]) if params[:priority].present?
        return render json: { error: "Invalid priority filter." }, status: :bad_request if params[:priority].present? && !MaintenanceRequest::PRIORITIES.include?(params[:priority])
        requests = requests.where(category: params[:category]) if params[:category].present?
        return render json: { error: "Invalid filter." }, status: :bad_request if params[:filter].present? && params[:filter] != "overdue"
        requests = requests.overdue if params[:filter] == "overdue"
        requests = requests.where("scheduled_on >= ?", Date.iso8601(params[:from])) if params[:from].present?
        requests = requests.where("scheduled_on <= ?", Date.iso8601(params[:to])) if params[:to].present?
        render json: requests.map { |request| maintenance_request_payload(request) }
      rescue ArgumentError
        render json: { error: "Invalid date or filter value." }, status: :bad_request
      end

      def show
        return head :forbidden unless MaintenanceRequestPolicy.new(current_user, @request).show?

        render json: maintenance_request_payload(@request)
      end

      def create
        return unless authorize_active_property_manager

        request = property.maintenance_requests.new(
          maintenance_request_params.except(:unit_id, :room_id, :lease_id, :contractor_id, :source_inspection_id, :source_inspection_item_id, :source_damage_assessment_id)
            .merge(organization: current_organization, reported_by: current_user)
        )
        assign_associations(request)
        if request.save
          render json: maintenance_request_payload(request), status: :created
        else
          render json: { errors: request.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "A linked record was not found for this property." }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotUnique
        render json: { error: "A work order already exists for that inspection finding or damage assessment." }, status: :unprocessable_entity
      end

      def update
        return unless authorize_active_property_manager

        @request.assign_attributes(
          maintenance_request_params.except(:unit_id, :room_id, :lease_id, :contractor_id, :source_inspection_id, :source_inspection_item_id, :source_damage_assessment_id)
        )
        assign_associations(@request)
        if @request.save
          render json: maintenance_request_payload(@request)
        else
          render json: { errors: @request.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "A linked record was not found for this property." }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotUnique
        render json: { error: "A work order already exists for that inspection finding or damage assessment." }, status: :unprocessable_entity
      end

      def acknowledge
        transition!("open", "acknowledged", acknowledged_at: Time.current)
      end

      def submit_for_approval
        transition!(%w[open acknowledged], "awaiting_approval")
      end

      def approve
        return unless authorize_active_property_manager
        return invalid_transition unless @request.status == "awaiting_approval"

        approved_cost = decimal_amount(params.require(:approved_cost))
        return render json: { error: "approved_cost must be a non-negative amount." }, status: :unprocessable_entity unless approved_cost&.finite? && approved_cost >= 0

        if @request.update(
          status: "approved",
          approved_cost: approved_cost,
          approval_notes: params[:comments],
          approved_by: current_user,
          approved_at: Time.current
        )
          render json: maintenance_request_payload(@request)
        else
          render json: { errors: @request.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActionController::ParameterMissing
        render json: { error: "approved_cost is required." }, status: :bad_request
      end

      def reject
        return unless authorize_active_property_manager
        return invalid_transition unless @request.status == "awaiting_approval"

        @request.update!(status: "rejected", rejection_reason: params.require(:reason))
        render json: maintenance_request_payload(@request)
      rescue ActionController::ParameterMissing
        render json: { error: "reason is required." }, status: :bad_request
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      def schedule
        return unless authorize_active_property_manager
        return invalid_transition unless %w[approved acknowledged open].include?(@request.status)

        if @request.update(scheduled_on: params.require(:scheduled_on), target_completion_on: params[:target_completion_on], status: "scheduled")
          render json: maintenance_request_payload(@request)
        else
          render json: { errors: @request.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActionController::ParameterMissing
        render json: { error: "scheduled_on is required." }, status: :bad_request
      end

      def start
        transition!(%w[scheduled approved acknowledged], "in_progress", actual_started_at: Time.current)
      end

      def complete
        return unless authorize_active_property_manager
        return invalid_transition unless @request.status == "in_progress"

        if @request.update(complete_params.merge(status: "resolved", resolved_at: Time.current))
          render json: maintenance_request_payload(@request)
        else
          render json: { errors: @request.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def close
        transition!("resolved", "closed", closed_at: Time.current, closed_by: current_user)
      end

      def cancel
        return unless authorize_active_property_manager
        return invalid_transition if %w[closed cancelled].include?(@request.status)

        if @request.update(status: "cancelled", cancellation_reason: params.require(:reason))
          render json: maintenance_request_payload(@request)
        else
          render json: { errors: @request.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActionController::ParameterMissing
        render json: { error: "reason is required." }, status: :bad_request
      end

      def dispute_responsibility
        return unless authorize_active_property_manager

        rationale = params.require(:rationale)
        if @request.update(
          responsibility_status: "disputed",
          responsibility_notes: rationale,
          responsibility_reviewed_by: current_user,
          responsibility_reviewed_at: Time.current
        )
          render json: maintenance_request_payload(@request)
        else
          render json: { errors: @request.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActionController::ParameterMissing
        render json: { error: "rationale is required." }, status: :bad_request
      end

      def allocate_costs
        return unless authorize_active_property_manager
        return render json: { error: "Cost responsibility is already approved. Dispute it before recording a revised allocation." }, status: :unprocessable_entity if @request.responsibility_status == "approved"
        return render json: { error: "An approved cost is required before allocating responsibility." }, status: :unprocessable_entity if @request.approved_cost.blank?

        allocations = params.require(:allocations)
        unless allocations.is_a?(Array) && allocations.all? { |allocation| allocation.is_a?(Hash) || allocation.is_a?(ActionController::Parameters) }
          return render json: { error: "Allocations must be a list of allocation records." }, status: :unprocessable_entity
        end
        return render json: { error: "At least one allocation is required." }, status: :unprocessable_entity if allocations.empty?
        if allocations.any? { |allocation| (allocation[:currency].presence || @request.currency) != @request.currency }
          return render json: { error: "Allocation currencies must match the work order currency." }, status: :unprocessable_entity
        end

        amounts = allocations.map { |allocation| decimal_amount(allocation[:allocated_amount]) }
        unless amounts.all? { |amount| amount&.finite? && amount >= 0 }
          return render json: { error: "Allocation amounts must be valid non-negative amounts." }, status: :unprocessable_entity
        end

        @request.with_lock do
          total = amounts.sum
          unless total == @request.approved_cost
            return render json: { error: "Allocations must equal the approved cost." }, status: :unprocessable_entity
          end
          @request.cost_allocations.where(status: "approved").each { |allocation| allocation.update!(status: "superseded") } if @request.responsibility_status == "disputed"
          allocations.each do |attributes|
            party = current_organization.parties.find(attributes[:party_id]) if attributes[:party_id].present?
            @request.cost_allocations.create!(
              organization: current_organization,
              responsible_party: attributes.fetch(:responsible_party),
              allocated_amount: attributes.fetch(:allocated_amount),
              currency: attributes[:currency].presence || @request.currency,
              rationale: params.require(:rationale),
              party: party,
              approved_by: current_user
            )
          end
          @request.update!(
            responsibility_status: "approved",
            responsibility_notes: params.require(:rationale),
            responsibility_reviewed_by: current_user,
            responsibility_reviewed_at: Time.current
          )
        end
        render json: maintenance_request_payload(@request)
      rescue ActionController::ParameterMissing, KeyError => error
        render json: { error: "#{error.message} is required." }, status: :bad_request
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Party not found in this organization." }, status: :unprocessable_entity
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      def add_financial_entry
        return unless authorize_active_property_manager

        attributes = financial_entry_params
        entry = @request.financial_entries.new(
          attributes.merge(
            organization: current_organization,
            recorded_by: current_user,
            currency: attributes[:currency].presence || @request.currency
          )
        )
        entry.party = current_organization.parties.find(attributes[:party_id]) if attributes[:party_id].present?
        if entry.save
          render json: financial_entry_payload(entry), status: :created
        else
          render json: { errors: entry.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Party not found in this organization." }, status: :unprocessable_entity
      end

      private

      def set_request
        @request = property.maintenance_requests.includes(:cost_allocations, :financial_entries, :documents).find(params[:maintenance_request_id])
      end

      def maintenance_request_params
        params.require(:maintenance_request).permit(
          :title, :description, :category, :priority, :classification, :source_type,
          :unit_id, :room_id, :lease_id, :contractor_id, :source_inspection_id,
          :source_inspection_item_id, :source_damage_assessment_id, :assigned_to_id,
          :scheduled_on, :target_completion_on, :estimated_cost, :currency,
          :resolution_notes
        )
      end

      def assign_associations(request)
        values = maintenance_request_params
        request.unit = values[:unit_id].present? ? property.units.find(values[:unit_id]) : nil if values.key?(:unit_id)
        request.room = values[:room_id].present? ? property.rooms.find(values[:room_id]) : nil if values.key?(:room_id)
        request.lease = values[:lease_id].present? ? property.leases.find(values[:lease_id]) : nil if values.key?(:lease_id)
        request.unit ||= request.room.unit if request.room
        request.unit ||= request.lease.unit if request.lease
        request.contractor = values[:contractor_id].present? ? current_organization.parties.find(values[:contractor_id]) : nil if values.key?(:contractor_id)
        request.source_inspection = values[:source_inspection_id].present? ? property.inspections.find(values[:source_inspection_id]) : nil if values.key?(:source_inspection_id)
        request.source_type = "inspection" if request.source_inspection
        if values[:source_inspection_item_id].present?
          request.source_inspection_item = InspectionItem.joins(:inspection)
            .where(organization_id: current_organization.id, inspections: { property_id: property.id })
            .find(values[:source_inspection_item_id])
          request.source_inspection ||= request.source_inspection_item.inspection
          request.source_type = "inspection"
        end
        request.source_damage_assessment = values[:source_damage_assessment_id].present? ? property.damage_assessments.find(values[:source_damage_assessment_id]) : nil if values.key?(:source_damage_assessment_id)
        request.source_type = "damage_assessment" if request.source_damage_assessment
      end

      def complete_params
        params.permit(:actual_cost, :resolution_notes)
      end

      def financial_entry_params
        params.require(:financial_entry).permit(:entry_type, :amount, :currency, :occurred_on, :reference, :notes, :party_id)
      end

      def decimal_amount(value)
        BigDecimal(value.to_s, exception: false)
      end

      def transition!(from, to, attributes = {})
        return unless authorize_active_property_manager
        return invalid_transition unless Array(from).include?(@request.status)

        if @request.update(attributes.merge(status: to))
          render json: maintenance_request_payload(@request)
        else
          render json: { errors: @request.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def invalid_transition
        render json: { error: "This status transition is not allowed." }, status: :unprocessable_entity
      end
    end
  end
end
