class AddVerifiedToApplicationDomains < ActiveRecord::Migration[8.0]
  def change
    add_column :application_domains, :verified, :boolean, default: false, null: false
  end
end
