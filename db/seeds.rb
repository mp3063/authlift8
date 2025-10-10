# Authlift8 Seeds - Development Test Data
# This file creates a comprehensive set of test data for development and testing

puts "🌱 Seeding Authlift8 development database..."

# ==============================================================================
# 1. USERS
# ==============================================================================
puts "\n👤 Creating users..."

# Super Admin - Platform-level access to everything
super_admin = User.find_or_create_by!(email: 'superadmin@authlift.com') do |u|
  u.password = 'password123456'
  u.password_confirmation = 'password123456'
  u.first_name = 'Super'
  u.last_name = 'Admin'
  u.super_admin = true
  u.admin = false
end
puts "  ✓ Super Admin: superadmin@authlift.com"

# Regular Admin - Legacy admin access
admin = User.find_or_create_by!(email: 'admin@authlift.com') do |u|
  u.password = 'password123456'
  u.password_confirmation = 'password123456'
  u.first_name = 'Admin'
  u.last_name = 'User'
  u.super_admin = false
  u.admin = true
end
puts "  ✓ Admin: admin@authlift.com"

# Regular test user
test_user = User.find_or_create_by!(email: 'test@example.com') do |u|
  u.password = 'password123456'
  u.password_confirmation = 'password123456'
  u.first_name = 'Test'
  u.last_name = 'User'
  u.super_admin = false
  u.admin = false
end
puts "  ✓ Test User: test@example.com"

# Company owner user
owner_user = User.find_or_create_by!(email: 'owner@acmecorp.com') do |u|
  u.password = 'password123456'
  u.password_confirmation = 'password123456'
  u.first_name = 'John'
  u.last_name = 'Owner'
  u.super_admin = false
  u.admin = false
end
puts "  ✓ Company Owner: owner@acmecorp.com"

# Company admin user
company_admin = User.find_or_create_by!(email: 'admin@techstart.com') do |u|
  u.password = 'password123456'
  u.password_confirmation = 'password123456'
  u.first_name = 'Jane'
  u.last_name = 'Admin'
  u.super_admin = false
  u.admin = false
end
puts "  ✓ Company Admin: admin@techstart.com"

# Company member user
member_user = User.find_or_create_by!(email: 'member@globalshop.com') do |u|
  u.password = 'password123456'
  u.password_confirmation = 'password123456'
  u.first_name = 'Bob'
  u.last_name = 'Member'
  u.super_admin = false
  u.admin = false
end
puts "  ✓ Company Member: member@globalshop.com"

# Multi-company user (belongs to multiple companies)
multi_user = User.find_or_create_by!(email: 'multi@example.com') do |u|
  u.password = 'password123456'
  u.password_confirmation = 'password123456'
  u.first_name = 'Multi'
  u.last_name = 'Company'
  u.super_admin = false
  u.admin = false
end
puts "  ✓ Multi-Company User: multi@example.com"

# ==============================================================================
# 2. COMPANIES
# ==============================================================================
puts "\n🏢 Creating companies..."

# Main test company
test_company = Company.find_or_create_by!(code: 'TESTCO') do |c|
  c.name = 'Test Company'
  c.email = 'contact@testcompany.com'
  c.phone = '+1-555-0100'
  c.website = 'https://testcompany.com'
  c.address_line1 = '123 Test Street'
  c.city = 'San Francisco'
  c.state = 'CA'
  c.postal_code = '94102'
  c.country = 'US'
  c.locale = 'en'
  c.active = true
  c.vat_id = 'US123456789'
  c.business_id = 'BIZ-001'
  c.info = { industry: 'Technology', founded: '2020' }
  c.settings = { theme: 'light', notifications_enabled: true }
end
puts "  ✓ Test Company (TESTCO)"

# ACME Corporation - Supplier/Service Provider
acme_corp = Company.find_or_create_by!(code: 'ACMECORP') do |c|
  c.name = 'ACME Corporation'
  c.email = 'sales@acmecorp.com'
  c.phone = '+1-555-0200'
  c.website = 'https://acmecorp.com'
  c.address_line1 = '456 Business Ave'
  c.city = 'New York'
  c.state = 'NY'
  c.postal_code = '10001'
  c.country = 'US'
  c.locale = 'en'
  c.active = true
  c.vat_id = 'US987654321'
  c.business_id = 'BIZ-002'
  c.info = { industry: 'Manufacturing', founded: '2015', employees: 250 }
  c.settings = { theme: 'dark', currency: 'USD' }
end
puts "  ✓ ACME Corporation (ACMECORP)"

