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

GlobalUid::Base.global_uid_options = {
  :disabled   => false,
  :id_servers => [
    "test_id_server_1",
    "test_id_server_2"
  ]
}
GlobalUid::Base.extend(GlobalUid::ServerVariables)

Phenix.configure do |config|
  config.database_config_path = File.join(File.dirname(__FILE__), "config/database.yml")
end

Phenix.rise!(with_schema: false)
ActiveRecord::Base.establish_connection(:test)
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/test.log")
ActiveSupport.test_order = :sorted if ActiveSupport.respond_to?(:test_order=)
ActiveRecord::Migration.verbose = false
