require "active_record"
require "active_support/all"

require "timeout"

begin
  require 'mysql2'
rescue LoadError
end


module GlobalUid
  class Base
    @@servers = nil

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

    def self.create_uid_tables(id_table_name, options={})
      type     = options[:uid_type] || "bigint(21) UNSIGNED"
      start_id = options[:start_id] || 1

      # TODO it would be nice to be able to set the engine or something to not be MySQL specific
      with_connections do |connection|
        connection.execute("CREATE TABLE IF NOT EXISTS `#{id_table_name}` (
        `id` #{type} NOT NULL AUTO_INCREMENT,
        `stub` char(1) NOT NULL DEFAULT '',
        PRIMARY KEY (`id`),
        UNIQUE KEY `stub` (`stub`)
        )")

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

    def self.new_connection(name, connection_timeout, offset, increment_by, use_server_variables)
      raise "No id server '#{name}' configured in database.yml" unless ActiveRecord::Base.configurations.has_key?(name)
      config = ActiveRecord::Base.configurations[name]
      c = config.symbolize_keys

      raise "No global_uid support for adapter #{c[:adapter]}" unless ['mysql', 'mysql2'].include?(c[:adapter])

      con = nil
      begin
        GlobalUidTimer.timeout(connection_timeout, ConnectionTimeoutException) do
          con = ActiveRecord::Base.send("#{c[:adapter]}_connection", config)
        end
      rescue ConnectionTimeoutException => e
        notify e, "Timed out establishing a connection to #{name}"
        return nil
      rescue Exception => e
        notify e, "establishing a connection to #{name}: #{e.message}"
        return nil
      end

      # Please note that this is unreliable -- if you lose your CX to the server
      # and auto-reconnect, you will be utterly hosed.  Much better to dedicate a server
      # or two to the cause, and set their auto_increment_increment globally.
      if use_server_variables
        con.execute("set @@auto_increment_increment = #{increment_by}")
        con.execute("set @@auto_increment_offset = #{offset}")
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
      @@servers = nil
    end

    def self.setup_connections!(options)
      connection_timeout = options[:connection_timeout]
      increment_by       = options[:increment_by]

      if @@servers.nil?
        @@servers = init_server_info(options)
        # sorting here sets up each process to have affinity to a particular server.
        @@servers = @@servers.sort_by { |s| s[:rand] }
      end

      @@servers.each do |info|
        next if info[:cx]

        if info[:new?] || ( info[:retry_at] && Time.now > info[:retry_at] )
          info[:new?] = false

          connection = new_connection(info[:name], connection_timeout, info[:offset], increment_by, options[:use_server_variables])
          info[:cx]  = connection
          info[:retry_at] = Time.now + options[:connection_retry] if connection.nil?
        end
      end

      @@servers
    end

    def self.with_connections(options = {})
      options = self.global_uid_options.merge(options)
      servers = setup_connections!(options)

      if !options[:per_process_affinity]
        servers = servers.sort_by { rand } #yes, I know it's not true random.
      end

      raise NoServersAvailableException if servers.empty?

      exception_count = 0

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

    def self.get_many_uids_for_class(klass, n, options = {})
      with_connections do |connection|
        GlobalUidTimer.timeout(self.global_uid_options[:query_timeout], TimeoutException) do
          connection.transaction do
            start_id = connection.select_value("SELECT id from #{klass.global_uid_table} where stub='a' FOR UPDATE").to_i
            connection.execute("update #{klass.global_uid_table} set id = id + #{n} * @@auto_increment_increment where stub='a'")
            end_res = connection.select_one("SELECT id, @@auto_increment_increment as inc from #{klass.global_uid_table} where stub='a'")
            increment_by = end_res['inc'].to_i
            end_id = end_res['id'].to_i
            return (start_id + increment_by).step(end_id, increment_by).to_a
          end
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
