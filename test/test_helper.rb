# frozen_string_literal: true
require 'bundler/setup'
require "active_record"
require 'benchmark/ips'
require 'minitest/autorun'
require 'minitest/rg'
require 'minitest/line/describe_track'
require 'mocha/minitest'
require 'global_uid'
require 'phenix'
require 'pry'

require_relative 'support/migrations'
require_relative 'support/models'

Phenix.configure do |config|
  config.database_config_path = File.join(File.dirname(__FILE__), "config/database.yml")
end

Phenix.rise!(with_schema: false)
ActiveRecord::Base.establish_connection(:test)
ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "test.log"))
ActiveSupport.test_order = :sorted if ActiveSupport.respond_to?(:test_order=)
ActiveRecord::Migration.verbose = false

def test_unique_ids(model: nil, models: [model], amount: 0)
  models.each do |model|
    amount.times.each_with_object({}) do |_, seen|
      record = model.create!
      refute_nil record.id
      assert_nil record.description
      refute seen.has_key?(record.id)
      seen[record.id] = true
    end
  end
end

def restore_defaults!
  GlobalUid.reset_configuration
  GlobalUid.configure do |config|
    config.id_servers = ["test_id_server_1", "test_id_server_2"]

    # Randomize connections for test processes to ensure they're not
    # sticky during tests
    config.connection_shuffling = true
  end
end
