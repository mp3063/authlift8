# frozen_string_literal: true

# =============================================================================
# SecureHeaders - HTTP Security Headers Configuration
# =============================================================================
#
# SecureHeaders automatically applies security headers to HTTP responses.
# These headers protect against common web vulnerabilities including:
# - Clickjacking attacks (X-Frame-Options)
# - MIME-sniffing attacks (X-Content-Type-Options)
# - Cross-Site Scripting (Content-Security-Policy, X-XSS-Protection)
# - Information leakage (Referrer-Policy)
#
# Documentation: https://github.com/github/secure_headers
#
# OWASP Secure Headers Project:
# https://owasp.org/www-project-secure-headers/
# =============================================================================

SecureHeaders::Configuration.default do |config|
  # =============================================================================
  # X-Frame-Options: DENY
  # =============================================================================
  # Prevents the page from being displayed in an iframe/frame/object
  # Protection against: Clickjacking attacks
  #
  # Options:
  #   - DENY: Page cannot be displayed in a frame (most secure)
  #   - SAMEORIGIN: Page can only be displayed in a frame on the same origin
  #   - ALLOW-FROM uri: Page can only be displayed in a frame on the specified origin
  #
  # Use SAMEORIGIN if you need to embed your own pages in iframes
  config.x_frame_options = "DENY"

  # =============================================================================
  # X-Content-Type-Options: nosniff
  # =============================================================================
  # Prevents browsers from MIME-sniffing a response away from declared content-type
  # Protection against: Drive-by download attacks and MIME confusion attacks
  #
  # This forces browsers to respect the Content-Type header declared by the server
  config.x_content_type_options = "nosniff"

  # =============================================================================
  # X-XSS-Protection: 1; mode=block
  # =============================================================================
  # Enables browser's XSS filtering and blocks the page if attack is detected
  # Protection against: Reflected XSS attacks
  #
  # Options:
  #   - 0: Disable XSS filtering
  #   - 1: Enable XSS filtering (sanitize the page)
  #   - 1; mode=block: Enable XSS filtering and block the page entirely
  #
  # Note: Modern browsers rely more on CSP, but this provides defense in depth
  config.x_xss_protection = "1; mode=block"

  # =============================================================================
  # X-Download-Options: noopen
  # =============================================================================
  # Prevents Internet Explorer from executing downloads in the site's context
  # Protection against: Execution of malicious HTML/JS files in trusted context
  #
  # IE-specific header that prevents opening files directly in the browser
  config.x_download_options = "noopen"

  # =============================================================================
  # X-Permitted-Cross-Domain-Policies: none
  # =============================================================================
  # Controls how Adobe Flash/PDF handle cross-domain requests
  # Protection against: Cross-domain data loading vulnerabilities
  #
  # Options:
  #   - none: No cross-domain access allowed
  #   - master-only: Only allow master policy file
  #   - by-content-type: Only allow by content type
  #   - all: Allow all cross-domain access (not recommended)
  config.x_permitted_cross_domain_policies = "none"

  # =============================================================================
  # Referrer-Policy: strict-origin-when-cross-origin
  # =============================================================================
  # Controls how much referrer information is included with requests
  # Protection against: Information leakage through referrer headers
  #
  # Options (from most to least restrictive):
  #   - no-referrer: Never send referrer
  #   - same-origin: Send referrer only for same-origin requests
  #   - strict-origin: Send origin only for HTTPS→HTTPS
  #   - strict-origin-when-cross-origin: Full URL for same-origin, origin only for cross-origin HTTPS
  #   - unsafe-url: Always send full URL (not recommended)
  #
  # strict-origin-when-cross-origin is a good balance of privacy and functionality
  config.referrer_policy = "strict-origin-when-cross-origin"

  # =============================================================================
  # Content-Security-Policy (CSP)
  # =============================================================================
  # Controls which resources can be loaded and executed on your pages
  # Protection against: XSS, clickjacking, code injection, and data exfiltration
  #
  # CSP is the most powerful security header for preventing XSS attacks.
  # It works by whitelisting sources of content that browsers should allow.
  #
  # Directive Explanations:
  #   - default-src: Fallback for all fetch directives
  #   - script-src: Valid sources for JavaScript
  #   - style-src: Valid sources for CSS
  #   - img-src: Valid sources for images
  #   - font-src: Valid sources for fonts
  #   - connect-src: Valid sources for fetch, XHR, WebSocket
  #   - media-src: Valid sources for <audio>, <video>
  #   - object-src: Valid sources for <object>, <embed>
  #   - frame-src: Valid sources for frames
  #   - base-uri: Restricts URLs that can appear in <base>
  #   - form-action: Valid endpoints for form submissions
  #   - frame-ancestors: Valid parents for embedding via frame/iframe
  #
  # Special Keywords:
  #   - 'self': Same origin as the document
  #   - 'unsafe-inline': Allow inline scripts/styles (avoid if possible)
  #   - 'unsafe-eval': Allow eval() and similar (avoid if possible)
  #   - 'nonce-{random}': Allow specific inline scripts with matching nonce
  #   - 'strict-dynamic': Trust scripts with nonces, ignore whitelist
  #
  # IMPORTANT: This configuration needs customization based on your CDNs,
  # third-party services, and frontend build process.
  # =============================================================================

  config.csp = {
    # Preserve existing CSP headers from the application
    preserve_schemes: true,

    # Default policy for all resources
    # Start restrictive and add sources as needed
    default_src: %w['self'],

    # Script sources - JavaScript execution
    # Include your CDN, analytics, and frontend framework sources
    script_src: %w[
      'self'
      'unsafe-inline'
      https://cdn.jsdelivr.net
      https://unpkg.com
    ],

    # Style sources - CSS
    # Include your CDN and any external stylesheets
    style_src: %w[
      'self'
      'unsafe-inline'
      https://cdn.jsdelivr.net
      https://fonts.googleapis.com
    ],

    # Image sources
    # Include data: for inline images, https: for all HTTPS images
    img_src: %w[
      'self'
      data:
      https:
      http:
    ],

    # Font sources
    # Include Google Fonts and other font CDNs
    font_src: %w[
      'self'
      data:
      https://fonts.gstatic.com
      https://cdn.jsdelivr.net
    ],

    # AJAX, WebSocket, and EventSource connections
    # Include your API endpoints and third-party services
    connect_src: %w[
      'self'
      https://api.yourdomain.com
    ],

    # Media sources (audio/video)
    media_src: %w['self'],

    # Object sources (Flash, Java, etc.)
    # Set to 'none' to block plugins entirely (recommended)
    object_src: %w['none'],

    # Frame sources for iframes
    # Add trusted domains if you embed content
    frame_src: %w[
      'self'
      https://accounts.google.com
    ],

    # Base URI restriction
    # Prevents injection of <base> tags
    base_uri: %w['self'],

    # Form submission targets
    # Restrict where forms can submit data
    form_action: %w[
      'self'
      https://accounts.google.com
    ],

    # Frame ancestors (who can embed this page)
    # This is a more modern alternative to X-Frame-Options
    # Set to 'none' to prevent all framing
    frame_ancestors: %w['none'],

    # Upgrade insecure requests to HTTPS
    upgrade_insecure_requests: true

    # Report violations to this endpoint (optional)
    # Useful for monitoring CSP violations in production
    # report_uri: %w[/csp-violation-report-endpoint],

    # Report-only mode - log violations without blocking (for testing)
    # Uncomment to test CSP changes without breaking functionality
    # report_only: true
  }

  # =============================================================================
  # HTTP Strict Transport Security (HSTS)
  # =============================================================================
  # Forces browsers to only access the site via HTTPS
  # Protection against: Protocol downgrade attacks and cookie hijacking
  #
  # Options:
  #   - max-age: How long (in seconds) to remember HTTPS-only rule
  #   - includeSubDomains: Apply to all subdomains
  #   - preload: Submit domain to browser preload lists
  #
  # WARNING: Be careful with HSTS settings:
  # - Start with a short max-age (e.g., 300 seconds) for testing
  # - Gradually increase to 31536000 (1 year) for production
  # - Only add includeSubDomains if ALL subdomains support HTTPS
  # - Only add preload after thorough testing (it's nearly irreversible)
  #
  # For development, HSTS is disabled by default
  # =============================================================================

  if Rails.env.production?
    config.hsts = {
      max_age: 31_536_000,      # 1 year in seconds
      include_subdomains: true, # Apply to all subdomains
      preload: true             # Submit to browser preload lists
    }
  else
    # Disable HSTS in development to avoid certificate issues
    config.hsts = SecureHeaders::OPT_OUT
  end

  # =============================================================================
  # Expect-CT (Certificate Transparency)
  # =============================================================================
  # Enforces Certificate Transparency requirements
  # Protection against: Fraudulent SSL certificates
  #
  # Note: This header is deprecated as Certificate Transparency is now
  # mandatory for all publicly trusted certificates. Modern browsers
  # no longer need this header. The expect_ct configuration has been
  # removed from secure_headers gem v7.0+
  # =============================================================================
  # config.expect_ct = SecureHeaders::OPT_OUT  # DEPRECATED - removed in v7.0+

  # =============================================================================
  # Custom Headers
  # =============================================================================
  # Add any custom security headers your application needs
  # =============================================================================

  # Permissions Policy (formerly Feature Policy)
  # Controls which browser features can be used
  # Uncomment and customize as needed:
  #
  # config.permissions_policy = {
  #   geolocation: %w['none'],
  #   camera: %w['none'],
  #   microphone: %w['none'],
  #   payment: %w['self'],
  #   usb: %w['none'],
  #   # Add other directives as needed
  # }

  # =============================================================================
  # Environment-Specific Overrides
  # =============================================================================

  # You can override settings for specific environments or controllers
  # using named configurations:
  #
  # SecureHeaders::Configuration.override(:api) do |config|
  #   config.x_frame_options = SecureHeaders::OPT_OUT
  # end
  #
  # Then use in controller:
  # class ApiController < ApplicationController
  #   use_secure_headers_override :api
  # end
