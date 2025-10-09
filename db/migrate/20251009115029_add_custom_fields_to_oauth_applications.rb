class AddCustomFieldsToOauthApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :oauth_applications, :home, :string
    add_column :oauth_applications, :partnerships_allowed, :boolean, default: false
    add_column :oauth_applications, :application_icon, :string
    add_column :oauth_applications, :trusted, :boolean, default: false
  end
end
