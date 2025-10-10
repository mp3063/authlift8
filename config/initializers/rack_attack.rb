# frozen_string_literal: true

# =============================================================================
# Rack::Attack - Rate Limiting & Throttling Configuration
# =============================================================================
#
# Rack::Attack is a rack middleware to protect your web app from bad clients.
# It allows whitelisting, blacklisting, throttling, and tracking based on
# arbitrary properties of the request.
#
# Documentation: https://github.com/rack/rack-attack
#
# SECURITY ARCHITECTURE:
# This configuration implements multi-layer defense against brute force attacks,
# credential stuffing, DDoS, and other authentication-related attacks following
# OWASP authentication security recommendations.
#
# IMPORTANT: This configuration uses Redis for distributed rate limiting.
# Ensure Redis is configured and running in production.
#
# Environment Variables:
# - RACK_ATTACK_ENABLED: Set to 'false' to disable in development (default: true)
# - REDIS_URL: Redis connection URL for distributed rate limiting
# - WHITELISTED_IPS: Comma-separated list of IPs to whitelist (internal services)
# - BLOCKED_IPS: Comma-separated list of IPs to permanently block
# =============================================================================

class Rack::Attack
  # =============================================================================
  # Configuration
  # =============================================================================

  # Enable/disable Rack::Attack (environment-aware)
  # - Test: Always disabled (prevents test flakiness)
  # - Development: Disabled by default (set RACK_ATTACK_ENABLED=true to test)
  # - Production/Staging: Always enabled (critical security protection)
  Rack::Attack.enabled = if Rails.env.test?
                           false
                         elsif Rails.env.development?
                           ENV.fetch('RACK_ATTACK_ENABLED', 'false') == 'true'
                         else
                           # Production/Staging: Always enabled
                           true
                         end

  # Configure Redis for distributed rate limiting across multiple servers
  # In production, this ensures rate limits work correctly with multiple app instances
  # Use memory store for development/test environments
  if Rails.env.production? || Rails.env.staging?
    Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
      url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
      namespace: 'rack_attack'
    )
  else
    # Use memory store for development (no Redis required)
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  # =============================================================================
  # Safelist (Whitelist) - These requests bypass all throttles
  # =============================================================================

  # Always allow requests from localhost in development
  safelist('allow-localhost') do |req|
    Rails.env.development? && ['127.0.0.1', '::1'].include?(req.ip)
  end

  # Allow monitoring/health check endpoints to bypass rate limits
  safelist('allow-health-checks') do |req|
    req.path == '/health' || req.path == '/up'
  end

  # Whitelist specific IPs (internal services, trusted partners)
  # Example: WHITELISTED_IPS=10.0.1.5,192.168.1.100
  # Security Note: Use sparingly - whitelisted IPs bypass ALL rate limits
  safelist('whitelist-internal-ips') do |req|
    whitelisted_ips = ENV.fetch('WHITELISTED_IPS', '').split(',').map(&:strip)
    whitelisted_ips.include?(req.ip) if whitelisted_ips.any?
  end

  # =============================================================================
  # Blocklist (Blacklist) - Permanently block malicious IPs
  # =============================================================================

  # Block requests from known bad IPs
  # Add malicious IPs to BLOCKED_IPS environment variable (comma-separated)
  # Example: BLOCKED_IPS=192.168.1.1,10.0.0.1
  blocklist('block-malicious-ips') do |req|
    blocked_ips = ENV.fetch('BLOCKED_IPS', '').split(',').map(&:strip)
    blocked_ips.include?(req.ip) if blocked_ips.any?
  end

  # Block requests with suspicious user agents (common bots/scanners)
  # Security Note: Adjust list based on your legitimate traffic patterns
  blocklist('block-bad-user-agents') do |req|
    suspicious_agents = [
      'masscan', 'nmap', 'nikto', 'sqlmap',
      'python-requests', 'go-http-client', 'scrapy',
      'zgrab', 'shodan', 'censys'
    ]
    user_agent = req.user_agent.to_s.downcase
    suspicious_agents.any? { |agent| user_agent.include?(agent) }
  end

  # Exponential backoff for repeat offenders (IP-based)
  # After hitting rate limits multiple times, increase the penalty period
  # This prevents persistent attackers from continuously hammering the server
  blocklist('repeat-offender-exponential-backoff') do |req|
    # Track how many times this IP has been throttled in the last hour
    violations_key = "violations:#{req.ip}"
    violations = Rack::Attack.cache.read(violations_key).to_i

    # Block IPs with more than 10 violations in the last hour
    # This indicates persistent abuse despite rate limiting
    if violations > 10
      # Extend the block period exponentially (up to 1 hour)
      block_duration = [300 * (2**(violations - 10)), 3600].min
      Rack::Attack.cache.store.write(violations_key, violations + 1, expires_in: 1.hour.to_i)
      true
    end
  end

  # =============================================================================
  # Throttles - Rate Limiting Rules
  # =============================================================================
  #
  # SECURITY STRATEGY: Multi-layer defense with different rate limits per layer
  #
  # Layer 1: Failed Authentication (Aggressive) - Prevents brute force
  # Layer 2: Authentication Endpoints (Moderate) - Prevents credential stuffing
  # Layer 3: Per-User Operations (Defense in Depth) - Prevents account takeover
  # Layer 4: Global Protection (DDoS Prevention) - Prevents resource exhaustion
  #
  # =============================================================================

  # =============================================================================
  # LAYER 1: Failed Authentication Protection (Aggressive)
  # =============================================================================
  # Purpose: Aggressively throttle failed login attempts to prevent brute force
  # OWASP Recommendation: Lock account after 5 failed attempts

  # Track failed login attempts by email
  # Limit: 5 failed attempts per 20 minutes per email
  # Security: Prevents credential stuffing and password guessing
  # Note: Only tracks FAILED attempts, successful logins don't count
  throttle('failed-logins/email', limit: 5, period: 20.minutes) do |req|
    if req.path == '/users/sign_in' && req.post?
      email = req.params['email'] || req.params.dig('user', 'email')
      # Use a unique key that distinguishes failed vs successful attempts
      # This will be cleared on successful login (see track block below)
      "failed-login:#{email.to_s.downcase}" if email.present?
    end
  end

  # Track failed login attempts by IP (prevents distributed attacks)
  # Limit: 10 failed attempts per 20 minutes per IP
  # Security: Prevents attackers using multiple email addresses from same IP
  throttle('failed-logins/ip', limit: 10, period: 20.minutes) do |req|
    if req.path == '/users/sign_in' && req.post?
      "failed-login:#{req.ip}"
    end
  end

  # Track failed login attempts by IP + User-Agent combination
  # Limit: 15 failed attempts per hour
  # Security: Detects sophisticated attackers rotating IPs but using same tools
  throttle('failed-logins/ip-ua', limit: 15, period: 1.hour) do |req|
    if req.path == '/users/sign_in' && req.post?
      ua_fingerprint = Digest::SHA256.hexdigest(req.user_agent.to_s)[0..8]
      "failed-login:#{req.ip}:#{ua_fingerprint}"
    end
  end

  # =============================================================================
  # LAYER 2: Authentication Endpoint Protection (Moderate)
  # =============================================================================
  # Purpose: Rate limit all authentication operations to prevent abuse

  # OAuth2 Token Endpoint (Critical - issues access tokens)
  # Limit: 20 requests per minute per IP
  # Security: Prevents brute force on authorization codes and client credentials
  # Stricter than previous config (was 20/5min, now 20/1min)
  throttle('oauth/token/ip', limit: 20, period: 1.minute) do |req|
    if req.path == '/oauth/token' && req.post?
      req.ip
    end
  end

  # OAuth2 Authorization Endpoint
  # Limit: 30 requests per 5 minutes per IP
  # Security: Prevents spam authorization requests
  throttle('oauth/authorize/ip', limit: 30, period: 5.minutes) do |req|
    if req.path == '/oauth/authorize' && (req.get? || req.post?)
      req.ip
    end
  end

  # OAuth2 Token Revocation Endpoint
  # Limit: 10 requests per minute per IP
  # Security: Prevents abuse of revocation endpoint
  throttle('oauth/revoke/ip', limit: 10, period: 1.minute) do |req|
    if req.path == '/oauth/revoke' && req.post?
      req.ip
    end
  end

  # Login Endpoint (POST /users/sign_in)
  # Limit: 5 requests per minute per IP
  # Security: Rate limits ALL login attempts (successful + failed)
  # Note: This works in conjunction with failed-login throttles above
  throttle('login/ip', limit: 5, period: 1.minute) do |req|
    if req.path == '/users/sign_in' && req.post?
      req.ip
    end
  end

  # Password Reset Request Endpoint
  # Limit: 3 requests per hour per email
  # Security: Prevents email bombing and enumeration attacks
  throttle('password-reset/email', limit: 3, period: 1.hour) do |req|
    if req.path == '/users/password' && req.post?
      email = req.params['email'] || req.params.dig('user', 'email')
      "password-reset:#{email.to_s.downcase}" if email.present?
    end
  end

  # Password Reset Request by IP (additional layer)
  # Limit: 10 requests per hour per IP
  # Security: Prevents mass password reset attacks from single IP
  throttle('password-reset/ip', limit: 10, period: 1.hour) do |req|
    if req.path == '/users/password' && req.post?
      req.ip
    end
  end

  # Registration Endpoint
  # Limit: 5 registrations per hour per IP
  # Security: Prevents automated account creation and spam
  throttle('registration/ip', limit: 5, period: 1.hour) do |req|
    if req.path == '/users' && req.post?
      req.ip
    end
  end

  # Registration by email (prevents re-registration attempts)
  # Limit: 3 attempts per day per email
  # Security: Prevents email enumeration through registration
  throttle('registration/email', limit: 3, period: 24.hours) do |req|
    if req.path == '/users' && req.post?
      email = req.params['email'] || req.params.dig('user', 'email')
      "registration:#{email.to_s.downcase}" if email.present?
    end
  end

  # =============================================================================
  # LAYER 3: Per-User Operations (Defense in Depth)
  # =============================================================================
  # Purpose: Rate limit authenticated user operations to prevent account abuse

  # Company Switching (Integration Endpoint)
  # Limit: 10 switches per minute per user
  # Security: Prevents rapid company context switching abuse
  throttle('switch-company/user', limit: 10, period: 1.minute) do |req|
    if req.path == '/auth/switch_company' && req.post?
      user = req.env['warden']&.user
      "switch-company:user:#{user.id}" if user
    end
  end

  # Company Switching by IP (unauthenticated protection)
  # Limit: 20 switches per minute per IP
  # Security: Protects endpoint even when JWT validation might fail
  throttle('switch-company/ip', limit: 20, period: 1.minute) do |req|
    if req.path == '/auth/switch_company' && req.post?
      req.ip
    end
  end

  # Language Change Operations
  # Limit: 15 changes per minute per user
  # Security: Prevents abuse of profile update endpoints
  throttle('change-language/user', limit: 15, period: 1.minute) do |req|
    if req.path == '/auth/change_language' && req.post?
      user = req.env['warden']&.user
      "change-language:user:#{user.id}" if user
    end
  end

  # Logout Endpoint (Remote logout via integration)
  # Limit: 20 logouts per minute per IP
  # Security: Prevents DoS via logout endpoint (destroys tokens)
  throttle('logout/ip', limit: 20, period: 1.minute) do |req|
    if req.path == '/auth/logout' && (req.delete? || req.get?)
      req.ip
    end
  end

  # OAuth Token Generation per User
  # Limit: 30 tokens per hour per user
  # Security: Prevents token flooding from compromised accounts
  throttle('oauth-tokens/user', limit: 30, period: 1.hour) do |req|
    if req.path == '/oauth/token' && req.post?
      user = req.env['warden']&.user
      "oauth-tokens:user:#{user.id}" if user
    end
  end

  # =============================================================================
  # LAYER 4: Global Protection (DDoS Prevention)
  # =============================================================================
  # Purpose: Safety net to prevent resource exhaustion from any source

  # Global request limit per IP
  # Limit: 300 requests per minute per IP (all endpoints)
  # Security: Prevents general DDoS and resource exhaustion
  # Note: This is more aggressive than previous config (was 300/5min, now 300/1min)
  throttle('global/ip', limit: 300, period: 1.minute) do |req|
    # Don't throttle static assets or health checks
    req.ip unless req.path.start_with?('/assets', '/health', '/up')
  end

  # API Endpoints (read-only operations)
  # Limit: 100 requests per minute per IP
  # Security: Protects API from scraping and abuse
  throttle('api/ip', limit: 100, period: 1.minute) do |req|
    if req.path.start_with?('/api')
      req.ip
    end
  end

  # API per authenticated user (more generous for legitimate users)
  # Limit: 200 requests per minute per user
  # Security: Allows higher limits for authenticated users
  throttle('api/user', limit: 200, period: 1.minute) do |req|
    if req.path.start_with?('/api') && req.env['warden']&.user
      user = req.env['warden'].user
      "api:user:#{user.id}"
    end
  end

  # =============================================================================
  # Custom Responses
  # =============================================================================

  # Customize the response when a request is throttled
  # Returns 429 (Too Many Requests) with standard rate limit headers
  self.throttled_responder = lambda do |request|
    match_data = request.env['rack.attack.match_data']
    now = match_data[:epoch_time]
    retry_after = match_data[:period] - (now % match_data[:period])

    headers = {
      'Content-Type' => 'application/json',
      'X-RateLimit-Limit' => match_data[:limit].to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + retry_after).to_s,
      'Retry-After' => retry_after.to_s
    }

    # Provide user-friendly error message
    # Security Note: Don't reveal specific rate limit details to prevent enumeration
    body = {
      error: 'rate_limit_exceeded',
      message: 'Too many requests. Please try again later.',
      retry_after_seconds: retry_after
    }

    [429, headers, [body.to_json]]
  end

  # Customize the response when a request is blocked
  # Returns 403 (Forbidden) for permanently blocked requests
  self.blocklisted_responder = lambda do |_env|
    body = {
      error: 'forbidden',
      message: 'Access denied. Your IP has been blocked due to suspicious activity.'
    }
    [403, { 'Content-Type' => 'application/json' }, [body.to_json]]
  end

  # =============================================================================
  # Logging and Monitoring
  # =============================================================================

  # Track requests for monitoring and analytics
  # Useful for identifying attack patterns and adjusting rate limits
  ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
    req = payload[:request]

    # Log all throttled and blocked requests with detailed information
    if [:throttle, :blocklist].include?(req.env['rack.attack.match_type'])
      # Extract email for authentication-related violations (for security logging)
      email = req.params['email'] || req.params.dig('user', 'email')

      # Security Event Logging - Critical for security monitoring and forensics
      Rails.logger.warn(
        "[SECURITY] Rack::Attack #{req.env['rack.attack.match_type'].to_s.upcase}: " \
        "Rule='#{req.env['rack.attack.matched']}' | " \
        "IP=#{req.ip} | " \
        "Path=#{req.path} | " \
        "Method=#{req.request_method} | " \
        "#{email.present? ? "Email=#{email} | " : ''}" \
        "User-Agent='#{req.user_agent}' | " \
        "Timestamp=#{Time.current.iso8601}"
      )

      # Increment violation counter for exponential backoff
      # This tracks repeat offenders across the application
      violations_key = "violations:#{req.ip}"
      current_violations = Rack::Attack.cache.read(violations_key).to_i
      Rack::Attack.cache.store.write(violations_key, current_violations + 1, expires_in: 1.hour.to_i)

      # Log severe violations to a separate security log for alerting
      # Security teams can monitor this for patterns indicating coordinated attacks
      if current_violations > 5
        Rails.logger.error(
          "[SECURITY ALERT] Repeat offender detected: " \
          "IP=#{req.ip} has #{current_violations} violations in the last hour. " \
          "Consider adding to BLOCKED_IPS environment variable."
        )
      end
    end
  end

  # =============================================================================
  # Failed Login Tracking
  # =============================================================================
  # Track failed login attempts and clear counters on successful login
  # This enables smart rate limiting that only throttles failed attempts

  # Increment failed login counter after each failed authentication
  # This is called by the track block when a login fails
  ActiveSupport::Notifications.subscribe('warden.authentication:failure') do |name, start, finish, request_id, payload|
    req = payload[:env]['rack.input']
    email = payload.dig(:options, :email) || payload.dig(:params, 'email') || payload.dig(:params, 'user', 'email')

    if email.present?
      # Increment failed login counter for this email
      failed_key = "failed-login:#{email.downcase}"
      failures = Rack::Attack.cache.read(failed_key).to_i
      Rack::Attack.cache.store.write(failed_key, failures + 1, expires_in: 20.minutes.to_i)

      # Log failed authentication attempt for security monitoring
      Rails.logger.warn(
        "[SECURITY] Failed login attempt: " \
        "Email=#{email} | " \
        "IP=#{payload[:env]['REMOTE_ADDR']} | " \
        "Attempts=#{failures + 1} | " \
        "Timestamp=#{Time.current.iso8601}"
      )
    end
  end

  # Clear failed login counter on successful authentication
  # This ensures legitimate users aren't penalized after a successful login
  ActiveSupport::Notifications.subscribe('warden.authentication:success') do |name, start, finish, request_id, payload|
    user = payload[:user]
    if user && user.email.present?
      # Clear all failed login counters for this email
      failed_key = "failed-login:#{user.email.downcase}"
      Rack::Attack.cache.delete(failed_key)

      # Log successful authentication (informational)
      Rails.logger.info(
        "[AUTH] Successful login: " \
        "User=#{user.id} | " \
        "Email=#{user.email} | " \
        "IP=#{payload[:env]['REMOTE_ADDR']} | " \
        "Timestamp=#{Time.current.iso8601}"
      )
    end
  end
