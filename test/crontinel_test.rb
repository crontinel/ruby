# frozen_string_literal: true

require "minitest/autorun"
require "minitest/reporters"
require "crontinel"

Minitest::Reporters.use!

describe Crontinel do
  describe ".client" do
    it "creates a client with an api key" do
      client = Crontinel.client(api_key: "test_key_123")
      assert_kind_of Crontinel::Client, client
      assert_equal "test_key_123", client.config.api_key
    end

    it "yields the config block" do
      client = Crontinel.client do |config|
        config.api_key = "block_key"
      end
      assert_equal "block_key", client.config.api_key
    end
  end
end

describe Crontinel::Config do
  describe "#validate!" do
    it "raises when api_key is nil" do
      config = Crontinel::Config.new
      assert_raises(Crontinel::ConfigurationError) { config.validate! }
    end

    it "raises when api_key is empty" do
      config = Crontinel::Config.new
      config.api_key = ""
      assert_raises(Crontinel::ConfigurationError) { config.validate! }
    end

    it "does not raise when api_key is set" do
      config = Crontinel::Config.new
      config.api_key = "valid_key"
      config.validate! # should not raise
    end
  end
end

describe Crontinel::TaskRun do
  it "parses attributes correctly" do
    run = Crontinel::TaskRun.new(
      "id" => "123",
      "name" => "send-report",
      "status" => "success",
      "started_at" => "2026-04-18T10:00:00Z",
      "finished_at" => "2026-04-18T10:00:05Z",
      "duration_ms" => 5000,
      "output" => "Report sent to 50 users"
    )

    assert_equal "123", run.id
    assert_equal "send-report", run.name
    assert_equal "success", run.status
    assert run.success?
    refute run.failed?
    refute run.running?
    assert_equal 5000, run.duration_ms
  end

  it "detects failed status" do
    run = Crontinel::TaskRun.new("status" => "failed", "name" => "job")
    assert run.failed?
    refute run.success?
  end
end

describe Crontinel::WorkerState do
  it "parses worker attributes" do
    worker = Crontinel::WorkerState.new(
      "name" => "email-worker",
      "status" => "running",
      "jobs_processed" => 500,
      "jobs_failed" => 3,
      "memory_mb" => 256
    )

    assert_equal "email-worker", worker.name
    assert worker.alive?
    assert_equal 500, worker.jobs_processed
    assert_equal 3, worker.jobs_failed
    assert_equal 256, worker.memory_mb
  end

  it "detects dead workers" do
    worker = Crontinel::WorkerState.new("name" => "dead-worker", "status" => "stopped")
    refute worker.alive?
  end
end
