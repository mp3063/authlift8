# Security Tests - Quick Start Guide

## Prerequisites

Ensure you have:
- Rails 8.0.0+ installed
- Ruby 3.3.x installed
- Database set up and migrated
- All gems installed (`bundle install`)
- Environment variables configured (see `.env.example`)

## Quick Run

### Run All Security Tests (Fastest)

```bash
bundle exec rspec spec/security
```

Expected output:
```
133 examples, 0 failures
```

### Run with Detailed Output

```bash
bundle exec rspec spec/security --format documentation
```

### Run Individual Test Files

```bash
# Auth integration security
bundle exec rspec spec/security/auth_integration_security_spec.rb

# Users controller security (IDOR tests)
bundle exec rspec spec/security/users_controller_security_spec.rb

# User authorization security (RBAC tests)
bundle exec rspec spec/security/user_authorization_security_spec.rb
```

## Common Issues and Solutions

### Issue: "No such file or directory - credentials"

**Solution:** Ensure Rails credentials are set up:
```bash
# Generate credentials if missing
EDITOR=nano rails credentials:edit
```

Add the required keys:
```yaml
doorkeeper:
  private_key: |
    -----BEGIN RSA PRIVATE KEY-----
    [Your RSA private key here]
    -----END RSA PRIVATE KEY-----
  public_key: |
    -----BEGIN PUBLIC KEY-----
    [Your RSA public key here]
    -----END PUBLIC KEY-----
```

### Issue: "Database not found"

**Solution:** Create and migrate the test database:
```bash
RAILS_ENV=test rails db:create
RAILS_ENV=test rails db:migrate
```

### Issue: "Uninitialized constant JWT"

**Solution:** Install the JWT gem:
```bash
bundle add jwt
bundle install
```

### Issue: "FactoryBot not found"

**Solution:** Ensure FactoryBot is in your Gemfile:
```ruby
group :development, :test do
  gem 'factory_bot_rails'
  gem 'rspec-rails'
end
```

Then run:
```bash
bundle install
```

### Issue: "ALLOWED_ORIGINS not set"

**Solution:** Set environment variable or create `.env` file:
```bash
export ALLOWED_ORIGINS="http://localhost:3232,http://localhost:3233"
```

Or add to `.env`:
```
ALLOWED_ORIGINS=http://localhost:3232,http://localhost:3233
AUTHLIFT_URL=http://localhost:3231
```

## Understanding Test Output

### Successful Test Output

```
Auth::IntegrationController Security
  Open Redirect Protection
    GET /auth/check_login
      ✓ allows redirect to whitelisted domain
      ✓ allows redirect to relative URLs (safe within domain)
      ✓ blocks redirect to non-whitelisted external domain
      ...

Finished in 5.23 seconds
133 examples, 0 failures
```

### Failed Test Output

```
Failures:

  1) Auth::IntegrationController Security Open Redirect Protection GET /auth/check_login
     blocks redirect to non-whitelisted external domain
     Failure/Error: expect(response).to have_http_status(:bad_request)

       expected the response to have status code :bad_request (400)
       but it was :see_other (303)
```

This indicates the open redirect protection is not working correctly.

## Running Specific Test Scenarios

### Run Only Open Redirect Tests

```bash
bundle exec rspec spec/security/auth_integration_security_spec.rb -e "Open Redirect"
```

### Run Only IDOR Tests

```bash
bundle exec rspec spec/security/users_controller_security_spec.rb -e "IDOR"
```

### Run Only JWT Tests

```bash
bundle exec rspec spec/security/auth_integration_security_spec.rb -e "JWT"
```

### Run Only Authorization Tests

```bash
bundle exec rspec spec/security/user_authorization_security_spec.rb
```

## Test Coverage

To see test coverage:

```bash
# Install SimpleCov if needed
bundle add simplecov --group development,test

# Run with coverage
COVERAGE=true bundle exec rspec spec/security
```

Coverage report will be generated in `coverage/index.html`.

## Debugging Failed Tests

### Enable Detailed Logging

```bash
# Set log level to debug
RAILS_LOG_LEVEL=debug bundle exec rspec spec/security
```

### Run Single Test

```bash
# Get line number from test file, e.g., line 45
bundle exec rspec spec/security/auth_integration_security_spec.rb:45
```

### Use Pry for Debugging

Add to test:
```ruby
require 'pry'
binding.pry  # Test will pause here
```

Then run:
```bash
bundle exec rspec spec/security/auth_integration_security_spec.rb:45
```

## Performance

### Test Execution Times

- **All Security Tests:** ~5-10 seconds
- **Auth Integration:** ~2-3 seconds
- **Users Controller:** ~1-2 seconds
- **User Authorization:** ~2-3 seconds

### Speed Up Tests

```bash
# Run tests in parallel (requires parallel_tests gem)
bundle exec parallel_rspec spec/security
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Security Tests
on: [push, pull_request]

jobs:
  security-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.3
      - name: Install dependencies
        run: bundle install
      - name: Setup database
        run: |
          RAILS_ENV=test rails db:create
          RAILS_ENV=test rails db:migrate
      - name: Run security tests
        run: bundle exec rspec spec/security --format documentation
```

## What Each Test File Covers

### auth_integration_security_spec.rb
Tests for `Auth::IntegrationController`:
- Open redirect protection
- JWT token validation
- CSRF protection
- Language whitelist validation
- Authorization bypass prevention

### users_controller_security_spec.rb
Tests for `Api::V1::UsersController`:
- IDOR (Insecure Direct Object Reference) protection
- Active membership verification
- Data isolation
- Profile endpoint security

### user_authorization_security_spec.rb
Tests for `User` model:
- Super admin global access
- Company-scoped authorization
- Role-based access control (RBAC)
- Inactive membership handling
- Multi-company access patterns

## Next Steps

After running tests successfully:

1. Review the test output to understand what's being tested
2. Read `spec/security/README.md` for comprehensive documentation
3. Review `SECURITY_TEST_SUMMARY.md` for detailed coverage information
4. Add these tests to your CI/CD pipeline
5. Run tests before every deployment

## Getting Help

- **Inline Comments:** Each test has detailed comments explaining what it tests
- **README:** See `spec/security/README.md` for comprehensive documentation
- **Summary:** See `SECURITY_TEST_SUMMARY.md` for vulnerability details
- **Code:** Review the controller/model implementations for context

## Success Criteria

✅ All 133+ tests pass
✅ No failures or errors
✅ Test execution time < 15 seconds
✅ Coverage > 95% for security-critical code

---

**Last Updated:** October 9, 2024
**Quick Start Version:** 1.0.0
