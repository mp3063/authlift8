# README

🔐 Test Credentials (Password: password123456 for all)

Users by Role:

1. superadmin@authlift.com - Super Admin (platform-wide access)
2. admin@authlift.com - Legacy Admin
3. test@example.com - Regular user (owner of Test Company)
4. owner@acmecorp.com - Company owner (ACME Corporation)
5. admin@techstart.com - Company admin (TechStart Inc)
6. member@globalshop.com - Limited member (GlobalShop Ltd)
7. multi@example.com - Multi-company user (belongs to 3 companies)

📊 What Was Created:

✅ 8 Users - Various permission levels✅ 5 Companies - Including 1 inactive for testing✅ 10 Memberships - Different roles (owner/admin/member), including 1 inactive✅ 4
Partnerships - B2B supplier-client relationships✅ 4 OAuth Applications - Trusted & untrusted apps✅ 3 Application Domains - Multi-tenant OAuth support✅ 3 Partnership Apps -
Apps linked to partnerships✅ 4 Customer Groups - B2B pricing tiers (15-25% discounts)✅ 3 API Keys - Including 1 expired for testing

🧪 Test Scenarios You Can Now Try:

Basic Authentication:

- Login as test@example.com / password123456
- View dashboard with Test Company context
- Switch between companies (if multi-company user)

Admin Features:

- Login as superadmin@authlift.com to access /admin
- Manage users, companies, OAuth apps

Multi-Company Testing:

- Login as multi@example.com
- Should see 3 companies: Test Company (admin), ACME (member), TechStart (admin)
- Test company switching

B2B Partnership Testing:

- ACME supplies to GlobalShop (15% wholesale discount)
- Test Company manages GlobalShop as client

OAuth Flow Testing:

- Use "Main Application" for OAuth testing
- Authorize at http://localhost:3231/oauth/authorize

🚀 Quick Start:

# Start the server
bin/rails server -p 3231

# Or with Tailwind watcher
bin/dev

Then visit http://localhost:3231 and login with any of the credentials above!

Your database is now fully populated and ready for comprehensive testing! 🎊