class CreateSimplefinTables < ActiveRecord::Migration[7.2]
  def change
    create_table :simplefin_items, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :access_url, null: false
      t.string :name
      t.string :status, default: "good"
      t.datetime :last_synced_at

      t.timestamps
    end

    create_table :simplefin_accounts, id: :uuid do |t|
      t.references :simplefin_item, null: false, foreign_key: true, type: :uuid
      t.string :simplefin_id, null: false
      t.string :name
      t.string :currency, default: "USD"
      t.decimal :current_balance, precision: 19, scale: 4
      t.decimal :available_balance, precision: 19, scale: 4
      t.jsonb :raw_payload

      t.timestamps
    end

    add_index :simplefin_accounts, :simplefin_id, unique: true

    add_reference :accounts, :simplefin_account, type: :uuid, foreign_key: true, null: true

    add_column :entries, :simplefin_id, :string
    add_index :entries, :simplefin_id
  end
end
