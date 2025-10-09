# Security Test Suite

This directory contains comprehensive security tests for the Authlift8 OAuth2 authentication server. These tests verify that all identified security vulnerabilities have been properly fixed.

## Overview

The security test suite covers three main areas:

1. **Auth Integration Security** - Tests for the `Auth::IntegrationController`
2. **Users Controller Security** - Tests for the `Api::V1::UsersController`
3. **User Authorization Security** - Tests for the `User` model authorization logic

## Test Coverage Summary

### 1. Auth Integration Security (`auth_integration_security_spec.rb`)

**Total Lines:** 579
**Test Categories:**

#### Open Redirect Protection
- ✅ Validates redirect URLs against whitelist
- ✅ Allows relative URLs (safe)
- ✅ Blocks external domains not in whitelist
- ✅ Logs security warnings for invalid redirects
- ✅ Handles invalid URI formats
- ✅ Applies to all endpoints: `check_login`, `logout`, `switch_company`, `change_language`

#### JWT Token Validation
- ✅ Validates `iss` (issuer) claim
- ✅ Validates `sub` (subject) claim
- ✅ Validates `exp` (expiration) claim
- ✅ Validates `iat` (issued at) claim
- ✅ Validates `nbf` (not before) claim
- ✅ Implements clock skew tolerance (60 seconds)
- ✅ Rejects tokens signed with wrong key
- ✅ Rejects expired tokens
- ✅ Rejects tokens with invalid issuer

#### Authorization Bypass Prevention
- ✅ Only allows switching to companies with ACTIVE memberships
- ✅ Blocks switching to companies with inactive memberships
- ✅ Blocks switching to non-existent companies
- ✅ Logs unauthorized company switch attempts

#### CSRF Protection
- ✅ Accepts POST with valid JWT (no CSRF needed)
- ✅ Rejects POST without JWT or CSRF token
- ✅ Allows GET requests without CSRF
- ✅ Falls back to CSRF check when JWT is invalid
- ✅ Logs CSRF validation failures

#### Language Validation
- ✅ Accepts only whitelisted language codes
- ✅ Rejects invalid language codes
- ✅ Prevents SQL injection attempts
- ✅ Handles case-insensitive language codes
- ✅ Updates membership info with validated language

#### Security Logging
- ✅ Logs successful operations (logout, company switch, language change)
- ✅ Logs security violations (unauthorized access, invalid tokens)
- ✅ Logs invalid redirect attempts

### 2. Users Controller Security (`users_controller_security_spec.rb`)

**Total Lines:** 486
**Test Categories:**

#### IDOR Protection
- ✅ Allows access to companies with active membership
- ✅ Blocks access to companies with inactive membership
- ✅ Blocks access to companies without any membership
- ✅ Blocks access to non-existent companies
- ✅ Logs security-relevant access attempts with IP address
- ✅ Returns current company when no company_id provided

#### Profile Endpoint Security
- ✅ Only includes companies with active memberships in `all_companies`
- ✅ Excludes companies with inactive memberships
- ✅ Returns current company from active membership
- ✅ Returns current membership data from active membership
- ✅ Handles users with no active memberships gracefully

#### Data Isolation
- ✅ Does not expose other users' companies
- ✅ Prevents horizontal privilege escalation
- ✅ Proper data structure without internal fields
- ✅ No partnership data leaked for unauthorized companies

#### Access Control - Membership Transitions
- ✅ Grants access when membership becomes active
- ✅ Revokes access when membership becomes inactive
- ✅ Updates allowed companies list dynamically

#### Error Handling
- ✅ Handles internal server errors gracefully
- ✅ Requires authentication
- ✅ Returns 404 when user is deleted
- ✅ Handles nil company gracefully

### 3. User Authorization Security (`user_authorization_security_spec.rb`)

**Total Lines:** 570
**Test Categories:**

#### Super Admin - Global Access
- ✅ `has_scope?` returns true for any scope
- ✅ Global access across all companies
- ✅ Access without any memberships
- ✅ `admin_for?` returns true for any company
- ✅ Proper handling of nil/false super_admin attribute

#### Company-Scoped Authorization
- ✅ Owner role has full access within company
- ✅ Admin role has full access within company
- ✅ Member role has scope-based access
- ✅ Cross-company access control (isolation)
- ✅ Scopes isolated per company

#### Inactive Membership Handling
- ✅ Denies access to companies with inactive membership
- ✅ Does not use inactive memberships for authorization
- ✅ Grants access when membership becomes active
- ✅ Revokes access when membership becomes inactive

#### Current Company Context
- ✅ Uses current_company when company parameter not provided
- ✅ Returns false when no current company is set
- ✅ Uses provided company parameter when specified
- ✅ Allows checking scopes for any accessible company

