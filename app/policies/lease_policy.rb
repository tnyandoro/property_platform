class LeasePolicy < ApplicationPolicy
  def index?   = same_organization?
  def show?    = same_organization?
  def create?  = same_organization?
  def update?  = same_organization?
  def destroy? = false   # leases are never hard-deleted; terminate via status
end