# TechStart Inc - Small startup
techstart = Company.find_or_create_by!(code: 'TECHSTART') do |c|
  c.name = 'TechStart Inc'
  c.email = 'hello@techstart.io'
  c.phone = '+1-555-0300'
  c.website = 'https://techstart.io'
  c.address_line1 = '789 Startup Lane'
  c.city = 'Austin'
  c.state = 'TX'
  c.postal_code = '78701'
  c.country = 'US'
  c.locale = 'en'
  c.active = true
  c.vat_id = 'US111222333'
  c.business_id = 'BIZ-003'
  c.info = { industry: 'SaaS', founded: '2023', employees: 15 }
  c.settings = { theme: 'light', currency: 'USD', timezone: 'America/Chicago' }
end
puts "  ✓ TechStart Inc (TECHSTART)"

# GlobalShop - E-commerce retailer
globalshop = Company.find_or_create_by!(code: 'GLOBALSHOP') do |c|
  c.name = 'GlobalShop Ltd'
  c.email = 'support@globalshop.com'
  c.phone = '+44-20-1234-5678'
  c.website = 'https://globalshop.com'
  c.address_line1 = '10 Commerce Street'
  c.city = 'London'
  c.postal_code = 'EC1A 1BB'
  c.country = 'GB'
  c.locale = 'en'
  c.active = true
  c.vat_id = 'GB123456789'
  c.business_id = 'BIZ-004'
  c.info = { industry: 'E-commerce', founded: '2018', employees: 150 }
  c.settings = { theme: 'light', currency: 'GBP', timezone: 'Europe/London' }
end
puts "  ✓ GlobalShop Ltd (GLOBALSHOP)"

# Inactive company for testing
inactive_company = Company.find_or_create_by!(code: 'INACTIVE') do |c|
  c.name = 'Inactive Company'
  c.email = 'old@inactive.com'
  c.active = false
  c.info = { status: 'Archived' }
end
puts "  ✓ Inactive Company (INACTIVE) - inactive"

# ==============================================================================
# 3. MEMBERSHIPS (User-Company relationships with roles)
# ==============================================================================
puts "\n👥 Creating memberships..."

# Test user → Test Company (owner)
Membership.find_or_create_by!(user: test_user, company: test_company) do |m|
  m.role = 'owner'
  m.active = true
  m.scopes = [ 'products:read', 'products:write', 'orders:read', 'orders:write' ]
  m.info = { joined_at: '2024-01-01', department: 'Engineering' }
end
test_user.update(company: test_company)
puts "  ✓ test@example.com → Test Company (owner)"

# Owner user → ACME (owner)
Membership.find_or_create_by!(user: owner_user, company: acme_corp) do |m|
  m.role = 'owner'
  m.active = true
  m.scopes = [ 'products:read', 'products:write', 'orders:read', 'orders:write', 'users:manage' ]
  m.info = { joined_at: '2015-01-01', department: 'Management' }
end
owner_user.update(company: acme_corp)
puts "  ✓ owner@acmecorp.com → ACME Corporation (owner)"

# Company admin → TechStart (admin)
Membership.find_or_create_by!(user: company_admin, company: techstart) do |m|
  m.role = 'admin'
  m.active = true
  m.scopes = [ 'products:read', 'products:write', 'orders:read', 'users:read' ]
  m.info = { joined_at: '2023-02-01', department: 'Operations' }
end
company_admin.update(company: techstart)
puts "  ✓ admin@techstart.com → TechStart Inc (admin)"

# Member user → GlobalShop (member with limited scopes)
Membership.find_or_create_by!(user: member_user, company: globalshop) do |m|
  m.role = 'member'
  m.active = true
  m.scopes = [ 'products:read', 'orders:read' ]
  m.info = { joined_at: '2024-03-15', department: 'Sales' }
end
member_user.update(company: globalshop)
puts "  ✓ member@globalshop.com → GlobalShop Ltd (member)"

# Multi-company user memberships
Membership.find_or_create_by!(user: multi_user, company: test_company) do |m|
  m.role = 'admin'
  m.active = true
  m.scopes = [ 'products:read', 'orders:read' ]
end

Membership.find_or_create_by!(user: multi_user, company: acme_corp) do |m|
  m.role = 'member'
  m.active = true
  m.scopes = [ 'products:read' ]
end

Membership.find_or_create_by!(user: multi_user, company: techstart) do |m|
  m.role = 'admin'
  m.active = true
  m.scopes = [ 'products:read', 'products:write', 'orders:read' ]
