# frozen_string_literal: true

version = File.read(File.expand_path("../lib/crontinel/version.rb", __FILE__))[/VERSION\s*=\s*['"]([^'"]+)['"]/, 1]

Gem::Specification.new do |spec|
  spec.name = "crontinel"
  spec.version = version
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
end
