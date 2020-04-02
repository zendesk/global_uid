# frozen_string_literal: true
require 'bundler/setup'
require "active_record"
require 'minitest/autorun'
require 'minitest/rg'
require 'minitest/line/describe_track'
require 'mocha/minitest'
require 'global_uid'
require 'phenix'
require 'pry'

Phenix.configure do |config|
  config.database_config_path = File.join(File.dirname(__FILE__), "config/database.yml")
end

Phenix.rise!(with_schema: false)
ActiveRecord::Base.establish_connection(:test)
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/test.log")
ActiveSupport.test_order = :sorted if ActiveSupport.respond_to?(:test_order=)
ActiveRecord::Migration.verbose = false

def test_unique_ids
  seen = {}
  (0..10).each do
    foo = WithGlobalUID.new
    foo.save
    refute_nil foo.id
    assert_nil foo.description
    refute seen.has_key?(foo.id)
    seen[foo.id] = 1
  end
end

def reset_connections!
  GlobalUid::Base.servers = nil
end

def restore_defaults!
  GlobalUid::Base.global_uid_options = {
    :id_servers => [
      "test_id_server_1",
      "test_id_server_2"
    ]
  }

  # Randomize connections for test processes to ensure they're not
  # sticky during tests
  GlobalUid::Base.global_uid_options[:per_process_affinity] = false
end
