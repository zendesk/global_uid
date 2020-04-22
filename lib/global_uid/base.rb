# frozen_string_literal: true
require "active_record"
require "active_support/all"
require "mysql2"
require "timeout"

module GlobalUid
  class Base

    def self.servers
      # Thread local storage is inheritted on `fork`, include the pid
      Thread.current["global_uid_servers_#{$$}"]
    end

    def self.servers=(s)
      Thread.current["global_uid_servers_#{$$}"] = s
    end

    def self.create_uid_tables(id_table_name, options={})
      type     = options[:uid_type] || "bigint(21) UNSIGNED"
      start_id = options[:start_id] || 1

      engine_stmt = "ENGINE=#{GlobalUid.configuration.storage_engine}"

      with_servers do |server|
        server.connection.execute("CREATE TABLE IF NOT EXISTS `#{id_table_name}` (
        `id` #{type} NOT NULL AUTO_INCREMENT,
        `stub` char(1) NOT NULL DEFAULT '',
        PRIMARY KEY (`id`),
        UNIQUE KEY `stub` (`stub`)
        ) #{engine_stmt}")

        # prime the pump on each server
        server.connection.execute("INSERT IGNORE INTO `#{id_table_name}` VALUES(#{start_id}, 'a')")
      end
    end

    def self.drop_uid_tables(id_table_name)
      with_servers do |server|
        server.connection.execute("DROP TABLE IF EXISTS `#{id_table_name}`")
      end
    end

    def self.init_server_info
      id_servers = GlobalUid.configuration.id_servers
      increment_by = GlobalUid.configuration.increment_by
      connection_timeout = GlobalUid.configuration.connection_timeout

      id_servers.map do |name|
        GlobalUid::Server.new(name,
          increment_by: increment_by,
          connection_timeout: connection_timeout
        )
      end
    end

    def self.setup_connections!
      self.servers ||= init_server_info
      self.servers.each(&:connect)
    end

    def self.disconnect!
      self.servers.each(&:disconnect!) unless servers.nil?
      self.servers = nil
    end

    def self.with_servers
      servers = setup_connections!
      servers = servers.shuffle if GlobalUid.configuration.connection_shuffling?

      errors = []
      servers.each do |server|
        begin
          yield server if server.active?
        rescue TimeoutException, Exception => e
          GlobalUid.configuration.notifier.call(e)
          errors << e
          server.disconnect!
          server.update_retry_at(60)
        end
      end

      if get_connections.empty? # all servers have returned errors
        exception = NoServersAvailableException.new(errors.empty? ? "" : "Errors hit: #{errors.map(&:to_s).join(', ')}")
        GlobalUid.configuration.notifier.call(exception)
        raise exception
      end

      servers
    end

    def self.get_connections
      return [] if servers.nil?
      servers.map(&:connection).compact
    end

    def self.get_uid_for_class(klass)
      with_servers do |server|
        Timeout.timeout(GlobalUid.configuration.query_timeout, TimeoutException) do
          return server.allocator.allocate_one(klass.global_uid_table)
        end
      end
    end

    def self.get_many_uids_for_class(klass, count)
      return [] unless count > 0
      with_servers do |server|
        Timeout.timeout(GlobalUid.configuration.query_timeout, TimeoutException) do
          return server.allocator.allocate_many(klass.global_uid_table, count: count)
        end
      end
    end

    def self.id_table_from_name(name)
      "#{name}_ids".to_sym
    end
  end
end
