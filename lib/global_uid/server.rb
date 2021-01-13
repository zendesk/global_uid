module GlobalUid
  class Server

    attr_accessor :connection, :name

    def initialize(name, increment_by:, connection_retry:, connection_timeout:, query_timeout:)
      @connection = nil
      @name = name
      @retry_at = nil
      @allocators = {}
      @increment_by = increment_by
      @connection_retry = connection_retry
      @connection_timeout = connection_timeout
      @query_timeout = query_timeout
    end

    def connect
      return @connection if active? || !retry_connection?
      @connection = mysql2_connection(name)

      begin
        validate_connection_increment if active?
      rescue InvalidIncrementException => e
        GlobalUid.configuration.notifier.call(e)
        disconnect!
      end

      @connection
    end

    def active?
      !disconnected?
    end

    def disconnected?
      @connection.nil?
    end

    def update_retry_at(seconds)
      @retry_at = Time.now + seconds
    end

    def disconnect!
      @connection = nil
      @allocators = {}
    end

    def create_uid_table!(name:, uid_type: nil, start_id: nil)
      uid_type ||= "bigint(21) UNSIGNED"
      start_id ||= 1

      connection.execute("CREATE TABLE IF NOT EXISTS `#{name}` (
      `id` #{uid_type} NOT NULL AUTO_INCREMENT,
      `stub` char(1) NOT NULL DEFAULT '',
      PRIMARY KEY (`id`),
      UNIQUE KEY `stub` (`stub`)
      ) ENGINE=#{GlobalUid.configuration.storage_engine}")

      # prime the pump on each server
      connection.execute("INSERT IGNORE INTO `#{name}` VALUES(#{start_id}, 'a')")
    end

    def drop_uid_table!(name:)
      connection.execute("DROP TABLE IF EXISTS `#{name}`")
    end

    def allocate(klass, count: 1)
      # TODO: Replace Timeout.timeout with DB level timeout
      #   Timeout.timeout is unpredictable
      Timeout.timeout(query_timeout, TimeoutException) do
        if count == 1
          allocator(klass).allocate_one
        else
          allocator(klass).allocate_many(count: count)
        end
      end
    end

    private

    attr_accessor :connection_retry, :connection_timeout, :retry_at, :increment_by, :query_timeout, :allocators

    def allocator(klass)
      table_name = klass.global_uid_table
      @allocators[table_name] ||= Allocator.new(incrementing_by: increment_by, connection: connection, table_name: table_name)
    end

    def retry_connection?
      return Time.now > retry_at if retry_at

      update_retry_at(connection_retry)
      true
    end

    def mysql2_connection(name)
      config = mysql2_config(name)

      Timeout.timeout(connection_timeout, ConnectionTimeoutException) do
        ActiveRecord::Base.mysql2_connection(config)
      end
    rescue ConnectionTimeoutException => e
      GlobalUid.configuration.notifier.call(ConnectionTimeoutException.new("Timed out establishing a connection to #{name}"))
      nil
    rescue Exception => e
      GlobalUid.configuration.notifier.call(StandardError.new("establishing a connection to #{name}: #{e.message}"))
      nil
    end

    if ActiveRecord.version < Gem::Version.new('6.1.0')
      def mysql2_config(name)
        raise "No id server '#{name}' configured in database.yml" unless ActiveRecord::Base.configurations.to_h.has_key?(name)
        config = ActiveRecord::Base.configurations.to_h[name]

        c = config.symbolize_keys
        raise "No global_uid support for adapter #{c[:adapter]}" if c[:adapter] != 'mysql2'

        config
      end
    else
      def mysql2_config(name)
        config = ActiveRecord::Base.configurations.configs_for(env_name: name, name: 'primary')

        raise "No id server '#{name}' configured in database.yml" if config.nil?
        raise "No global_uid support for adapter #{config.adapter}" if config.adapter != 'mysql2'

        config.configuration_hash
      end
    end

    def validate_connection_increment
      db_increment = connection.select_value("SELECT @@auto_increment_increment")

      if db_increment != increment_by
        GlobalUid::Base.alert(InvalidIncrementException.new("Configured: '#{increment_by}', Found: '#{db_increment}' on '#{connection.current_database}'"))
      end
    end
  end
end
