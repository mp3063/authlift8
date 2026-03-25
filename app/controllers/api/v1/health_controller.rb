# frozen_string_literal: true

module Api
  module V1
    class HealthController < ActionController::API
      # No authentication required for health checks

      # GET /api/v1/health
      # Basic liveness check — returns 200 if the app is running
      def show
        render json: {
          status: "ok",
          service: "authlift8",
          timestamp: Time.current.iso8601,
          version: "1.0.0",
          rails_version: Rails::VERSION::STRING,
          ruby_version: RUBY_VERSION
        }
      end

      # GET /api/v1/health/ready
      # Readiness check — verifies database, Redis, and Solid Queue
      def ready
        checks = {
          database: check_database,
          redis: check_redis,
          queue: check_queue
        }

        all_ok = checks.values.all? { |v| v == "ok" }

        render json: {
          status: all_ok ? "ok" : "degraded",
          service: "authlift8",
          checks: checks,
          timestamp: Time.current.iso8601
        }, status: all_ok ? :ok : :service_unavailable
      end

      private

      def check_database
        ActiveRecord::Base.connection.execute("SELECT 1")
        "ok"
      rescue StandardError => e
        Rails.logger.error "Health check: database failed — #{e.message}"
        "fail"
      end

      def check_redis
        return "skip" unless ENV["REDIS_URL"].present?

        redis = Redis.new(url: ENV["REDIS_URL"])
        redis.ping == "PONG" ? "ok" : "fail"
      rescue StandardError => e
        Rails.logger.error "Health check: redis failed — #{e.message}"
        "fail"
      ensure
        redis&.close
      end

      def check_queue
        if defined?(SolidQueue)
          SolidQueue::Process.count
          "ok"
        else
          "skip"
        end
      rescue StandardError => e
        Rails.logger.error "Health check: queue failed — #{e.message}"
        "fail"
      end
    end
  end
end
