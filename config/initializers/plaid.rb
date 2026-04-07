# Plaid disabled — using SimpleFIN instead
Rails.application.configure do
  config.plaid = nil
  config.plaid_eu = nil
end
