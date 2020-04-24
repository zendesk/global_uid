# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (from 3.7.0 onwards).

## [Unreleased]

### Added
- [Breaking change] ID Validation, ensure the ID coming back has been incremented using the configured `auto_increment_increment`. (https://github.com/zendesk/global_uid/pull/63)
- `notify` is called before raising `NoServersAvailableException` (https://github.com/zendesk/global_uid/pull/71)

### Changed
- `with_connections` has been replaced by `with_servers` which contains the connection metadata (increment_by, timeout, allocations, etc) (https://github.com/zendesk/global_uid/pull/71)
- The `per_process_affinity` configuration has been replaced with `connection_shuffling`. The behaviour remains the same, but the default boolean value has flipped – e.g. if you had previously configured `per_process_affinity = false`, you should now set `connection_shuffling = true` to get the same behavior. `connection_shuffling` defaults to false.

### Removed
- Removed the `dry_run` option (https://github.com/zendesk/global_uid/pull/64)
- Removed `GlobalUid::ServerVariables` module (https://github.com/zendesk/global_uid/pull/66)
- Removed `options` parameter from `generate_uid` & `generate_many_uids` (https://github.com/zendesk/global_uid/pull/68)
- The following methods on `GlobalUid::Base` are no longer accessible as they're for internal use only (https://github.com/zendesk/global_uid/pull/71)
  - `GlobalUid::Base.setup_connections!`
  - `GlobalUid::Base.get_uid_for_class`
  - `GlobalUid::Base.get_many_uids_for_class`
  - `GlobalUid::Base.create_uid_tables`
  - `GlobalUid::Base.drop_uid_tables`
  - `GlobalUid::Base.get_connections`

## [3.7.1] - 2020-02-06
### Added
- Support for Rails 6.0. (https://github.com/zendesk/global_uid/pull/60)

### Removed
- Removed testing with Rails 5.0 and EOL Ruby 2.3 (https://github.com/zendesk/global_uid/pull/57/)

## <= [3.7.0]

Unwritten
