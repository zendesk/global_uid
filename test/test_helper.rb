require 'rubygems'

require 'bundler'
Bundler.setup
Bundler.setup(:test)

require "active_record"
require "active_support"
require "active_support/test_case"
require "shoulda"
require "mocha/setup"
require 'minitest/autorun'
require "global_uid"

GlobalUid::Base.global_uid_options = {
  :disabled   => false,
  :id_servers => [
    "test_id_server_1",
    "test_id_server_2"
  ]
}
GlobalUid::Base.extend(GlobalUid::ServerVariables)

yaml = YAML::load(IO.read(File.dirname(__FILE__) + "/config/database.yml"))

if !Gem::Specification.find_all_by_name("mysql2").empty?
  yaml.each do |k, v|
    v['adapter'] = 'mysql2'
  end
end

ActiveRecord::Base.configurations = yaml
ActiveRecord::Base.establish_connection("test")
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/test.log")
