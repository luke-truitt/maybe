class SyncSimplefinItemsJob < ApplicationJob
  queue_as :scheduled

  def perform
    SimplefinItem.find_each do |item|
      item.sync_later
    end
  end
end
