require "global_uid/base"
require "global_uid/active_record_extension"
require "global_uid/has_and_belongs_to_many_builder_extension"
require "global_uid/migration_extension"
require "global_uid/schema_dumper_extension"

module GlobalUid
  class NoServersAvailableException < Exception ; end
  class ConnectionTimeoutException < Exception ; end
  class TimeoutException < Exception ; end

  autoload :ServerVariables, "global_uid/server_variables"
end

ActiveRecord::Base.send(:include, GlobalUid::ActiveRecordExtension)
ActiveRecord::Migration.send(:prepend, GlobalUid::MigrationExtension)

if ActiveRecord::VERSION::MAJOR >= 4 && ActiveRecord::VERSION::MINOR >= 1
  ActiveRecord::Associations::Builder::HasAndBelongsToMany.send(:include, GlobalUid::HasAndBelongsToManyBuilderExtension)
end

if ActiveRecord::VERSION::MAJOR == 4 && RUBY_VERSION >= '2'
  ActiveRecord::SchemaDumper.send(:prepend, GlobalUid::SchemaDumperExtension)
end
