= Global UID Plugin

== Summary

This plugin does a lot of the heavy lifting needed to have an external MySQL based global id generator as described in this article from Flickr

http://code.flickr.com/blog/2010/02/08/ticket-servers-distributed-unique-primary-keys-on-the-cheap/

There are three parts to it: configuration, migration and object creation

=== Interactions with other databases

This plugin shouldn't fail with Databases other than MySQL but neither will it do anything either. There's theoretically nothing that should stop it from being *ported* to other DBs, we just don't need to.

== Installation

Shove this in your Gemfile and smoke it

  gem "global_uid", :git => "git://github.com/zendesk/global_uid.git"

=== Configuration

First configure some databases in database.yml in the normal way.

    id_server_1:
      adapter: mysql
      host: id_server_db1.prod
      port: 3306

    id_server_2:
        adapter: mysql
        host: id_server_db2.prod
        port: 3306

Then setup these servers, and other defaults in your environment.rb:

    GlobalUid.default_options = {
      :id_servers => [ 'id_server_1', 'id_server_2' ],
      :increment_by => 3
    }

Here's a complete list of the options you can use:

  Name                  Default                       Explains
  :increment_by         5                             Chooses the step size for the increment.  This will define the maximum number of UID servers you can have.
  :connection_timeout   10 seconds                    Timeout for connecting to a global UID server
  :query_timeout        10 seconds                    Timeout for retrieving a global UID from a server
  :connection_retry     10.minutes                    After failing to connect or query a UID server, how long before we retry
  :notifier             A proc calling Rails.logger   This proc is called with two parameters upon UID server failure -- an exception and a message
  :disabled             false                         Disable GlobalUid, either globally or on a per class basis.
  :dry_run              false                         Setting this parameter causes the REPLACE INTO statements to run, but the id picked up will not be used.

=== Testing

  mysqladmin -uroot create global_uid_test
  mysqladmin -uroot create global_uid_test_id_server_1
  mysqladmin -uroot create global_uid_test_id_server_2

Copy test/config/database.yml.example to test/config/database.yml and make the modifications you need to point it to 2 local MySQL databases. Then +rake test+

=== Migration

Create a migration as normal but pass in the option

  :use_global_uid => true

to both create_table and drop_table.

You must have describe an id column which is primary. It can be called whatever you want.

    class CreateFoos < ActiveRecord::Migration
      def self.up
        create_table :foos, :use_global_uid => true do |t|
          t.integer :id, :limit => 8, :primary => true, :null => false
          t.string  :description
        end
      end

      def self.down
        drop_table :foos, :use_global_uid => true
      end
    end

This will set up the table properly for you and also create the corresponding id table on each of the id servers.

You can specify the name of the id table by passing in

    :global_uid_table => '<name>'

Remember: you must pass the same value into drop_table as well.

== Model-level stuff

If you want GlobalUIDs created, you don't have to do anything except set up the GlobalUID tables
with your migration.  Everything will be taken care you.  It's calm, and soothing like aloe.
It's the Rails way.


=== Disabling global uid per table

class Foo < ActiveRecord::Base
  disable_global_uid
end


=== Setting per model global uid parameters

class Foo < ActiveRecord::Base
  global_uid_options[:table_name] = 'bar_ids'
  global_uid_options[:dry_run] = true
end

== Taking matters into your own hands:


  class Foo < ActiveRecord::Base
    disable_global_uid

    def before_create
      self.id = generate_uid()
      # other stuff
      ....
    end

  end

If you're using a non standard uid table then pass that in.

    generate_uid(:uid_table => '<name>')

== Submitting Bug reports, patches or improvements

I welcome your feedback, bug reports, patches and improvements. Please e-mail these
to
    simon at zendesk.com

with [mysqlbigint global uid] in the subject line. I'll get back to you as soon as I can.

Copyright (c) 2010 Zendesk, released under the MIT license
