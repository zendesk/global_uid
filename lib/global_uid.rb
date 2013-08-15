require "global_uid/base"
require "global_uid/active_record_extension"
require "global_uid/migration_extension"

module GlobalUid
  VERSION = "1.3.1"

  class NoServersAvailableException < Exception ; end
  class ConnectionTimeoutException < Exception ; end
  class TimeoutException < Exception ; end

  autoload :ServerVariables, "global_uid/server_variables"
end

ActiveRecord::Base.send(:include, GlobalUid::ActiveRecordExtension)
ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:include, GlobalUid::MigrationExtension)

