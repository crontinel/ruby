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
      @endpoint = "https://app.crontinel.com/api/v1"
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
      @name = attrs["name"]
      @started_at = attrs["started_at"] ? Time.parse(attrs["started_at"]) : nil
      @finished_at = attrs["finished_at"] ? Time.parse(attrs["finished_at"]) : nil
      @status = attrs["status"] || "unknown"
      @duration_ms = attrs["duration_ms"]
      @output = attrs["output"]
    end

    def success?
      @status == "success"
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
      @jobs_processed = attrs["jobs_processed"] || 0
      @jobs_failed = attrs["jobs_failed"] || 0
      @memory_mb = attrs["memory_mb"]
    end

    def alive?
      @status == "running" || @status == "active"
    end
  end

  # Main Crontinel client
  class Client
    attr_reader :config

    def initialize(api_key: nil, endpoint: nil)
      @config = Config.new
      @config.api_key = api_key if api_key
      @config.endpoint = endpoint if endpoint
      yield @config if block_given?
      @config.validate!
    end

    # Record a scheduled task starting
    def task_started(name:, output: nil)
      record(name: name, status: "started", output: output)
    end

    # Record a scheduled task completing successfully
    def task_finished(name:, output: nil, duration_ms: nil)
      record(name: name, status: "success", output: output, duration_ms: duration_ms)
    end

    # Record a scheduled task failing
    def task_failed(name:, error: nil, output: nil, duration_ms: nil)
      record(name: name, status: "failed", error: error, output: output, duration_ms: duration_ms)
    end

    # Record a queue worker heartbeat
    def worker_heartbeat(name:, status: "running", jobs_processed: nil, jobs_failed: nil, memory_mb: nil)
      post("/worker/heartbeat", {
        name: name,
        status: status,
        jobs_processed: jobs_processed,
        jobs_failed: jobs_failed,
        memory_mb: memory_mb
      }.compact)
    end

    # Get recent task runs
    def task_runs(name:, limit: 10)
      get("/tasks/#{URI.encode_www_form_component(name)}/runs?limit=#{limit}").map { |attrs| TaskRun.new(attrs) }
    end

    # Get worker state
    def worker_state(name:)
      attrs = get("/workers/#{URI.encode_www_form_component(name)}")
      WorkerState.new(attrs)
    end

    # Check if Crontinel is reachable
    def health_check
      get("/health")
      true
    rescue NetworkError
      false
    end

    private

    def record(name:, status:, output: nil, error: nil, duration_ms: nil)
      post("/tasks/record", {
        name: name,
        status: status,
        output: output,
        error: error,
        duration_ms: duration_ms,
        started_at: Time.now.utc.iso8601(3)
      }.compact)
    end

    def get(path)
      request(:get, path)
    end

    def post(path, body)
      request(:post, path, body)
    end

    def request(method, path, body = nil)
      uri = URI("#{@config.endpoint}#{path}")
      req = method == :get ? Net::HTTP::Get.new(uri) : Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{@config.api_key}"
      req["Content-Type"] = "application/json"
      req.body = JSON.generate(body) if body

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @config.open_timeout
      http.read_timeout = @config.timeout

      response = http.start { http.request(req) }

      case response
      when Net::HTTPSuccess
        JSON.parse(response.body)
      else
        raise NetworkError, "Crontinel API error: #{response.code} #{response.message}"
      end
    rescue *[
        Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout,
        SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET
      ] => e
      raise NetworkError, "Failed to connect to Crontinel: #{e.message}"
    end
  end

  class << self
    def client(api_key: nil, endpoint: nil, &block)
      Client.new(api_key: api_key, endpoint: endpoint, &block)
    end
  end
end
