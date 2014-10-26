require 'bundler/setup'
require "active_record"
require 'minitest/autorun'
require 'minitest/rg'
require 'mocha/setup'
require 'global_uid'

GlobalUid::Base.global_uid_options = {
  :disabled   => false,
  :id_servers => [
    "test_id_server_1",
    "test_id_server_2"
  ]
}
GlobalUid::Base.extend(GlobalUid::ServerVariables)

yaml = YAML.load(IO.read(File.dirname(__FILE__) + "/config/database.yml"))
ActiveRecord::Base.configurations = yaml
ActiveRecord::Base.establish_connection("test")
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/test.log")
