class RemoveSaasInfrastructure < ActiveRecord::Migration[7.2]
  def up
    # Remove foreign keys first
    remove_foreign_key :sessions, :impersonation_sessions, column: :active_impersonator_session_id, if_exists: true
    remove_foreign_key :impersonation_session_logs, :impersonation_sessions, if_exists: true
    remove_foreign_key :impersonation_sessions, :users, column: :impersonated_id, if_exists: true
    remove_foreign_key :impersonation_sessions, :users, column: :impersonator_id, if_exists: true
    remove_foreign_key :oauth_access_grants, :oauth_applications, column: :application_id, if_exists: true
    remove_foreign_key :oauth_access_tokens, :oauth_applications, column: :application_id, if_exists: true

    # Drop tables
    drop_table :subscriptions, if_exists: true
    drop_table :oauth_access_grants, if_exists: true
    drop_table :oauth_access_tokens, if_exists: true
    drop_table :oauth_applications, if_exists: true
    drop_table :api_keys, if_exists: true
    drop_table :invite_codes, if_exists: true
    drop_table :invitations, if_exists: true
    drop_table :impersonation_session_logs, if_exists: true
    drop_table :impersonation_sessions, if_exists: true
    drop_table :mobile_devices, if_exists: true

    # Remove columns from families
    remove_column :families, :stripe_customer_id, if_exists: true

    # Remove columns from sessions
    remove_column :sessions, :active_impersonator_session_id, if_exists: true
    remove_column :sessions, :subscribed_at, if_exists: true

    # Remove MFA columns from users
    remove_column :users, :otp_secret, if_exists: true
    remove_column :users, :otp_required, if_exists: true
    remove_column :users, :otp_backup_codes, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