end

# =============================================================================
# Testing Rack::Attack in Development
# =============================================================================
#
# To test rate limiting in development:
#
# 1. Enable Rack::Attack in development:
#    - Set RACK_ATTACK_ENABLED=true in your .env file
#    - Restart the Rails server
#
# 2. Test failed login throttle (5 failed attempts per 20 minutes per email):
#    for i in {1..6}; do curl -X POST http://localhost:3231/users/sign_in \
#      -d "user[email]=test@example.com" -d "user[password]=wrong"; done
#    Expected: 6th attempt returns 429 (Too Many Requests)
#
# 3. Test OAuth token endpoint throttle (20 requests per minute per IP):
#    for i in {1..21}; do curl -X POST http://localhost:3231/oauth/token \
#      -d "grant_type=client_credentials"; done
#    Expected: 21st attempt returns 429
#
# 4. Test password reset throttle (3 requests per hour per email):
#    for i in {1..4}; do curl -X POST http://localhost:3231/users/password \
#      -d "user[email]=test@example.com"; done
#    Expected: 4th attempt returns 429
#
# 5. Test registration throttle (5 registrations per hour per IP):
#    for i in {1..6}; do curl -X POST http://localhost:3231/users \
#      -d "user[email]=test$i@example.com" -d "user[password]=password"; done
#    Expected: 6th attempt returns 429
#
# 6. Test company switching throttle (10 switches per minute per user):
#    - Requires authenticated session/JWT token
#    - Make 11 POST requests to /auth/switch_company
#    Expected: 11th attempt returns 429
#
# 7. Test global IP throttle (300 requests per minute per IP):
#    for i in {1..301}; do curl http://localhost:3231/; done
#    Expected: 301st attempt returns 429
#
# 8. Monitor security logs in real-time:
#    tail -f log/development.log | grep -E "\[SECURITY\]|\[AUTH\]|Rack::Attack"
#
# 9. Test exponential backoff for repeat offenders:
#    - Trigger multiple different rate limits from same IP
#    - After 10 violations, IP should be temporarily blocked
#    - Check logs for [SECURITY ALERT] messages
#
# 10. Verify failed login counter reset on successful login:
#     - Make 4 failed login attempts (below threshold)
#     - Make 1 successful login attempt
#     - Counter should reset - can make 5 more failed attempts
#
# SECURITY MONITORING TIPS:
# - Monitor logs for patterns: multiple IPs targeting same email = credential stuffing
# - Monitor logs for patterns: single IP targeting multiple emails = brute force
# - Monitor [SECURITY ALERT] messages for coordinated attacks
# - Consider implementing alerting for rate limit violations in production
#
# ENVIRONMENT VARIABLES FOR TESTING:
# - RACK_ATTACK_ENABLED=true          # Enable rate limiting
# - WHITELISTED_IPS=127.0.0.1         # Whitelist your IP during testing
# - BLOCKED_IPS=192.168.1.100         # Test IP blocking
# - REDIS_URL=redis://localhost:6379  # Required in production
#
# =============================================================================
