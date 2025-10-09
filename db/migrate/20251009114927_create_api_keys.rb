class CreateApiKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :api_keys do |t|
      t.references :company, null: false, foreign_key: true

      t.string :token, null: false              # Hashed token
      t.string :name                            # Friendly name
      t.jsonb :scopes, default: []              # Allowed scopes
      t.datetime :last_used_at
      t.datetime :expires_at
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :api_keys, :token, unique: true
    add_index :api_keys, :scopes, using: :gin
  end
end
