class CreateCustomerGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :customer_groups do |t|
      t.references :company, null: false, foreign_key: true

      t.string :name, null: false
      t.string :group_type                      # wholesale, retail, vip, partner
      t.boolean :enabled, default: true, null: false
      t.jsonb :product_restriction_rules, default: {}
      t.jsonb :pricing_rules, default: {}

      t.timestamps
    end

    add_index :customer_groups, [:company_id, :name], unique: true
    add_index :customer_groups, :product_restriction_rules, using: :gin
  end
end
