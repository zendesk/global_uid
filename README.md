**GlobalUID is deprecated and will no longer be maintained.**

Zendesk is working on a [new unique ID solution](https://medium.com/zendesk-engineering/how-probable-are-collisions-with-ulids-monotonic-option-d604d3ed2de) that has made this library redundant, and will no longer be actively maintained. Internal staff are recommended to use [this private transitional library](https://github.com/zendesk/zendesk_unique_id_migration).

----

# Global UID Plugin

[![Build status](https://circleci.com/gh/zendesk/global_uid.svg?style=svg)](https://circleci.com/gh/zendesk/global_uid)

## Summary

This gem allows you to generate global IDs as described in [this article from Flickr](http://code.flickr.com/blog/2010/02/08/ticket-servers-distributed-unique-primary-keys-on-the-cheap/) for your Ruby on Rails applications. It does this by patching
`ActiveRecord::Base` and `ActiveRecord::Migration` so that new models retrieve their ID from one of the configured
alloc servers (short for ID allocation databases), this functionality is opt-out, not opt-in. The databases responsible
for allocating your identifiers (aka id_servers) should have their `auto_increment_increment` and `auto_increment_offset`
setting [configured globally](https://dev.mysql.com/doc/refman/5.7/en/replication-options-master.html#sysvar_auto_increment_increment).

This gem only supports MySQL databases and the documentation is written with that in mind but the concept could be applied to others.

### Resilience

The gem will iterate over the configured `id_servers`, choose one at random and attempt a connection, returning the ID from the first alloc server to successfully respond.
If there's a connection failure, the server will be removed from the pool and retried after the configured `connection_retry` period.
If there's an allocation failure, the server will be removed from the pool and retried after 60 seconds.

In either failure scenario, the configured `notifier` will be called and the gem will move through the list of configured `id_servers`
until it gets a successful response. If no ID can be retrieved, a `NoServersAvailableException` is thrown and the connection state is reset so that subsequent requests will retry immediately.

## Installation

Add it to your gemfile and run `bundle install`:

```rb
gem "global_uid"
```

## Configuration

First configure some databases in database.yml in the normal way.

```yml
id_server_1:
  adapter: mysql2
  host: id_server_db1.prod
  port: 3306

id_server_2:
  adapter: mysql2
  host: id_server_db2.prod
  port: 3306
```

Then setup these servers, and other defaults in your environment.rb:

```rb
GlobalUid.configure do |config|
  config.id_servers = [ 'id_server_1', 'id_server_2' ]
  config.increment_by = 5
}
```

For a full list of configuration options, and their defaults, see `GlobalUid::Configuration`

### Migration

Migrations will now add global_uid tables for you by default.  They will also change
your primary keys from signature "PRIMARY KEY AUTO_INCREMENT NOT NULL" to "PRIMARY KEY NOT NULL".

If you'd like to disable this behavior, you can by setting `use_global_uid` to `false` as show
below:

```rb
class CreateFoos < ActiveRecord::Migration
  def self.up
    create_table :foos, use_global_uid: false do |t|
```

### Model-level stuff

If you want GlobalUIDs created, you don't have to do anything except set up the GlobalUID tables
with your migration.  Everything will be taken care you.  It's calm, and soothing like aloe.
It's the Rails way.


### Disabling global uid per table

```rb
class Foo < ActiveRecord::Base
  disable_global_uid
end
```

### Taking matters into your own hands:

```rb
class Foo < ActiveRecord::Base
  disable_global_uid

  def before_create
    self.id = generate_uid()
    # other stuff
    ....
  end
end
```

If you're using a non standard uid table then pass that in.

```rb
generate_uid(uid_table: '<name>')
```

### Testing

`mysql` is a required and can be installed with `brew install mysql@5.7`.
If already installed, it's expected to be running with the defaults (`root@127.0.0.1:3306`).
Set the `MYSQL_URL` environment variable if you're using something different.

This gem uses `minitest` and the test suite can be run with `bundle exec rake test`.

If you want to run a particular scenario, it can be done by passing the line number in, e.g. `bundle exec ruby test/global_uid_test.rb -l 18`

Copyright (c) 2010 Zendesk, released under the MIT license
