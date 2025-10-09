class CreatePartnerships < ActiveRecord::Migration[8.0]
  def change
    create_table :partnerships do |t|
      # Owner = Supplier/Service Provider
      t.references :partner_owner, null: false,
                   foreign_key: { to_table: :companies }

      # Client = Customer/Buyer
      t.references :partner_client, null: false,
                   foreign_key: { to_table: :companies }

      # Data
      t.jsonb :info, default: {}
      t.jsonb :settings, default: {}

      # Flags
      t.boolean :managed_company, default: false, null: false  # Is this a managed sub-company?
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :partnerships, [:partner_owner_id, :partner_client_id],
              unique: true, name: 'index_partnerships_unique'
  end
end
