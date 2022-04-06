# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (from 3.7.0 onwards).

## [Unreleased]

## [4.2.0] - 2022-04-06
### Added
- Support for Ruby 3. (https://github.com/zendesk/global_uid/pull/92)

## [4.1.0] - 2021-01-14
### Added
- Support for Rails 6.1. (https://github.com/zendesk/global_uid/pull/90)

## [4.0.1] - 2020-09-10
### Fixed
 - `generate_many_ids(1)` would return the ID; It's now returned within an Array, fixing a breaking API change when clients upgraded from v3.x to v4.x. (https://github.com/zendesk/global_uid/pull/86)

## [4.0.0] - 2020-08-26

No changes, the release candidate has been used in production without issue.

A document on upgrading from 3.7.x to 4.0.0 [can be found here](https://github.com/zendesk/global_uid/blob/master/docs/upgrading-to-4-0.md).

## [4.0.0.rc1] - 2020-05-11
### Fixed
 - ID allocation validation now takes the table name into consideration. Prior to this change the server would allocate multiple IDs (e.g. 2 & 2) from different tables using global UIDs and incorrectly raise a InvalidIncrementException. (https://github.com/zendesk/global_uid/pull/81)

## [4.0.0.beta2] - 2020-04-30
### Added
- A `GlobalUid::TestSupport` module has been introduced to assist with creating, droppping and recreating ID tables. (https://github.com/zendesk/global_uid/pull/76)
- `GlobalUid.enabled?`, `GlobalUid.disabled?`, `GlobalUid.disable!` & `GlobalUid.enable!` helper methods added. (https://github.com/zendesk/global_uid/pull/77)

## [4.0.0.beta1] - 2020-04-27
### Added
- [Breaking change] ID Validation, ensure the ID coming back has been incremented using the configured `auto_increment_increment`. (https://github.com/zendesk/global_uid/pull/63)
- `notify` is called before raising `NoServersAvailableException` (https://github.com/zendesk/global_uid/pull/71)

### Changed
- [Breaking change] `with_connections` has been replaced by `with_servers` which contains the connection metadata (increment_by, timeout, allocations, etc) (https://github.com/zendesk/global_uid/pull/71)
- [Breaking change] The `per_process_affinity` configuration has been replaced with `connection_shuffling`. The behaviour remains the same, but the default boolean value has flipped – e.g. if you had previously configured `per_process_affinity = false`, you should now set `connection_shuffling = true` to get the same behavior. `connection_shuffling` defaults to false. (https://github.com/zendesk/global_uid/pull/72)
- [Breaking change] Move configuration to a class (https://github.com/zendesk/global_uid/pull/72)
- [Breaking change] The configured `notifier` proc is now called now only with an exception, rather than an exception and a message. (https://github.com/zendesk/global_uid/pull/73)

### Removed
- [Breaking change] Removed the `dry_run` option (https://github.com/zendesk/global_uid/pull/64)
- [Breaking change] Removed `GlobalUid::ServerVariables` module (https://github.com/zendesk/global_uid/pull/66)
- Removed `options` parameter from `generate_uid` & `generate_many_uids` (https://github.com/zendesk/global_uid/pull/68)
- [Breaking change] The following methods on `GlobalUid::Base` are no longer accessible as they're for internal use only (https://github.com/zendesk/global_uid/pull/71)
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
