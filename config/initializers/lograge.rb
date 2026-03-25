Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  config.lograge.custom_options = lambda do |event|
    {
      time: Time.current.iso8601,
      host: Socket.gethostname,
      service: "authlift8",
      request_id: event.payload[:headers]&.fetch("action_dispatch.request_id", nil),
      user_id: event.payload[:user_id],
      company_id: event.payload[:company_id]
    }
  end
end
