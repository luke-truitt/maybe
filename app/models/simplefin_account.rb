class SimplefinAccount < ApplicationRecord
  belongs_to :simplefin_item
  has_one :account, dependent: :nullify
end
