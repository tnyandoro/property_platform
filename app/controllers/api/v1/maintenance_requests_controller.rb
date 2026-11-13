module Api
  module V1
    class MaintenanceRequestsController < PropertyResourcesController
      include MaintenanceSerialization
      include DocumentSerialization
      include PropertyManagerAuthorization

      before_action :set_request, only: %i[
        show update assign acknowledge submit_for_approval approve reject schedule start
        complete verify close cancel dispute_responsibility allocate_costs add_financial_entry
        create_quote create_invoice create_payment mark_payment_paid
      ]

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
        render json: maintenance_request_payloads(requests)
      rescue ArgumentError
        render json: { error: "Invalid date or filter value." }, status: :bad_request
      end

      def show
        return head :forbidden unless MaintenanceRequestPolicy.new(current_user, @request).show?

        render json: maintenance_request_payload(@request)
      end

      def create
        return unless authorize_request_manager

        request = MaintenanceRequestCreator.call(
          property: property,
          organization: current_organization,
          actor: current_user,
          attributes: maintenance_request_params
        )
        render json: maintenance_request_payload(request), status: :created
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotFound
        render json: { error: "A linked record was not found for this property." }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotUnique
        render json: { error: "A work order already exists for that inspection finding or damage assessment." }, status: :unprocessable_entity
      end

      def update
        return unless authorize_request_manager

        attributes = maintenance_request_params
        @request.assign_attributes(attributes.except(*MaintenanceRequestAssociationAssigner::ASSOCIATION_KEYS))
        MaintenanceRequestAssociationAssigner.call(
          request: @request,
          property: property,
          organization: current_organization,
          attributes: attributes
        )
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
        run_workflow(:acknowledge)
      end

      def submit_for_approval
        run_workflow(:submit_for_approval)
      end

      def approve
        run_workflow(:approve, approved_cost: params.require(:approved_cost), comments: params[:comments])
      rescue ActionController::ParameterMissing
        render json: { error: "approved_cost is required." }, status: :bad_request
      end

      def reject
        run_workflow(:reject, reason: params.require(:reason))
      rescue ActionController::ParameterMissing
        render json: { error: "reason is required." }, status: :bad_request
      end

      def schedule
        run_workflow(:schedule, scheduled_on: params.require(:scheduled_on), target_completion_on: params[:target_completion_on])
      rescue ActionController::ParameterMissing
        render json: { error: "scheduled_on is required." }, status: :bad_request
      end

      def start
        run_workflow(:start)
      end

      def complete
        run_workflow(:complete, complete_params.to_h)
      end

      def verify
        run_workflow(:verify)
      end

      def close
        run_workflow(:close)
      end

      def cancel
        run_workflow(:cancel, reason: params.require(:reason))
      rescue ActionController::ParameterMissing
        render json: { error: "reason is required." }, status: :bad_request
      end

      def dispute_responsibility
        run_workflow(:dispute_responsibility, rationale: params.require(:rationale))
      rescue ActionController::ParameterMissing
        render json: { error: "rationale is required." }, status: :bad_request
      end

      def assign
        run_workflow(:assign, assignment_params.to_h)
      end

      def allocate_costs
        return unless authorize_request_manager

        allocations = params.require(:allocations)
        unless allocations.is_a?(Array) && allocations.all? { |allocation| allocation.is_a?(Hash) || allocation.is_a?(ActionController::Parameters) }
          return render json: { error: "Allocations must be a list of allocation records." }, status: :unprocessable_entity
        end
        allocations = allocations.map do |allocation|
          permitted_keys = %i[
            responsible_party allocated_amount allocation_percentage currency
            party_id lease_id property_ownership_id
          ]
          if allocation.is_a?(ActionController::Parameters)
            allocation.permit(*permitted_keys)
          else
            ActionController::Parameters.new(allocation).permit(*permitted_keys)
          end
        end
        MaintenanceCostAllocator.call(
          request: @request,
          allocations: allocations,
          actor: current_user,
          rationale: params.require(:rationale)
        )
        render json: maintenance_request_payload(@request)
      rescue ActionController::ParameterMissing, KeyError => error
        render json: { error: "#{error.message} is required." }, status: :bad_request
      rescue MaintenanceCostAllocator::InvalidAllocation => error
        render json: { error: error.message }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotFound
        render json: { error: "A linked party, lease, or ownership record was not found for this property." }, status: :unprocessable_entity
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      def add_financial_entry
        return unless authorize_request_manager

        entry = MaintenanceFinancialEntryRecorder.call_legacy(
          request: @request,
          actor: current_user,
          attributes: financial_entry_params
        )
        render json: financial_entry_payload(entry), status: :created
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Party not found in this organization." }, status: :unprocessable_entity
      end

      def create_quote
        record_typed_financial_entry(
          "quotation",
          :quote,
          %i[amount currency occurred_on valid_until reference notes party_id]
        )
      end

      def create_invoice
        record_typed_financial_entry(
          "invoice",
          :invoice,
          %i[amount currency occurred_on due_on invoice_reference reference notes party_id]
        )
      end

      def create_payment
        record_typed_financial_entry(
          "payment",
          :payment,
          %i[amount currency occurred_on invoice_id reference notes party_id status]
        )
      end

      def mark_payment_paid
        return unless authorize_request_manager

        payment = @request.payments.find(params[:payment_id])
        MaintenancePaymentStatusUpdater.call(payment: payment)
        render json: financial_entry_payload(payment)
      rescue MaintenancePaymentStatusUpdater::InvalidTransition => error
        render json: { error: error.message }, status: :unprocessable_entity
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def record_typed_financial_entry(entry_type, parameter_name, permitted_keys)
        return unless authorize_request_manager

        attributes = params.require(parameter_name).permit(*permitted_keys).to_h
          .merge(entry_type: entry_type)
        entry = MaintenanceFinancialEntryRecorder.call(
          request: @request,
          actor: current_user,
          attributes: attributes
        )
        render json: financial_entry_payload(entry), status: :created
      rescue MaintenanceFinancialEntryRecorder::InvalidEntry => error
        render json: { error: error.message }, status: :unprocessable_entity
      rescue ActionController::ParameterMissing => error
        render json: { error: "#{error.param} is required." }, status: :bad_request
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotFound
        render json: { error: "A linked party or invoice was not found for this work order." }, status: :unprocessable_entity
      end

      def set_request
        @request = property.maintenance_requests.includes(:cost_allocations, :financial_entries, :documents).find(params[:maintenance_request_id])
      end

      def maintenance_request_payloads(requests)
        records = requests.to_a
        audit_logs = AuditLog.where(
          organization_id: current_organization.id,
          auditable_type: "MaintenanceRequest",
          auditable_id: records.map(&:id)
        ).order(:occurred_at).group_by(&:auditable_id)
        blobs_by_key = ActiveStorage::Blob.where(
          key: records.flat_map { |request| request.documents.map(&:storage_key) }
        ).index_by(&:key)

        records.map do |request|
          maintenance_request_payload(
            request,
            audit_logs: audit_logs.fetch(request.id, []),
            blobs_by_key: blobs_by_key
          )
        end
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

      def complete_params
        params.permit(:actual_cost, :resolution_notes)
      end

      def assignment_params
        params.require(:assignment).permit(:assigned_to_id, :contractor_id)
      end

      def financial_entry_params
        params.require(:financial_entry).permit(
          :entry_type, :amount, :currency, :occurred_on, :reference, :notes, :party_id,
          :valid_until, :due_on, :invoice_reference, :invoice_id
        )
      end

      def decimal_amount(value)
        BigDecimal(value.to_s, exception: false)
      end

      def run_workflow(action, attributes = {})
        return unless authorize_request_manager

        MaintenanceRequestWorkflow.call(
          request: @request,
          action: action,
          actor: current_user,
          attributes: attributes
        )
        render json: maintenance_request_payload(@request)
      rescue MaintenanceRequestWorkflow::InvalidTransition
        render json: { error: "This status transition is not allowed." }, status: :unprocessable_entity
      rescue MaintenanceRequestWorkflow::InvalidInput => error
        render json: { error: error.message }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotFound
        render json: { error: "A linked assignee or contractor was not found for this organization." }, status: :unprocessable_entity
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      def authorize_request_manager
        policy = MaintenanceRequestPolicy.new(current_user, @request || property)
        return true if policy.manage?

        render json: { error: "Only an active property manager can manage property records." }, status: :forbidden
        false
      end
    end
  end
end