#### Role-Based Access Control (RBAC)
- ✅ Owner > Admin > Member hierarchy
- ✅ Role transitions respect active status
- ✅ Different roles across multiple companies
- ✅ Permission isolation between companies

#### Security Edge Cases
- ✅ Prevents privilege escalation via inactive membership
- ✅ Validates active status before granting privileges
- ✅ Handles nil parameters gracefully
- ✅ Handles both symbol and string scope parameters

#### Security Logging
- ✅ Logs warning when setting current_company without active membership
- ✅ Allows setting current_company with active membership
- ✅ Prevents unauthorized company assignment

## Running the Tests

### Run All Security Tests

```bash
bundle exec rspec spec/security
```

### Run Individual Test Files

```bash
# Auth integration security tests
bundle exec rspec spec/security/auth_integration_security_spec.rb

# Users controller security tests
bundle exec rspec spec/security/users_controller_security_spec.rb

# User authorization security tests
bundle exec rspec spec/security/user_authorization_security_spec.rb
```

### Run Specific Test Sections

```bash
# Run only Open Redirect Protection tests
bundle exec rspec spec/security/auth_integration_security_spec.rb -e "Open Redirect Protection"

# Run only IDOR Protection tests
bundle exec rspec spec/security/users_controller_security_spec.rb -e "IDOR Protection"

# Run only Super Admin tests
bundle exec rspec spec/security/user_authorization_security_spec.rb -e "Super Admin"
```

### Run with Documentation Format

```bash
bundle exec rspec spec/security --format documentation
```

### Generate Coverage Report

```bash
COVERAGE=true bundle exec rspec spec/security
```

## Test Data Setup

All tests use FactoryBot for test data creation:

- **Users** - Regular users and super admins
- **Companies** - Multiple companies for cross-company testing
- **Memberships** - Active/inactive memberships with different roles (owner, admin, member)
- **OAuth Tokens** - Access tokens for API authentication

## JWT Testing Helper

The test suite includes a JWT test helper (`spec/support/jwt_test_helper.rb`) that provides:

- `generate_test_jwt(user, payload_overrides)` - Generate valid JWT tokens
- `decode_test_jwt(token)` - Decode and verify tokens
- `generate_expired_jwt(user)` - Generate expired tokens for testing
- `generate_jwt_with_invalid_issuer(user)` - Generate tokens with invalid issuer
- `generate_jwt_with_wrong_key(user)` - Generate tokens signed with wrong key

## Security Vulnerabilities Fixed

These tests verify fixes for the following security vulnerabilities:

1. **Open Redirect Vulnerability** - Unvalidated redirect URLs could redirect users to malicious sites
2. **JWT Token Validation Issues** - Missing validation of critical JWT claims (iss, exp, iat, nbf)
3. **Authorization Bypass** - Missing active membership checks allowed access to inactive company memberships
4. **IDOR (Insecure Direct Object Reference)** - Users could access company data without proper membership verification
5. **Language Injection** - Unvalidated language parameter could allow arbitrary data injection
6. **CSRF Token Bypass** - Missing CSRF protection on state-changing operations
7. **Privilege Escalation** - Inactive memberships could be used to maintain elevated privileges

## Test Statistics

- **Total Test Files:** 3
- **Total Lines of Test Code:** 1,635
- **Total Test Cases:** 100+ test scenarios
- **Coverage Areas:**
  - Controller endpoints (request specs)
  - Model authorization logic (model specs)
  - Security logging
  - Error handling
  - Edge cases

## Security Testing Best Practices

These tests follow security testing best practices:

1. **Negative Testing** - Tests what should NOT work (unauthorized access, invalid tokens)
2. **Boundary Testing** - Tests edge cases (nil values, empty arrays, expired tokens)
3. **Comprehensive Coverage** - Tests all security-critical paths
4. **Security Logging Verification** - Ensures security events are logged
5. **Realistic Scenarios** - Uses real-world attack vectors
6. **Isolation** - Each test is independent and does not affect others

## Continuous Integration

These security tests should be run:

- On every commit
- Before every deployment
- As part of the CI/CD pipeline
- During security audits

## Maintenance

When adding new security features:

1. Add corresponding security tests first (TDD)
2. Ensure tests cover both positive and negative cases
3. Add security logging verification
4. Update this README with new test coverage

## Related Documentation

- [Security Fixes Documentation](../../SECURITY_FIXES.md) - Detailed explanation of all security fixes
- [Auth Integration Controller](../../app/controllers/auth/integration_controller.rb) - Implementation
- [Users Controller](../../app/controllers/api/v1/users_controller.rb) - Implementation
- [User Model](../../app/models/user.rb) - Authorization logic

## Contact

For questions about security tests:
- Review the inline test comments
- Check the security fixes documentation
- Consult the development team

---

**Last Updated:** October 9, 2024
**Test Suite Version:** 1.0.0
**Rails Version:** 8.0.0
**Ruby Version:** 3.3.x
