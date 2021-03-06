# frozen_string_literal: true
require "global_uid/base"
require "global_uid/allocator"
require "global_uid/server"
require "global_uid/configuration"
require "global_uid/error_tracker"
require "global_uid/active_record_extension"
require "global_uid/has_and_belongs_to_many_builder_extension"
require "global_uid/migration_extension"
require "global_uid/schema_dumper_extension"

module GlobalUid
  class NoServersAvailableException < StandardError ; end
  class ConnectionTimeoutException < StandardError ; end
  class TimeoutException < StandardError ; end
  class InvalidIncrementException < StandardError ; end

  def self.configuration
    @configuration ||= GlobalUid::Configuration.new
  end

  def self.configure
    yield configuration if block_given?
  end

  def self.disable!
    self.configuration.disabled = true
  end

  def self.enable!
    self.configuration.disabled = false
  end

  def self.enabled?
    !self.disabled?
  end

  def self.disabled?
    self.configuration.disabled
  end

  # @private
  def self.reset_configuration
    @configuration = nil
  end
end

ActiveRecord::Base.send(:include, GlobalUid::ActiveRecordExtension)
ActiveRecord::Migration.send(:prepend, GlobalUid::MigrationExtension)

# Make sure that GlobalUID is disabled for ActiveRecord's SchemaMigration table
if defined?(ActiveRecord::SchemaMigration)
  ActiveRecord::SchemaMigration.disable_global_uid
end

# Make sure that GlobalUID is disabled for ActiveRecord's Internal Metadata table
if ActiveRecord::VERSION::MAJOR >= 5
  ActiveRecord::InternalMetadata.disable_global_uid
end

ActiveRecord::Associations::Builder::HasAndBelongsToMany.send(:include, GlobalUid::HasAndBelongsToManyBuilderExtension)
ActiveRecord::SchemaDumper.send(:prepend, GlobalUid::SchemaDumperExtension)
