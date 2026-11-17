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
    return Current.organization.id if Current.organization

    record_organization_id = record.organization_id if record.respond_to?(:organization_id)
    return record_organization_id if user&.member_of?(record_organization_id)

    nil
  end

  def organization_administrator?
    if Current.workspace.present?
      Current.membership&.administrator? || false
    else
      user&.membership_for(organization_id)&.administrator? || false
    end
  end

  def same_organization?
    return false if Current.workspace.present? && Current.workspace != "management"

    record.respond_to?(:organization_id) &&
      record.organization_id == organization_id
  end
end
