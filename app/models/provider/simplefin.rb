class Provider::Simplefin < Provider
  Error = Class.new(Provider::Error)

  # Exchange a setup token for an access URL with embedded credentials
  def claim_setup_token(setup_token)
    with_provider_response do
      claim_url = Base64.decode64(setup_token).strip
      response = Faraday.post(claim_url)

      raise Error, "Failed to claim setup token: #{response.status}" unless response.success?

      response.body.strip # This is the access URL with embedded Basic Auth
    end
  end

  # Fetch all accounts and transactions from SimpleFIN
  def fetch_accounts(access_url, start_date: nil)
    with_provider_response do
      # Access URL is like: https://user:pass@beta-bridge.simplefin.org/simplefin
      # Parse out credentials and build a clean URL with explicit Basic Auth
      uri = URI.parse(access_url.chomp("/"))
      username = uri.user
      password = uri.password

      # Build URL without credentials
      uri.user = nil
      uri.password = nil
      accounts_url = "#{uri}/accounts"

      params = {}
      params["start-date"] = start_date.to_time.to_i if start_date

      conn = Faraday.new do |f|
        f.request :authorization, :basic, username, password
        f.adapter Faraday.default_adapter
      end

      response = conn.get(accounts_url, params)

      raise Error, "SimpleFIN API error: #{response.status}" unless response.success?

      JSON.parse(response.body)
    end
  end
end
