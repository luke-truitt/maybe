class SimplefinAccount::Processor
  attr_reader :simplefin_item, :account_data

  def initialize(simplefin_item, account_data)
    @simplefin_item = simplefin_item
    @account_data = account_data
  end

  def process!
    simplefin_account = find_or_create_simplefin_account!
    account = find_or_create_account!(simplefin_account)
    process_transactions!(account)
    update_balance!(account, simplefin_account)
  end

  private

    def family
      simplefin_item.family
    end

    def find_or_create_simplefin_account!
      sfin_id = account_data.dig("id")
      name = account_data.dig("name") || "Unknown Account"
      currency = resolve_currency
      balance = account_data.dig("balance").to_d
      available = account_data.dig("available-balance")&.to_d

      simplefin_account = SimplefinAccount.find_or_initialize_by(simplefin_id: sfin_id)
      simplefin_account.assign_attributes(
        simplefin_item: simplefin_item,
        name: name,
        currency: currency,
        current_balance: balance,
        available_balance: available,
        raw_payload: account_data
      )
      simplefin_account.save!
      simplefin_account
    end

    def find_or_create_account!(simplefin_account)
      account = family.accounts.find_or_initialize_by(
        simplefin_account_id: simplefin_account.id
      )

      if account.new_record?
        accountable = infer_accountable(simplefin_account)
        balance = simplefin_account.current_balance
        # Liabilities should be stored as positive in Maybe
        balance = balance.abs if accountable.is_a?(CreditCard) || accountable.is_a?(Loan)

        account.assign_attributes(
          name: simplefin_account.name,
          accountable: accountable,
          balance: balance,
          currency: simplefin_account.currency
        )
      end

      account.save!
      account
    end

    def process_transactions!(account)
      transactions = account_data.dig("transactions") || []

      transactions.each do |txn_data|
        txn_id = txn_data.dig("id")
        next if txn_id.blank?

        # Skip if we already have this transaction
        existing = account.entries.find_by(simplefin_id: txn_id)
        next if existing.present?

        amount = txn_data.dig("amount").to_d
        date = if txn_data.dig("posted")
          Time.at(txn_data.dig("posted")).to_date
        else
          Date.current
        end
        description = txn_data.dig("description") || txn_data.dig("payee") || "Unknown"

        # SimpleFIN: positive = money in, negative = money out
        # Maybe: positive = outflow (expense), negative = inflow (income)
        entry_amount = -amount

        entry = account.entries.create!(
          name: description.truncate(255),
          date: date,
          amount: entry_amount,
          currency: account.currency,
          entryable: Transaction.new,
          simplefin_id: txn_id
        )
      end
    end

    def update_balance!(account, simplefin_account)
      balance = simplefin_account.current_balance
      # Liabilities should be stored as positive in Maybe
      balance = balance.abs if account.classification == "liability"
      account.update!(balance: balance)

      flows_factor = account.classification == "liability" ? -1 : 1

      # Create/update today's balance record for net worth calculations
      # Set start_cash_balance so the virtual end_balance column computes correctly
      account.balances.find_or_initialize_by(date: Date.current, currency: account.currency).tap do |b|
        b.balance = balance
        b.start_cash_balance = balance
        b.flows_factor = flows_factor
        b.save!
      end
    end

    def infer_accountable(simplefin_account)
      name = simplefin_account.name.downcase
      balance = simplefin_account.current_balance || 0

      if name.match?(/credit card|amex|visa|mastercard|discover|american express|\bcard\b/)
        CreditCard.new
      elsif name.match?(/ira|401k|403b|brokerage|individual(?!.*apy)/) && balance > 1000
        Investment.new
      elsif name.match?(/mortgage|home loan/)
        Loan.new
      elsif name.match?(/loan|student/)
        Loan.new
      else
        Depository.new
      end
    end

    def resolve_currency
      currency_raw = account_data.dig("currency")
      # SimpleFIN uses ISO 4217 codes or URLs — extract the code
      if currency_raw.is_a?(String) && currency_raw.length == 3
        currency_raw.upcase
      else
        "USD"
      end
    end
end