end
multi_user.update(company: test_company)
puts "  ✓ multi@example.com → Test Company (admin)"
puts "  ✓ multi@example.com → ACME Corporation (member)"
puts "  ✓ multi@example.com → TechStart Inc (admin)"

# Inactive membership for testing
Membership.find_or_create_by!(user: test_user, company: acme_corp) do |m|
  m.role = 'member'
  m.active = false
  m.scopes = []
  m.info = { status: 'Deactivated', deactivated_at: '2024-06-01' }
end
puts "  ✓ test@example.com → ACME Corporation (inactive member)"

# ==============================================================================
# 4. PARTNERSHIPS (B2B Company-Company relationships)
# ==============================================================================
puts "\n🤝 Creating partnerships..."

# ACME (supplier) ↔ GlobalShop (client)
partnership1 = Partnership.find_or_create_by!(
  partner_owner: acme_corp,
  partner_client: globalshop
) do |p|
  p.active = true
  p.managed_company = false
  p.info = {
    partnership_type: 'wholesale',
    discount_percentage: 15,
    credit_limit: 50000
  }
  p.settings = {
    auto_approve_orders: true,
    payment_terms: 'net30'
  }
end
puts "  ✓ ACME Corporation (supplier) ↔ GlobalShop Ltd (client)"

# ACME (supplier) ↔ TechStart (client)
partnership2 = Partnership.find_or_create_by!(
  partner_owner: acme_corp,
  partner_client: techstart
) do |p|
  p.active = true
  p.managed_company = false
  p.info = {
    partnership_type: 'b2b',
    discount_percentage: 10,
    credit_limit: 25000
  }
  p.settings = {
    auto_approve_orders: false,
    payment_terms: 'net15'
  }
end
puts "  ✓ ACME Corporation (supplier) ↔ TechStart Inc (client)"

# Test Company (supplier) ↔ GlobalShop (client)
partnership3 = Partnership.find_or_create_by!(
  partner_owner: test_company,
  partner_client: globalshop
) do |p|
  p.active = true
  p.managed_company = true  # GlobalShop is managed by Test Company
  p.info = {
    partnership_type: 'managed',
    service_level: 'premium'
  }
  p.settings = {
    auto_approve_orders: true,
    shared_inventory: true
  }
end
puts "  ✓ Test Company (supplier) ↔ GlobalShop Ltd (managed client)"

# Inactive partnership
partnership4 = Partnership.find_or_create_by!(
  partner_owner: test_company,
  partner_client: techstart
) do |p|
  p.active = false
  p.managed_company = false
  p.info = { status: 'Terminated', ended_at: '2024-05-01' }
end
puts "  ✓ Test Company ↔ TechStart Inc (inactive)"

# ==============================================================================
# 5. OAUTH APPLICATIONS (Doorkeeper)
# ==============================================================================
puts "\n🔐 Creating OAuth applications..."

# Main application - owned by Test Company
main_app = Doorkeeper::Application.find_or_create_by!(name: 'Main Application') do |app|
  app.redirect_uri = "http://localhost:3232/auth/callback\nhttp://localhost:3232/oauth/callback"
  app.scopes = 'public profile email companies:read companies:write orders:read products:read'
  app.confidential = true
  app.owner = test_company
  app.home = 'http://localhost:3232'
  app.partnerships_allowed = true
  app.trusted = true
end
puts "  ✓ Main Application (trusted)"

# Mobile App - public client
mobile_app = Doorkeeper::Application.find_or_create_by!(name: 'Mobile App') do |app|
  app.redirect_uri = "com.authlift.mobile://oauth/callback\nhttp://localhost:3232/mobile/callback"
  app.scopes = 'public profile email'
  app.confidential = false
  app.owner = test_company
  app.home = 'http://localhost:3232'
  # app.application_icon = 'mobile-icon.png'  # Commented out - image doesn't exist yet
  app.partnerships_allowed = false
  app.trusted = false
end
puts "  ✓ Mobile App (public client)"

# Third-party integration
third_party_app = Doorkeeper::Application.find_or_create_by!(name: 'Third Party Integration') do |app|
  app.redirect_uri = "https://thirdparty.example.com/callback"
  app.scopes = 'public profile'
  app.confidential = true
  app.owner = acme_corp
  app.home = 'https://thirdparty.example.com'
  app.partnerships_allowed = false
  app.trusted = false
end
puts "  ✓ Third Party Integration (untrusted)"

