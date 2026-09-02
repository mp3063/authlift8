# frozen_string_literal: true

# Bridge importmap-rails inline-script nonces to secure_headers' CSP nonce.
#
# importmap-rails renders two INLINE scripts in <%= javascript_importmap_tags %>:
# the <script type="importmap"> map and the <script type="module">import "application"
# </script> entry. It tags them with Rails' built-in nonce
# (request.content_security_policy_nonce — see importmap's importmap_tags_helper.rb).
#
# Our CSP header, however, is produced by the secure_headers gem, which maintains its
# OWN, separate nonce system. With the two unconnected, the inline scripts render with
# no nonce, our strict script-src (no 'unsafe-inline') refuses them, and Stimulus/Turbo
# never boot — breaking every Stimulus controller (dropdowns, modals, mobile nav, etc.).
#
# Pointing Rails' nonce generator at secure_headers' per-request script nonce makes the
# inline importmap/module tags carry a nonce that secure_headers ALSO appends to the
# script-src directive of the same response — so they're allowed while CSP stays strict.
#
# Notes:
# - Rails::Application#env_config injects this generator into every request's env, so no
#   Rails CSP policy is needed for request.content_security_policy_nonce to resolve.
# - secure_headers remains the sole CSP header; its presence makes Rails' own CSP
#   middleware a no-op (it bails when a CSP header is already present).
# - SecureHeaders is only referenced inside the lambda (evaluated per request), so there
#   is no initializer load-order dependency on secure_headers.rb.
Rails.application.config.content_security_policy_nonce_generator = lambda do |request|
  SecureHeaders.content_security_policy_script_nonce(request)
end
