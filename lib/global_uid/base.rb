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
      :notifier             => Proc.new { |exception, message| ActiveRecord::Base.logger.error("GlobalUID error:  #{exception} #{message}") },
      :query_timeout        => 10,
      :increment_by         => 5,  # This will define the maximum number of servers that you can have
      :disabled             => false,
      :per_process_affinity => true,
      :dry_run              => false
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

    def self.drop_uid_tables(id_table_name, options={})
      with_connections do |connection|
        connection.execute("DROP TABLE IF EXISTS `#{id_table_name}`")
      end
    end

    begin
      require 'system_timer'
    rescue LoadError
    end

    if const_defined?("SystemTimer")
      GlobalUidTimer = SystemTimer
    else
      GlobalUidTimer = Timeout
    end

    def self.new_connection(name, connection_timeout, offset, increment_by)
      raise "No id server '#{name}' configured in database.yml" unless ActiveRecord::Base.configurations.has_key?(name)
      config = ActiveRecord::Base.configurations[name]
      c = config.symbolize_keys

      raise "No global_uid support for adapter #{c[:adapter]}" if c[:adapter] != 'mysql2'

      con = nil
      begin
        GlobalUidTimer.timeout(connection_timeout, ConnectionTimeoutException) do
          con = ActiveRecord::Base.mysql2_connection(config)
        end
      rescue ConnectionTimeoutException => e
        notify e, "Timed out establishing a connection to #{name}"
        return nil
      rescue Exception => e
        notify e, "establishing a connection to #{name}: #{e.message}"
        return nil
      end

      con
    end

    def self.init_server_info(options)
      id_servers = self.global_uid_servers

      raise "You haven't configured any id servers" if id_servers.nil? or id_servers.empty?
      raise "More servers configured than increment_by: #{id_servers.size} > #{options[:increment_by]} -- this will create duplicate IDs." if id_servers.size > options[:increment_by]

      offset = 1

      id_servers.map do |name, i|
        info = {}
        info[:cx]       = nil
        info[:name]     = name
        info[:retry_at] = nil
        info[:offset]   = offset
        info[:rand]     = rand
        info[:new?]     = true
        offset +=1
        info
      end
    end

    def self.disconnect!
      self.servers = nil
    end

    def self.setup_connections!(options)
      connection_timeout = options[:connection_timeout]
      increment_by       = options[:increment_by]

      if self.servers.nil?
        self.servers = init_server_info(options)
        # sorting here sets up each process to have affinity to a particular server.
        self.servers = self.servers.sort_by { |s| s[:rand] }
      end

      self.servers.each do |info|
        next if info[:cx]

        if info[:new?] || ( info[:retry_at] && Time.now > info[:retry_at] )
          info[:new?] = false

          connection = new_connection(info[:name], connection_timeout, info[:offset], increment_by)
          info[:cx]  = connection
          info[:retry_at] = Time.now + options[:connection_retry] if connection.nil?
        end
      end

      self.servers
    end

    def self.with_connections(options = {})
      options = self.global_uid_options.merge(options)
      servers = setup_connections!(options)

      if !options[:per_process_affinity]
        servers = servers.sort_by { rand } #yes, I know it's not true random.
      end

      raise NoServersAvailableException if servers.empty?

      errors = []
      servers.each do |s|
        begin
          yield s[:cx] if s[:cx]
        rescue TimeoutException, Exception => e
          notify e, "#{e.message}"
          errors << e
          s[:cx] = nil
          s[:retry_at] = Time.now + 1.minute
        end
      end

      # in the case where all servers are gone, put everyone back in.
      if servers.all? { |info| info[:cx].nil? }
        servers.each do |info|
          info[:retry_at] = Time.now - 5.minutes
        end
        raise NoServersAvailableException, "Errors hit: #{errors.map(&:to_s).join(',')}"
      end

      servers.map { |s| s[:cx] }.compact
    end

    def self.notify(exception, message)
      if self.global_uid_options[:notifier]
        self.global_uid_options[:notifier].call(exception, message)
      end
    end

    def self.get_connections(options = {})
      with_connections {}
    end

    def self.get_uid_for_class(klass, options = {})
      with_connections do |connection|
        GlobalUidTimer.timeout(self.global_uid_options[:query_timeout], TimeoutException) do
          id = connection.insert("REPLACE INTO #{klass.global_uid_table} (stub) VALUES ('a')")
          return id
        end
      end
      raise NoServersAvailableException, "All global UID servers are gone!"
    end

    def self.get_many_uids_for_class(klass, count, options = {})
      return [] unless count > 0
      with_connections do |connection|
        GlobalUidTimer.timeout(self.global_uid_options[:query_timeout], TimeoutException) do
          increment_by = connection.select_value("SELECT @@auto_increment_increment")
          start_id = connection.insert("REPLACE INTO #{klass.global_uid_table} (stub) VALUES " + (["('a')"] * count).join(','))
          return start_id.step(start_id + (count-1) * increment_by, increment_by).to_a
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