# Admin Dashboard App
admin_app = Doorkeeper::Application.find_or_create_by!(name: 'Admin Dashboard') do |app|
  app.redirect_uri = "http://localhost:3233/auth/callback"
  app.scopes = 'public profile email admin:read admin:write'
  app.confidential = true
  app.owner = test_company
  app.home = 'http://localhost:3233'
  app.partnerships_allowed = false
  app.trusted = true
end
puts "  ✓ Admin Dashboard (trusted)"

# ==============================================================================
# 6. APPLICATION DOMAINS (Multi-domain OAuth support)
# ==============================================================================
puts "\n🌐 Creating application domains..."

ApplicationDomain.find_or_create_by!(
  oauth_application: main_app,
  company: test_company,
  domain: 'http://localhost:3232'
)

ApplicationDomain.find_or_create_by!(
  oauth_application: main_app,
  company: acme_corp,
  domain: 'http://localhost:3234'
)

ApplicationDomain.find_or_create_by!(
  oauth_application: admin_app,
  company: test_company,
  domain: 'http://localhost:3233'
)
puts "  ✓ Created application domains for multi-tenant OAuth"

# ==============================================================================
# 7. APPLICATIONS-COMPANIES (HABTM - App access control)
# ==============================================================================
puts "\n🔗 Creating application-company associations..."

# Test Company can use Main App and Admin Dashboard
test_company.allowed_applications << main_app unless test_company.allowed_applications.include?(main_app)
test_company.allowed_applications << admin_app unless test_company.allowed_applications.include?(admin_app)

# ACME can use Main App
acme_corp.allowed_applications << main_app unless acme_corp.allowed_applications.include?(main_app)

# GlobalShop can use Main App
globalshop.allowed_applications << main_app unless globalshop.allowed_applications.include?(main_app)

puts "  ✓ Configured company-application access control"

# ==============================================================================
# 8. PARTNERSHIP APPS (Apps available per partnership)
# ==============================================================================
puts "\n📱 Creating partnership apps..."

PartnershipApp.find_or_create_by!(
  partnership: partnership1,
  oauth_application: main_app
) do |pa|
  pa.active = true
end

PartnershipApp.find_or_create_by!(
  partnership: partnership2,
  oauth_application: main_app
) do |pa|
  pa.active = true
end

PartnershipApp.find_or_create_by!(
  partnership: partnership3,
  oauth_application: admin_app
) do |pa|
  pa.active = true
end
puts "  ✓ Created partnership-specific app access"

# ==============================================================================
# 9. CUSTOMER GROUPS (B2B customer segmentation)
# ==============================================================================
puts "\n👔 Creating customer groups..."

# Wholesale customers for ACME
wholesale_group = CustomerGroup.find_or_create_by!(
  company: acme_corp,
  name: 'Wholesale Customers'
) do |cg|
  cg.group_type = 'wholesale'
  cg.enabled = true
  cg.product_restriction_rules = {
    allowed_product_ids: [],
    excluded_product_ids: []
  }
  cg.pricing_rules = {
    price_multiplier: 0.85,  # 15% discount
    discount_percentage: 0,
    min_order_quantity: 100
  }
end
puts "  ✓ Wholesale Customers (ACME) - 15% discount"

# VIP customers for GlobalShop
vip_group = CustomerGroup.find_or_create_by!(
  company: globalshop,
  name: 'VIP Customers'
) do |cg|
  cg.group_type = 'vip'
  cg.enabled = true
  cg.product_restriction_rules = {
    allowed_product_ids: [],
    excluded_product_ids: []
  }
  cg.pricing_rules = {
    price_multiplier: 0.90,  # 10% discount
    discount_percentage: 0,
    early_access: true
  }
end
puts "  ✓ VIP Customers (GlobalShop) - 10% discount + early access"

# Retail customers for Test Company
retail_group = CustomerGroup.find_or_create_by!(
  company: test_company,
  name: 'Retail Customers'
) do |cg|
  cg.group_type = 'retail'
  cg.enabled = true
  cg.product_restriction_rules = {
    allowed_product_ids: [],
    excluded_product_ids: []
  }
  cg.pricing_rules = {
    price_multiplier: 1.0,  # Standard pricing
    discount_percentage: 0
  }
end
puts "  ✓ Retail Customers (Test Company) - standard pricing"

