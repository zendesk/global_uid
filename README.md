# Global UID Plugin

[![Build status](https://circleci.com/gh/zendesk/global_uid.svg?style=svg)](https://circleci.com/gh/zendesk/global_uid)

## Summary

This plugin does a lot of the heavy lifting needed to have an external MySQL based global id generator as described in this article from Flickr

(http://code.flickr.com/blog/2010/02/08/ticket-servers-distributed-unique-primary-keys-on-the-cheap/)

There are three parts to it: configuration, migration and object creation

### Interactions with other databases

This gem only supports MySQL. Theoretically it should be easy to port it to other DBs, we just don't need to.

## Installation

Add it to your gemfile and run `bundle install`:

```rb
gem "global_uid"
```

### Configuration

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
GlobalUid::Base.global_uid_options = {
  id_servers: [ 'id_server_1', 'id_server_2' ],
  increment_by: 3
}
```

Here's a complete list of the options you can use:

| Name                  | Default                                    | Description                                                                                                |
| --------------------- | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `:disabled`           | `false`                                    | Disable GlobalUid entirely                                                                                 |
| `:connection_timeout` | 3 seconds                                  | Timeout for connecting to a global UID server                                                              |
| `:query_timeout`      | 10 seconds                                 | Timeout for retrieving a global UID from a server before we move on to the next server                     |
| `:connection_retry`   | 10 minutes                                 | After failing to connect or query a UID server, how long before we retry                                   |
| `:notifier`           | A proc calling `ActiveRecord::Base.logger` | This proc is called with two parameters upon UID server failure -- an exception and a message              |
| `:increment_by`       | 5                                          | Chooses the step size for the increment.  This will define the maximum number of UID servers you can have. |

### Testing

```
mysqladmin -uroot create global_uid_test
mysqladmin -uroot create global_uid_test_id_server_1
mysqladmin -uroot create global_uid_test_id_server_2
```

Copy test/config/database.yml.example to test/config/database.yml and make the modifications you need to point it to 2 local MySQL databases. Then +rake test+

### Migration

Migrations will now add global_uid tables for you by default.  They will also change
your primary keys from signature "PRIMARY KEY AUTO_INCREMENT NOT NULL" to "PRIMARY KEY NOT NULL".

If you'd like to disable this behavior, you can write:

```rb
class CreateFoos < ActiveRecord::Migration
  def self.up
    create_table :foos, use_global_uid: false do |t|
```

## Model-level stuff

If you want GlobalUIDs created, you don't have to do anything except set up the GlobalUID tables
with your migration.  Everything will be taken care you.  It's calm, and soothing like aloe.
It's the Rails way.


### Disabling global uid per table

```rb
class Foo < ActiveRecord::Base
  disable_global_uid
end
````


## Taking matters into your own hands:

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

Copyright (c) 2010 Zendesk, released under the MIT license
