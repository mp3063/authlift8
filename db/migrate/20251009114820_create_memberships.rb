class CreateMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true

      t.string :role, null: false, default: "member"  # owner, admin, member
      t.jsonb :scopes, default: []                    # Permission scopes
      t.jsonb :info, default: {}                      # Additional metadata
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :memberships, [ :user_id, :company_id ], unique: true
    add_index :memberships, :scopes, using: :gin
    add_index :memberships, :info, using: :gin
  end
end
