# frozen_string_literal: true
require "active_record"
require "active_support/all"
require "mysql2"
require "timeout"

module GlobalUid
  class Base
    GLOBAL_UID_DEFAULTS = {
      :connection_timeout   => 3,
      :connection_retry     => 10.minutes,
      :notifier             => Proc.new { |exception, message| ActiveRecord::Base.logger.error("GlobalUID error: #{exception.class} #{message}") },
      :query_timeout        => 10,
      :increment_by         => 5, # This will define the maximum number of servers that you can have
      :disabled             => false,
      :per_process_affinity => true,
      :suppress_increment_exceptions => false
    }

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

      engine_stmt = "ENGINE=#{global_uid_options[:storage_engine] || "MyISAM"}"

      with_connections do |connection|
        connection.execute("CREATE TABLE IF NOT EXISTS `#{id_table_name}` (
        `id` #{type} NOT NULL AUTO_INCREMENT,
        `stub` char(1) NOT NULL DEFAULT '',
        PRIMARY KEY (`id`),
        UNIQUE KEY `stub` (`stub`)
        ) #{engine_stmt}")

        # prime the pump on each server
        connection.execute("INSERT IGNORE INTO `#{id_table_name}` VALUES(#{start_id}, 'a')")
      end
    end

    def self.drop_uid_tables(id_table_name)
      with_connections do |connection|
        connection.execute("DROP TABLE IF EXISTS `#{id_table_name}`")
      end
    end

    def self.init_server_info
      id_servers = self.global_uid_servers
      increment_by = self.global_uid_options[:increment_by]
      connection_retry = self.global_uid_options[:connection_retry]
      connection_timeout = self.global_uid_options[:connection_timeout]

      raise "You haven't configured any id servers" if id_servers.nil? or id_servers.empty?
      raise "More servers configured than increment_by: #{id_servers.size} > #{increment_by} -- this will create duplicate IDs." if id_servers.size > increment_by

      id_servers.map do |name|
        GlobalUid::Server.new(name,
          increment_by: increment_by,
          connection_retry: connection_retry,
          connection_timeout: connection_timeout
        )
      end
    end

    def self.disconnect!
      servers.each(&:disconnect!) unless servers.nil?
      self.servers = nil
    end

    def self.setup_connections!
      self.servers ||= init_server_info.shuffle
      self.servers.each(&:connect)
    end

    def self.with_connections
      servers = setup_connections!
      servers = servers.shuffle if !self.global_uid_options[:per_process_affinity]

      raise NoServersAvailableException if servers.empty?

      errors = []
      servers.each do |server|
        begin
          yield server.connection if server.active?
        rescue TimeoutException, Exception => e
          notify e, "#{e.message}"
          errors << e
          server.disconnect!
          server.update_retry_at(1.minute)
        end
      end

      # in the case where all servers are gone, put everyone back in.
      if servers.all?(&:disconnected?)
        servers.each do |server|
          server.update_retry_at(0)
        end
        raise NoServersAvailableException, "Errors hit: #{errors.map(&:to_s).join(',')}"
      end

      connections
    end

    def self.notify(exception, message)
      if self.global_uid_options[:notifier]
        self.global_uid_options[:notifier].call(exception, message)
      end
    end

    def self.connections
      return [] if servers.nil?
      servers.select(&:active?).map(&:connection)
    end

    def self.get_uid_for_class(klass)
      with_connections do |connection|
        server = self.servers.find { |server| connection.current_database.include?(server.name) }
        Timeout.timeout(self.global_uid_options[:query_timeout], TimeoutException) do
          return server.allocator.allocate_one(klass.global_uid_table)
        end
      end
      raise NoServersAvailableException, "All global UID servers are gone!"
    end

    def self.get_many_uids_for_class(klass, count)
      return [] unless count > 0
      with_connections do |connection|
        server = self.servers.find { |server| connection.current_database.include?(server.name) }
        Timeout.timeout(self.global_uid_options[:query_timeout], TimeoutException) do
          return server.allocator.allocate_many(klass.global_uid_table, count: count)
        end
      end
      raise NoServersAvailableException, "All global UID servers are gone!"
    end

    def self.global_uid_options=(options)
      @global_uid_options = GLOBAL_UID_DEFAULTS.merge(options.symbolize_keys)
    end

    def self.global_uid_options
      @global_uid_options
    end

    def self.global_uid_servers
      self.global_uid_options[:id_servers]
    end

    def self.id_table_from_name(name)
      "#{name}_ids".to_sym
    end
  end
end
