Gem::Specification.new do |spec|
  spec.name = "crontinel"
  spec.version = Crontinel::VERSION
  spec.authors = ["Harun R Rayhan"]
  spec.email = ["me@harunray.com"]
  spec.summary = "Crontinel monitoring SDK for Ruby — track cron jobs and background workers"
  spec.description = <<~DESC
    Crontinel monitors your cron jobs, background workers, and scheduled tasks.
    Unlike generic uptime tools, Crontinel knows when a job started but crashed silently,
    when a queue worker stopped processing, or when a cron fired but did nothing.
  DESC
  spec.homepage = "https://crontinel.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/crontinel/ruby",
    "changelog_uri" => "https://github.com/crontinel/ruby/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/crontinel/ruby/issues"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.require_path = "lib"

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "concurrent-ruby", "~> 1.0"

  spec.add_development_dependency "bundler", ">= 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "minitest-reporters", "~> 1.0"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "rubocop-minitest", "~> 0.30"
end
