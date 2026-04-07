class SimplefinItemsController < ApplicationController
  before_action :set_simplefin_item, only: %i[destroy sync]

  def new
  end

  def create
    setup_token = params[:setup_token]&.strip

    if setup_token.blank?
      redirect_to new_simplefin_item_path, alert: "Please provide a SimpleFIN setup token."
      return
    end

    provider = Provider::Simplefin.new
    response = provider.claim_setup_token(setup_token)

    unless response.success?
      redirect_to new_simplefin_item_path, alert: "Failed to connect: #{response.error.message}"
      return
    end

    access_url = response.data

    simplefin_item = Current.family.simplefin_items.create!(
      access_url: access_url,
      name: "SimpleFIN Connection"
    )

    simplefin_item.sync_later

    redirect_to accounts_path, notice: "SimpleFIN connected! Syncing your accounts now."
  end

  def destroy
    @simplefin_item.destroy
    redirect_to accounts_path, notice: "SimpleFIN connection removed."
  end

  def sync
    @simplefin_item.sync_later
    redirect_to accounts_path, notice: "Sync started."
  end

  private

    def set_simplefin_item
      @simplefin_item = Current.family.simplefin_items.find(params[:id])
    end
end
