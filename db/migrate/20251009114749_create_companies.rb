class CreateCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :companies do |t|
      t.string :code, null: false              # Unique identifier
      t.string :name, null: false
      t.string :vat_id                         # VAT/Tax ID (was vatid in old schema)
      t.string :business_id                    # Country-specific business ID

      # Address
      t.string :address_line1
      t.string :address_line2
      t.string :city
      t.string :state
      t.string :postal_code
      t.string :country, default: "FI"

      # Contact
      t.string :email
      t.string :phone
      t.string :website

      # Branding
      t.string :logo_code                      # Logo identifier
      t.string :locale, default: "en"

      # Data (separate concerns)
      t.jsonb :info, default: {}               # Company information/metadata
      t.jsonb :settings, default: {}, null: false  # Application settings

      # Status
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :companies, :code, unique: true
    add_index :companies, :vat_id
    add_index :companies, :info, using: :gin
    add_index :companies, :settings, using: :gin
  end
end
