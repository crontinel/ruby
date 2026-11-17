# Changelog

All notable changes will be documented in this file.

## [0.1.1] - 2026-11-17

- `Crontinel.client` reads `CRONTINEL_API_KEY` and `CRONTINEL_API_URL` when no argument is given
- `task_started` no longer records a finished run; it sends nothing
- `task_failed` always sends exit code 1

## [0.1.0] - 2026-04-18

- Initial release
- Task tracking: `task_started`, `task_finished`, `task_failed`
- Worker heartbeat support
- Faraday-based HTTP client
- Minitest test suite
- Rubocop linting
