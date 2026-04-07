class Session < ApplicationRecord
  belongs_to :user
  before_create do
    self.user_agent = Current.user_agent
    self.ip_address = Current.ip_address
  end

  def get_preferred_tab(tab_key)
    data.dig("tab_preferences", tab_key)
  end

  def set_preferred_tab(tab_key, tab_value)
    data["tab_preferences"] ||= {}
    data["tab_preferences"][tab_key] = tab_value
    save!
  end
end
