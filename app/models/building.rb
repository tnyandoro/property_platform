class Building < ApplicationRecord
  include TenantScoped

  belongs_to :property
  has_many :units

  validates :name, presence: true
end