class CreatePartnershipApps < ActiveRecord::Migration[8.0]
  def change
    create_table :partnership_apps do |t|
      t.references :oauth_application, null: false,
                   foreign_key: { to_table: :oauth_applications }
      t.references :partnership, null: false, foreign_key: true
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :partnership_apps, [:partnership_id, :oauth_application_id],
              unique: true, name: 'idx_partnership_apps_unique'
  end
end
