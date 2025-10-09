# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_09_140100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_keys", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "token", null: false
    t.string "name"
    t.jsonb "scopes", default: []
    t.datetime "last_used_at"
    t.datetime "expires_at"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_api_keys_on_company_id"
    t.index ["scopes"], name: "index_api_keys_on_scopes", using: :gin
    t.index ["token"], name: "index_api_keys_on_token", unique: true
  end

  create_table "application_domains", force: :cascade do |t|
    t.bigint "oauth_application_id", null: false
    t.bigint "company_id", null: false
    t.string "domain", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_application_domains_on_company_id"
    t.index ["oauth_application_id", "domain"], name: "index_app_domains_unique", unique: true
    t.index ["oauth_application_id"], name: "index_application_domains_on_oauth_application_id"
  end

  create_table "applications_companies", id: false, force: :cascade do |t|
    t.bigint "application_id", null: false
    t.bigint "company_id", null: false
    t.index ["application_id", "company_id"], name: "idx_app_company", unique: true
    t.index ["application_id"], name: "index_applications_companies_on_application_id"
    t.index ["company_id", "application_id"], name: "idx_company_app"
    t.index ["company_id"], name: "index_applications_companies_on_company_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.string "vat_id"
    t.string "business_id"
    t.string "address_line1"
    t.string "address_line2"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "country", default: "FI"
    t.string "email"
    t.string "phone"
    t.string "website"
    t.string "logo_code"
    t.string "locale", default: "en"
    t.jsonb "info", default: {}
    t.jsonb "settings", default: {}, null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_companies_on_code", unique: true
    t.index ["info"], name: "index_companies_on_info", using: :gin
    t.index ["settings"], name: "index_companies_on_settings", using: :gin
    t.index ["vat_id"], name: "index_companies_on_vat_id"
  end

  create_table "customer_groups", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.string "group_type"
    t.boolean "enabled", default: true, null: false
    t.jsonb "product_restriction_rules", default: {}
    t.jsonb "pricing_rules", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "name"], name: "index_customer_groups_on_company_id_and_name", unique: true
    t.index ["company_id"], name: "index_customer_groups_on_company_id"
    t.index ["product_restriction_rules"], name: "index_customer_groups_on_product_restriction_rules", using: :gin
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "company_id", null: false
    t.string "role", default: "member", null: false
    t.jsonb "scopes", default: []
    t.jsonb "info", default: {}
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_memberships_on_company_id"
    t.index ["info"], name: "index_memberships_on_info", using: :gin
    t.index ["scopes"], name: "index_memberships_on_scopes", using: :gin
    t.index ["user_id", "company_id"], name: "index_memberships_on_user_id_and_company_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.bigint "resource_owner_id", null: false
    t.bigint "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.bigint "resource_owner_id"
    t.bigint "application_id", null: false
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.string "scopes"
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "previous_refresh_token", default: "", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "owner_id"
    t.string "owner_type"
    t.string "home"
    t.boolean "partnerships_allowed", default: false
    t.string "application_icon"
    t.boolean "trusted", default: false
    t.index ["owner_id", "owner_type"], name: "index_oauth_applications_on_owner_id_and_owner_type"
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "partnership_apps", force: :cascade do |t|
    t.bigint "oauth_application_id", null: false
    t.bigint "partnership_id", null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["oauth_application_id"], name: "index_partnership_apps_on_oauth_application_id"
    t.index ["partnership_id", "oauth_application_id"], name: "idx_partnership_apps_unique", unique: true
    t.index ["partnership_id"], name: "index_partnership_apps_on_partnership_id"
  end

  create_table "partnerships", force: :cascade do |t|
    t.bigint "partner_owner_id", null: false
    t.bigint "partner_client_id", null: false
    t.jsonb "info", default: {}
    t.jsonb "settings", default: {}
    t.boolean "managed_company", default: false, null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["partner_client_id"], name: "index_partnerships_on_partner_client_id"
    t.index ["partner_owner_id", "partner_client_id"], name: "index_partnerships_unique", unique: true
    t.index ["partner_owner_id"], name: "index_partnerships_on_partner_owner_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "first_name"
    t.string "last_name"
    t.string "phone"
    t.string "locale", default: "en"
    t.boolean "admin", default: false
    t.string "scopes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id"
    t.boolean "super_admin", default: false, null: false
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "api_keys", "companies"
  add_foreign_key "application_domains", "companies"
  add_foreign_key "application_domains", "oauth_applications"
  add_foreign_key "applications_companies", "companies"
  add_foreign_key "applications_companies", "oauth_applications", column: "application_id"
  add_foreign_key "customer_groups", "companies"
  add_foreign_key "memberships", "companies"
  add_foreign_key "memberships", "users"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "partnership_apps", "oauth_applications"
  add_foreign_key "partnership_apps", "partnerships"
  add_foreign_key "partnerships", "companies", column: "partner_client_id"
  add_foreign_key "partnerships", "companies", column: "partner_owner_id"
  add_foreign_key "users", "companies"
end
