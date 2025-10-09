class AddCompanyToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :company, foreign_key: true
  end
end