end

# =============================================================================
# Testing Security Headers
# =============================================================================
#
# 1. Check headers in development:
#    curl -I http://localhost:3000
#
# 2. Test with online tools:
#    - https://securityheaders.com
#    - https://observatory.mozilla.org
#
# 3. Verify CSP in browser console:
#    - Open DevTools > Console
#    - Look for CSP violation warnings
#    - Adjust policy to allow legitimate resources
#
# 4. Test HSTS:
#    curl -I https://yourdomain.com | grep -i strict
#
# 5. Validate with OWASP ZAP or similar security scanner
#
# =============================================================================
#
# Common CSP Violations and Solutions:
#
# 1. Inline Scripts Blocked:
#    - Use external .js files instead of <script> tags
#    - OR add 'unsafe-inline' (less secure)
#    - OR use nonces: <%= javascript_tag nonce: true %>
#
# 2. External Resources Blocked:
#    - Add the domain to the appropriate directive
#    - Example: Add 'https://cdn.example.com' to script-src
#
# 3. Eval Blocked:
#    - Avoid eval(), new Function(), setTimeout with strings
#    - OR add 'unsafe-eval' (less secure)
#
# 4. Google Analytics/Tag Manager:
#    script-src: https://www.googletagmanager.com https://www.google-analytics.com
#    img-src: https://www.google-analytics.com
#    connect-src: https://www.google-analytics.com
#
# =============================================================================
