require "global_uid/base"
require "global_uid/active_record_extension"
require "global_uid/migration_extension"

module GlobalUid
end

ActiveRecord::Base.send(:include, GlobalUid::ActiveRecordExtension)
ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:include, GlobalUid::MigrationExtension)

