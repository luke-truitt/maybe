class SimplefinItem::SyncCompleteEvent
  attr_reader :simplefin_item

  def initialize(simplefin_item)
    @simplefin_item = simplefin_item
  end

  def broadcast
    simplefin_item.accounts.each do |account|
      account.broadcast_refresh
    end

    simplefin_item.family.broadcast_refresh
  end
end
