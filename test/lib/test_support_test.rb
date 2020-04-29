# frozen_string_literal: true
require_relative '../test_helper'
require 'global_uid/test_support'

describe GlobalUid::TestSupport do
  before do
    Phenix.rise!(with_schema: false)
    ActiveRecord::Base.establish_connection(:test)
    restore_defaults!
  end

  after do
    GlobalUid::Base.disconnect!
    Phenix.burn!
  end

  def table_exists?(connection, table)
    if ActiveRecord::VERSION::MAJOR >= 5
      connection.data_source_exists?(table)
    else
      connection.table_exists?(table)
    end
  end

  class Foo < ActiveRecord::Base
  end

  class Bar < ActiveRecord::Base
  end

  it 'recreates the tables' do
    # Check the tables aren't there
    GlobalUid::Base.with_servers do |server|
      refute table_exists?(server.connection, Foo.global_uid_table), 'Table should not exist'
      refute table_exists?(server.connection, Bar.global_uid_table), 'Table should not exist'
    end

    # Create the tables
    GlobalUid::TestSupport.create_uid_tables(tables: [Foo.table_name, Bar.table_name])
    GlobalUid::Base.with_servers do |server|
      assert table_exists?(server.connection, Foo.global_uid_table), 'Table should exist'
      assert table_exists?(server.connection, Bar.global_uid_table), 'Table should exist'
    end

    # Add some data, ensuring it's cleared when recreate is called
    GlobalUid::Base.with_servers do |server|
      3.times { server.allocate(Foo) }
    end
    assert_operator GlobalUid::Base.servers.first.allocate(Foo), :>=, 15

    # Verify that the tables are dropped and recreated
    GlobalUid::TestSupport.recreate_uid_tables(tables: [Foo.table_name, Bar.table_name])
    GlobalUid::Base.with_servers do |server|
      server.allocate(Foo)
    end
    assert_operator GlobalUid::Base.servers.first.allocate(Foo), :<=, 15
  end
end
