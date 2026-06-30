# frozen_string_literal: true

require "net/http"
require "json"
require "time"
require "crontinel/version"

module Crontinel
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class NetworkError < Error; end

  # Configuration for the Crontinel client
  class Config
    attr_accessor :api_key, :endpoint, :timeout, :open_timeout

    def initialize
      @api_key = nil
      @endpoint = "https://app.crontinel.com"
      @timeout = 10
      @open_timeout = 5
    end

    def validate!
      raise ConfigurationError, "api_key is required" if api_key.nil? || api_key.to_s.strip.empty?
    end
  end

  # Represents a single scheduled task / cron job run
  class TaskRun
    attr_reader :id, :name, :started_at, :finished_at, :status, :duration_ms, :output

    def initialize(attrs = {})
      @id = attrs["id"]
      @name = attrs["command"] || attrs["name"]
      @started_at = attrs["started_at"] ? Time.parse(attrs["started_at"]) : nil
      @finished_at = attrs["finished_at"] ? Time.parse(attrs["finished_at"]) : nil
      @status = attrs["last_status"] || attrs["status"] || "unknown"
      @duration_ms = attrs["duration_ms"]
      @output = attrs["output"]
    end

    def success?
      @status == "completed" || @status == "success"
    end

    def failed?
      @status == "failed"
    end

    def running?
      @status == "running"
    end
  end

  # Represents a worker's current state
  class WorkerState
    attr_reader :name, :status, :jobs_processed, :jobs_failed, :memory_mb

    def initialize(attrs = {})
      @name = attrs["name"]
      @status = attrs["status"] || "unknown"
      @jobs_processed = attrs["processed"] || attrs["jobs_processed"] || 0
      @jobs_failed = attrs["failed"] || attrs["jobs_failed"] || 0
      @memory_mb = attrs["memory_mb"]
    end

    def alive?
      @status == "running" || @status == "active"
    end
  end

  # Main Crontinel client
  class Client
    attr_reader :config

    NETWORK_ERRORS = [
      Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout,
      SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET
    ].freeze

    def initialize(api_key: nil, endpoint: nil)
      @config = Config.new
      @config.api_key = api_key if api_key
      @config.endpoint = endpoint if endpoint
      yield @config if block_given?
      @config.validate!
    end

    # ── Event reporting (uses MCP notify/*) ───────────────────

    # Record a scheduled task completing successfully
    def task_finished(name:, output: nil, duration_ms: nil)
      mcp_call("notify/schedule_run", {
        command: name,
        exit_code: 0,
        duration_ms: duration_ms,
        output: output,
        ran_at: Time.now.utc.iso8601(3),
        app: "ruby",
      })
    end

    # Record a scheduled task failing
    def task_failed(name:, error: nil, output: nil, duration_ms: nil)
      mcp_call("notify/schedule_run", {
        command: name,
        exit_code: error ? 1 : 1,
        duration_ms: duration_ms,
        output: output || error,
        ran_at: Time.now.utc.iso8601(3),
        app: "ruby",
      })
    end

    # Record a queue worker heartbeat / processed batch
    def worker_heartbeat(name:, status: "running", jobs_processed: nil, jobs_failed: nil, memory_mb: nil)
      mcp_call("notify/queue_processed", {
        queue: name,
        processed: jobs_processed || 0,
        failed: jobs_failed || 0,
        ran_at: Time.now.utc.iso8601(3),
        app: "ruby",
      }.compact)
    end

    # Send a custom event
    def event(key:, message:, state: "info", metadata: {})
      mcp_call("notify/event", {
        key: key,
        message: message,
        state: state,
        metadata: metadata,
        ran_at: Time.now.utc.iso8601(3),
        app: "ruby",
      })
    end

    # Send a Horizon snapshot
    def horizon_snapshot(supervisors:, failed_jobs_per_minute: 0, paused: false)
      mcp_call("notify/horizon_snapshot", {
        supervisors: supervisors,
        failed_jobs_per_minute: failed_jobs_per_minute,
        paused: paused,
        ran_at: Time.now.utc.iso8601(3),
        app: "ruby",
      })
    end

    # ── Query methods (uses MCP tools/call) ───────────────────

    # List all scheduled jobs
    def scheduled_jobs
      result = mcp_call("tools/call", { name: "list_scheduled_jobs", arguments: {} })
      (result["content"] || []).flat_map { |c| JSON.parse(c["text"]) rescue [] }.map { |r| TaskRun.new(r) }
    end

    # Get status for a specific cron command
    def cron_status(command:)
      result = mcp_call("tools/call", { name: "get_cron_status", arguments: { command: command } })
      (result["content"] || []).flat_map { |c| JSON.parse(c["text"]) rescue [] }.first
    end

    # List recent alerts
    def recent_alerts(hours: 24)
      result = mcp_call("tools/call", { name: "list_recent_alerts", arguments: { hours: hours } })
      (result["content"] || []).flat_map { |c| JSON.parse(c["text"]) rescue [] }
    end

    # Check if Crontinel is reachable (direct HTTP, not MCP)
    def health_check
      get("/health")
      true
    rescue NetworkError, JSON::ParserError
      false
    end

    # ── Backward-compatible aliases ───────────────────────────
    def task_started(name:, output: nil)
      task_finished(name: name, output: output)
    end

    def task_runs(name:, limit: 10)
      scheduled_jobs.select { |r| r.name&.include?(name) }.first(limit)
    end

    def worker_state(name:)
      WorkerState.new("name" => name, "status" => "unknown")
    end

    private

    # Unified MCP JSON-RPC call against /api/mcp
    def mcp_call(method, params = {})
      uri = URI("#{@config.endpoint}/api/mcp")

      body = {
        jsonrpc: "2.0",
        id: (Time.now.to_f * 1000).to_i,
        method: method,
        params: params,
      }

      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{@config.api_key}"
      req["Content-Type"] = "application/json"
      req.body = JSON.generate(body)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @config.open_timeout
      http.read_timeout = @config.timeout

      response = http.start { http.request(req) }

      case response
      when Net::HTTPSuccess
        data = JSON.parse(response.body)
        if data["error"]
          raise NetworkError, "Crontinel RPC error: #{data["error"]["code"]}: #{data["error"]["message"]}"
        end
        data["result"]
      else
        raise NetworkError, "Crontinel API error: #{response.code} #{response.message}"
      end
    rescue *NETWORK_ERRORS => e
      raise NetworkError, "Failed to connect to Crontinel: #{e.message}"
    end

    # Direct HTTP GET (for /health)
    def get(path)
      uri = URI("#{@config.endpoint}#{path}")
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{@config.api_key}"

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @config.open_timeout
      http.read_timeout = @config.timeout

      response = http.start { http.request(req) }

      case response
      when Net::HTTPSuccess
        begin
          JSON.parse(response.body)
        rescue JSON::ParserError
          response.body
        end
      else
        raise NetworkError, "Crontinel API error: #{response.code} #{response.message}"
      end
    rescue *NETWORK_ERRORS => e
      raise NetworkError, "Failed to connect to Crontinel: #{e.message}"
    end
  end

  class << self
    def client(api_key: nil, endpoint: nil, &block)
      Client.new(api_key: api_key, endpoint: endpoint, &block)
    end

    # Rails-style configure block (used by crontinel-rails railtie)
    def configure
      yield config
      config
    end
    alias_method :setup, :configure

    def config
      @config ||= Configuration.new
    end
  end

  # Configuration object for module-level setup
  class Configuration
    attr_accessor :api_key, :endpoint

    def initialize
      @api_key = ENV.fetch("CRONTINEL_API_KEY", nil)
      @endpoint = ENV.fetch("CRONTINEL_API_URL", "https://app.crontinel.com")
    end
  end
end
