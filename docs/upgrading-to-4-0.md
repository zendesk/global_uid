This release includes non-backwards compatible changes.

## Upgrading from 3.x to 4.x

* The `auto_increment_increment` on the allocation servers is compared with the configured `increment_by` and an exception is raised if they don't match. Use the `suppress_increment_exceptions` configuration option if this is expected.
* Make sure you weren't using any of the private APIs that were removed in https://github.com/zendesk/global_uid/pull/71.
* The `GlobalUid::ServerVariables` module has been removed (https://github.com/zendesk/global_uid/pull/66), update your database.yml to configure the increment and offset values for the development/test DB.
* Update your configuration to use the new interface (https://github.com/zendesk/global_uid/pull/72).
```ruby
GlobalUid.configure do |config|
  config.id_servers = [ 'id_server_1', 'id_server_2' ]
  config.increment_by = 5
  config.notifier = Proc.new { |exception| do_something_with(exception) }
}
```
* The `dry_run` configuration option is no longer supported and has been removed.
* The `per_process_affinity` configuration option was replaced with `connection_shuffling` (https://github.com/zendesk/global_uid/pull/72). If you had previously configured `per_process_affinity = false`, you should now set `connection_shuffling = true` to get the same behaviour. `connection_shuffling` defaults to false.

### The removal of `with_connections`

Some gem clients were using `GlobalUid::Base.with_connections` to perform operations, however, the removal of `with_connections` was deliberate. It was a private API, and clients shouldn't be using those connections directly.

The responsibility of this gem is to provide IDs, nothing more.

If you _must_ do something with the connection, you would do it like so:
```ruby
GlobalUid::Base.with_servers do |server|
  puts "Allocation server name: #{server.name}"
  server.connection.select_all("SHOW TABLES").each do |row|
    puts "ID table Name: #{row.values.first}"
  end
end; nil
```

It's not recommended though. If a client is performing an action on the connection, consider upstreaming it by opening a pull request.
