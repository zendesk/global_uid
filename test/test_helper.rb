require 'rubygems'

require 'bundler'
Bundler.setup
Bundler.setup(:test)

require 'ruby-debug'
require "active_record"
require "active_support"
require "active_support/test_case"
require "shoulda"
require "global_uid"

GlobalUid::Base.global_uid_options = {
  :use_server_variables => true,
  :disabled   => false,
  :id_servers => [
    "test_id_server_1",
    "test_id_server_2"
  ]
}

ActiveRecord::Base.configurations = YAML::load(IO.read(File.dirname(__FILE__) + "/config/database.yml"))
ActiveRecord::Base.establish_connection("test")
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/test.log")