# Partner pricing for special partners
partner_group = CustomerGroup.find_or_create_by!(
  company: acme_corp,
  name: 'Partner Network'
) do |cg|
  cg.group_type = 'partner'
  cg.enabled = true
  cg.product_restriction_rules = {
    allowed_product_ids: [],
    excluded_product_ids: []
  }
  cg.pricing_rules = {
    price_multiplier: 0.75,  # 25% discount
    discount_percentage: 0,
    volume_discounts: true
  }
end
puts "  ✓ Partner Network (ACME) - 25% discount"

# ==============================================================================
# 10. API KEYS (Alternative authentication method)
# ==============================================================================
puts "\n🔑 Creating API keys..."

# Active API key for Test Company
api_key1 = ApiKey.find_or_create_by!(
  company: test_company,
  name: 'Production API Key'
) do |key|
  key.token = Digest::SHA256.hexdigest("test-company-prod-#{SecureRandom.hex(32)}")
  key.scopes = [ 'api:read', 'api:write', 'products:read', 'orders:read' ]
  key.active = true
  key.expires_at = 1.year.from_now
  key.last_used_at = 1.day.ago
end
puts "  ✓ Test Company - Production API Key"

# Development API key for ACME
api_key2 = ApiKey.find_or_create_by!(
  company: acme_corp,
  name: 'Development API Key'
) do |key|
  key.token = Digest::SHA256.hexdigest("acme-dev-#{SecureRandom.hex(32)}")
  key.scopes = [ 'api:read', 'products:read' ]
  key.active = true
  key.expires_at = 6.months.from_now
end
puts "  ✓ ACME Corporation - Development API Key"

# Expired API key for testing
api_key3 = ApiKey.find_or_create_by!(
  company: test_company,
  name: 'Expired API Key'
) do |key|
  key.token = Digest::SHA256.hexdigest("test-expired-#{SecureRandom.hex(32)}")
  key.scopes = [ 'api:read' ]
  key.active = false
  key.expires_at = 1.month.ago
  key.last_used_at = 2.months.ago
end
puts "  ✓ Test Company - Expired API Key (inactive)"

# ==============================================================================
# SUMMARY
# ==============================================================================
puts "\n" + "=" * 80
puts "✅ SEED COMPLETED SUCCESSFULLY!"
puts "=" * 80

puts "\n📊 Summary:"
puts "  Users:             #{User.count}"
puts "  Companies:         #{Company.count}"
puts "  Memberships:       #{Membership.count}"
puts "  Partnerships:      #{Partnership.count}"
puts "  OAuth Apps:        #{Doorkeeper::Application.count}"
puts "  App Domains:       #{ApplicationDomain.count}"
puts "  Partnership Apps:  #{PartnershipApp.count}"
puts "  Customer Groups:   #{CustomerGroup.count}"
puts "  API Keys:          #{ApiKey.count}"

puts "\n🔐 Test Credentials (all passwords: password123456):"
puts "  Superadmin:        superadmin@authlift.com"
puts "  Admin:             admin@authlift.com"
puts "  Test User:         test@example.com"
puts "  Company Owner:     owner@acmecorp.com"
puts "  Company Admin:     admin@techstart.com"
puts "  Company Member:    member@globalshop.com"
puts "  Multi-Company:     multi@example.com"

puts "\n🏢 Test Companies:"
puts "  Test Company       (TESTCO)     - test@example.com (owner)"
puts "  ACME Corporation   (ACMECORP)   - owner@acmecorp.com (owner)"
puts "  TechStart Inc      (TECHSTART)  - admin@techstart.com (admin)"
puts "  GlobalShop Ltd     (GLOBALSHOP) - member@globalshop.com (member)"

puts "\n🔐 OAuth Applications:"
puts "  Main Application   - http://localhost:3232 (trusted)"
puts "  Mobile App         - com.authlift.mobile://oauth/callback"
puts "  Admin Dashboard    - http://localhost:3233 (trusted)"
puts "  Third Party        - https://thirdparty.example.com (untrusted)"

puts "\n🤝 B2B Partnerships:"
puts "  ACME → GlobalShop  (wholesale, 15% discount)"
puts "  ACME → TechStart   (b2b, 10% discount)"
puts "  Test → GlobalShop  (managed)"

puts "\n👔 Customer Groups:"
puts "  Wholesale (ACME)   - 15% discount, min 100 units"
puts "  VIP (GlobalShop)   - 10% discount, early access"
puts "  Retail (Test)      - standard pricing"
puts "  Partners (ACME)    - 25% discount, volume pricing"

puts "\n" + "=" * 80
puts "🚀 Ready to test! Visit http://localhost:3231"
puts "=" * 80
puts ""
