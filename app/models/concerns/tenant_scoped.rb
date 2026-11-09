module TenantScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :organization
    validates :organization, presence: true
  end
end