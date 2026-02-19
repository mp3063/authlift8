class AddIndexToOauthAccessTokensRevokedAt < ActiveRecord::Migration[8.0]
  def change
    add_index :oauth_access_tokens, :revoked_at,
              name: "index_oauth_access_tokens_on_revoked_at"
  end
end
