module GlobalUid
  class Server
    attr_reader :name, :allocator, :connection

    def initialize(name, increment_by:, connection_timeout:)
      @connection = nil
      @name = name
      @retry_at = nil
      @increment_by = increment_by
      @connection_timeout = connection_timeout
      @allocator = nil
    end

    def update_retry_at(seconds)
      @retry_at = Time.now + seconds
    end

    def retry_connection?
      return Time.now > retry_at if retry_at

      update_retry_at(GlobalUid.configuration.connection_retry)
      true
    end

    def connect
      return @connection if active? || !retry_connection?

      @connection = mysql2_connection

      begin
        @allocator = Allocator.new(incrementing_by: increment_by, connection: @connection) unless @connection.nil?
      rescue InvalidIncrementException => e
        GlobalUid::Base.notify(e, e.message)
        # Don't return the connection if the allocator has found it invalid
        disconnect!
      end

      @connection
    end

    def active?
      !@connection.nil?
    end

    def disconnect!
      @connection = nil
      @allocator = nil
    end

    private

    attr_reader :retry_at, :connection_timeout, :increment_by

    def mysql2_connection
      raise "No id server '#{name}' configured in database.yml" unless ActiveRecord::Base.configurations.to_h.has_key?(name)
      config = ActiveRecord::Base.configurations.to_h[name]
      c = config.symbolize_keys

      raise "No global_uid support for adapter #{c[:adapter]}" if c[:adapter] != 'mysql2'

      Timeout.timeout(connection_timeout, ConnectionTimeoutException) do
        ActiveRecord::Base.mysql2_connection(config)
      end
    rescue ConnectionTimeoutException => e
      GlobalUid::Base.notify(e, "Timed out establishing a connection to #{name}")
      nil
    rescue Exception => e
      GlobalUid::Base.notify(e, "establishing a connection to #{name}: #{e.message}")
      nil
    end
  end
end
