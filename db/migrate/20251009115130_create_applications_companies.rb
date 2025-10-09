class CreateApplicationsCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :applications_companies, id: false do |t|
      t.references :application, null: false,
                   foreign_key: { to_table: :oauth_applications }
      t.references :company, null: false, foreign_key: true
    end

    add_index :applications_companies, [:application_id, :company_id],
              unique: true, name: 'idx_app_company'
    add_index :applications_companies, [:company_id, :application_id],
              name: 'idx_company_app'
  end
end
