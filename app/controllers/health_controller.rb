# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token

  # GET /up
  # Health check endpoint for load balancers and uptime monitors
  # Returns 200 if the app is healthy, 503 if there are issues
  def show
    # Check database connection
    database_healthy = check_database

    # Check Redis connection (if using Redis)
    redis_healthy = check_redis

    # Overall health status
    healthy = database_healthy && redis_healthy

    status_code = healthy ? :ok : :service_unavailable

    render json: {
      status: healthy ? "healthy" : "unhealthy",
      timestamp: Time.current.iso8601,
      version: Rails.application.config.version || "unknown",
      services: {
        database: database_healthy ? "up" : "down",
        redis: redis_healthy ? "up" : "down"
      }
    }, status: status_code
  rescue StandardError => e
    Rails.logger.error "Health check error: #{e.message}"
    render json: {
      status: "unhealthy",
      error: e.message,
      timestamp: Time.current.iso8601
    }, status: :service_unavailable
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute("SELECT 1")
    true
  rescue StandardError => e
    Rails.logger.error "Database health check failed: #{e.message}"
    false
  end

  def check_redis
    # Skip Redis check if not configured
    return true unless defined?(Redis)
    return true unless ENV["REDIS_URL"].present?

    redis = Redis.new(url: ENV["REDIS_URL"])
    redis.ping == "PONG"
  rescue StandardError => e
    Rails.logger.error "Redis health check failed: #{e.message}"
    false
  ensure
    redis&.close
  end
end
