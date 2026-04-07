class SimplefinItem < ApplicationRecord
  include Syncable

  belongs_to :family
  has_many :simplefin_accounts, dependent: :destroy
  has_many :accounts, through: :simplefin_accounts

  encrypts :access_url

  enum :status, { good: "good", error: "error" }

  def destroy_later
    update!(scheduled_for_deletion: true) if respond_to?(:scheduled_for_deletion)
    destroy
  end
end
