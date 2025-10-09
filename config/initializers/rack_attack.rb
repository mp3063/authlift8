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
# IMPORTANT: This configuration uses Redis for distributed rate limiting.
# Ensure Redis is configured and running in production.
#
# Environment Variables:
# - RACK_ATTACK_ENABLED: Set to 'false' to disable in development (default: true)
# - REDIS_URL: Redis connection URL for distributed rate limiting
# =============================================================================

class Rack::Attack
  # =============================================================================
  # Configuration
  # =============================================================================

  # Enable/disable Rack::Attack (useful for development)
  # Set RACK_ATTACK_ENABLED=false in .env to disable
  Rack::Attack.enabled = ENV.fetch('RACK_ATTACK_ENABLED', 'true') == 'true'

  # Configure Redis for distributed rate limiting across multiple servers
  # In production, this ensures rate limits work correctly with multiple app instances
  if Rails.env.production? || Rails.env.staging?
    Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
      url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
      namespace: 'rack_attack'
    )
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

  # =============================================================================
  # Blocklist (Blacklist) - Permanently block malicious IPs
  # =============================================================================

  # Block requests from known bad IPs
  # Add malicious IPs to BLOCKED_IPS environment variable (comma-separated)
  # Example: BLOCKED_IPS=192.168.1.1,10.0.0.1
  blocklist('block-malicious-ips') do |req|
    blocked_ips = ENV.fetch('BLOCKED_IPS', '').split(',').map(&:strip)
    blocked_ips.include?(req.ip)
  end

  # Block requests with suspicious user agents (common bots/scanners)
  blocklist('block-bad-user-agents') do |req|
    suspicious_agents = [
      'masscan', 'nmap', 'nikto', 'sqlmap', 'curl', 'wget',
      'python-requests', 'go-http-client', 'scrapy'
    ]
    user_agent = req.user_agent.to_s.downcase
    suspicious_agents.any? { |agent| user_agent.include?(agent) }
  end

  # =============================================================================
  # Throttles - Rate Limiting Rules
  # =============================================================================

  # -----------------------------------------------------------------------------
  # 1. General Request Throttle - All Requests by IP
  # -----------------------------------------------------------------------------
  # Limit: 300 requests per 5 minutes per IP
  # Purpose: Prevent general abuse and resource exhaustion
  # Note: This is a safety net for all requests not covered by specific throttles
  throttle('requests/ip', limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?('/assets') # Don't throttle static assets
  end

  # -----------------------------------------------------------------------------
  # 2. OAuth2 Endpoints - Strict Rate Limiting
  # -----------------------------------------------------------------------------
  # Limit: 20 requests per 5 minutes per IP
  # Purpose: Prevent brute force attacks on OAuth2 token endpoints
  # Covers: /oauth/token, /oauth/authorize, /oauth/revoke
  throttle('oauth2/ip', limit: 20, period: 5.minutes) do |req|
    if req.path.start_with?('/oauth')
      req.ip
    end
  end

  # -----------------------------------------------------------------------------
  # 3. Login Attempts - Email-Based Throttling
  # -----------------------------------------------------------------------------
  # Limit: 5 attempts per 20 minutes per email
  # Purpose: Prevent credential stuffing and password guessing attacks
  # Tracks: Failed login attempts by email address
  throttle('logins/email', limit: 5, period: 20.minutes) do |req|
    if req.path == '/users/sign_in' && req.post?
      # Extract email from form data (works with both form and JSON requests)
      email = req.params['email'] || req.params.dig('user', 'email')
      email.to_s.downcase.presence # Return email as the discriminator
    end
  end

  # Additional login throttle by IP to prevent distributed attacks
  # Limit: 10 login attempts per 20 minutes per IP
  throttle('logins/ip', limit: 10, period: 20.minutes) do |req|
    if req.path == '/users/sign_in' && req.post?
      req.ip
    end
  end

  # -----------------------------------------------------------------------------
  # 4. API Endpoints - Standard Rate Limiting
  # -----------------------------------------------------------------------------
  # Limit: 100 requests per minute per IP
  # Purpose: Prevent API abuse while allowing legitimate usage
  # Covers: All /api/* endpoints
  throttle('api/ip', limit: 100, period: 1.minute) do |req|
    if req.path.start_with?('/api')
      req.ip
    end
  end

  # API throttle by user ID for authenticated requests
  # Limit: 200 requests per minute per user (more generous than IP-based)
  throttle('api/user', limit: 200, period: 1.minute) do |req|
    if req.path.start_with?('/api') && req.env['warden']&.user
      req.env['warden'].user.id
    end
  end

  # -----------------------------------------------------------------------------
  # 5. Integration Endpoints - Auth Operations Throttling
  # -----------------------------------------------------------------------------
  # Limit: 50 requests per 5 minutes per IP
  # Purpose: Prevent abuse of user registration, password reset, and verification
  # Covers: Registration, password reset, email confirmation, unlock
  throttle('integrations/auth/ip', limit: 50, period: 5.minutes) do |req|
    auth_paths = [
      '/users/sign_up',           # Registration
      '/users/password/new',      # Password reset request
      '/users/password/edit',     # Password reset form
      '/users/confirmation/new',  # Resend confirmation
      '/users/unlock/new'         # Unlock account
    ]

    if auth_paths.any? { |path| req.path.start_with?(path) } && req.post?
      req.ip
    end
  end

  # Additional throttle for password reset by email
  # Limit: 3 requests per hour per email
  # Purpose: Prevent email bombing and abuse
  throttle('password-reset/email', limit: 3, period: 1.hour) do |req|
    if req.path == '/users/password' && req.post?
      email = req.params['email'] || req.params.dig('user', 'email')
      email.to_s.downcase.presence
    end
  end

  # -----------------------------------------------------------------------------
  # 6. Registration Throttling
  # -----------------------------------------------------------------------------
  # Limit: 5 registrations per hour per IP
  # Purpose: Prevent automated account creation and abuse
  throttle('registrations/ip', limit: 5, period: 1.hour) do |req|
    if req.path == '/users' && req.post?
      req.ip
    end
  end

  # =============================================================================
  # Custom Responses
  # =============================================================================

  # Customize the response when a request is throttled
  self.throttled_responder = lambda do |env|
    match_data = env['rack.attack.match_data']
    now = match_data[:epoch_time]

    headers = {
      'Content-Type' => 'application/json',
      'X-RateLimit-Limit' => match_data[:limit].to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + (match_data[:period] - now % match_data[:period])).to_s
    }

    body = {
      error: 'rate_limit_exceeded',
      message: 'Too many requests. Please try again later.',
      retry_after: match_data[:period] - (now % match_data[:period])
    }

    [429, headers, [body.to_json]]
  end

  # Customize the response when a request is blocked
  self.blocklisted_responder = lambda do |_env|
    [403, { 'Content-Type' => 'application/json' }, [{ error: 'forbidden', message: 'Access denied' }.to_json]]
  end

  # =============================================================================
  # Logging and Monitoring
  # =============================================================================

  # Track requests for monitoring and analytics
  # Useful for identifying attack patterns and adjusting rate limits
  ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
    req = payload[:request]

    # Log throttled requests
    if [:throttle, :blocklist].include?(req.env['rack.attack.match_type'])
      Rails.logger.warn(
        "Rack::Attack #{req.env['rack.attack.match_type']}: " \
        "#{req.env['rack.attack.matched']} | " \
        "IP: #{req.ip} | " \
        "Path: #{req.path} | " \
        "User-Agent: #{req.user_agent}"
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
# 1. Ensure RACK_ATTACK_ENABLED=true in your .env file
#
# 2. Test general throttle (300 req/5min):
#    for i in {1..301}; do curl http://localhost:3000/; done
#
# 3. Test OAuth throttle (20 req/5min):
#    for i in {1..21}; do curl -X POST http://localhost:3000/oauth/token; done
#
# 4. Test login throttle (5 req/20min):
#    for i in {1..6}; do curl -X POST http://localhost:3000/users/sign_in \
#      -d "user[email]=test@example.com" -d "user[password]=wrong"; done
#
# 5. Check logs for Rack::Attack warnings:
#    tail -f log/development.log | grep "Rack::Attack"
#
# =============================================================================
