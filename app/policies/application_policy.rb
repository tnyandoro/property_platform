class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user   = user
    @record = record
  end

  def index?   = false
  def show?    = false
  def create?  = false
  def update?  = false
  def destroy? = false

  protected

  # Returns true if the user belongs to the same organization as the record.
  def same_organization?
    record.respond_to?(:organization_id) &&
      record.organization_id == user.organization_id
  end
end
