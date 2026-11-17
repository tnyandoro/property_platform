class Current < ActiveSupport::CurrentAttributes
  attribute :user, :organization, :membership, :workspace
end
