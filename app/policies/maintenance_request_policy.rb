class MaintenanceRequestPolicy < ApplicationPolicy
  def index?   = same_organization?
  def show?    = same_organization?
  def create?  = same_organization?
  def update?  = same_organization?
  def destroy? = false
end
