# Crontinel Ruby

Ruby SDK for [Crontinel](https://crontinel.com) — open-source monitoring for cron jobs, background workers, and scheduled tasks.

Unlike generic uptime tools, Crontinel knows when a job started but crashed silently, when a queue worker stopped processing, or when a cron fired but did nothing.

## Installation

Add to your `Gemfile`:

```ruby
gem "crontinel", "~> 0.1"
```

Or install directly:

```bash
gem install crontinel
```

## Quick Start

```ruby
require "crontinel"

# Configure with your API key
client = Crontinel.client(api_key: "your_api_key_here")

# Record a cron job starting
client.task_started(name: "send-daily-summary")

# Do your work...
result = send_daily_summary

# Record success
client.task_finished(name: "send-daily-summary", duration_ms: 520)
```

### With error handling

```ruby
client = Crontinel.client(api_key: ENV["CRONTINEL_API_KEY"])

begin
  client.task_started(name: "process-invoices")
  process_invoices
  client.task_finished(name: "process-invoices", duration_ms: 3200)
rescue => e
  client.task_failed(name: "process-invoices", error: e.message, duration_ms: 150)
  raise
end
```

### Worker heartbeat

For queue workers (Sidekiq, etc.):

```ruby
worker = Crontinel.client(api_key: ENV["CRONTINEL_API_KEY"])

# In your worker loop or at intervals
worker.worker_heartbeat(
  name: "email-worker",
  status: "running",
  jobs_processed: 142,
  jobs_failed: 2,
  memory_mb: 128
)
```

## Configuration

```ruby
client = Crontinel.client do |config|
  config.api_key = ENV["CRONTINEL_API_KEY"]
  config.endpoint = "https://app.crontinel.com/api/v1" # optional, default works for hosted
  config.timeout = 10       # seconds, default: 10
  config.open_timeout = 5    # seconds, default: 5
end
```

## API

### `Crontinel.client(api_key:, endpoint: nil)`

Create a new Crontinel client.

### `#task_started(name:, output: nil)`

Record that a task began execution.

### `#task_finished(name:, output: nil, duration_ms: nil)`

Record that a task completed successfully.

### `#task_failed(name:, error: nil, output: nil, duration_ms: nil)`

Record that a task failed.

### `#worker_heartbeat(name:, status:, jobs_processed: nil, jobs_failed: nil, memory_mb: nil)`

Send a heartbeat for a queue worker.

### `#task_runs(name:, limit: 10)`

Get recent task runs. Returns an array of `Crontinel::TaskRun` objects.

### `#health_check`

Returns `true` if Crontinel is reachable, `false` otherwise.

## Supported Ruby Versions

Ruby 2.7+

## License

MIT © Harun R Rayhan
