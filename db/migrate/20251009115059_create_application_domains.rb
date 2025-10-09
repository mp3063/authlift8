class CreateApplicationDomains < ActiveRecord::Migration[8.0]
  def change
    create_table :application_domains do |t|
      t.references :oauth_application, null: false,
                   foreign_key: { to_table: :oauth_applications }
      t.references :company, null: false, foreign_key: true
      t.string :domain, null: false

      t.timestamps
    end

    add_index :application_domains, [:oauth_application_id, :domain],
              unique: true, name: 'index_app_domains_unique'
  end
end
