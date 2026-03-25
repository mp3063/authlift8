class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Store request_id in Current for propagation to inter-service HTTP calls
  before_action :set_current_request_id

  private

  # Store the request_id from Rails' ActionDispatch::RequestId middleware
  # into Current so inter-service HTTP clients can forward it.
  def set_current_request_id
    Current.request_id = request.request_id
  end

  public

  def append_info_to_payload(payload)
    super
    payload[:user_id] = current_user&.id
    payload[:company_id] = current_user&.current_company&.id
  end
end
