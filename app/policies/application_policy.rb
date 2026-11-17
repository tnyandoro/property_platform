class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = false
  def show? = false
  def create? = false
  def update? = false
  def destroy? = false

  protected

  def organization_id
    Current.organization&.id || user&.organization_id
  end

  def organization_administrator?
    if Current.workspace.present?
      Current.membership&.administrator? || false
    else
      user&.organization_role == "administrator"
    end
  end

  def same_organization?
    return false if Current.workspace.present? && Current.workspace != "management"

    record.respond_to?(:organization_id) &&
      record.organization_id == organization_id
  end
end
