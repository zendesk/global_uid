require 'rubygems'

require 'bundler'
Bundler.setup

require "active_record"
require "active_support"
require "active_support/test_case"
require "shoulda"
require "global_uid"

test_options = {
  'global_uid_options' => {
    'use_server_variables' => true,
    'disabled'   => false,
    'id_servers' => [
      'test_id_server_1',
      'test_id_server_2'
    ]
  }
}
