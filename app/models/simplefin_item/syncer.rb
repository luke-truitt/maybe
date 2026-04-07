class SimplefinItem::Syncer
  attr_reader :simplefin_item

  def initialize(simplefin_item)
    @simplefin_item = simplefin_item
  end

  def perform_sync(sync)
    provider = Provider::Simplefin.new
    start_date = sync.window_start_date || 90.days.ago.to_date

    response = provider.fetch_accounts(simplefin_item.access_url, start_date: start_date)

    raise Provider::Simplefin::Error, response.error.message unless response.success?

    accounts_data = response.data.dig("accounts") || []

    accounts_data.each do |account_data|
      processor = SimplefinAccount::Processor.new(simplefin_item, account_data)
      processor.process!
    end

    simplefin_item.update!(last_synced_at: Time.current, status: :good)

    # Schedule downstream account syncs for balance history
    simplefin_item.accounts.each do |account|
      account.sync_later(
        parent_sync: sync,
        window_start_date: sync.window_start_date,
        window_end_date: sync.window_end_date
      )
    end
  end

  def perform_post_sync
    # no-op
  end
end
