module GlobalUid
  class Server

    attr_accessor :connection, :name, :allocator

    def initialize(name, increment_by:, connection_retry:, connection_timeout:)
      @connection = nil
      @name = name
      @retry_at = nil
      @allocator = nil
      @increment_by = increment_by
      @connection_retry = connection_retry
      @connection_timeout = connection_timeout
    end

    def connect
      return @connection if active? || !retry_connection?
      @connection = mysql2_connection(name)

      begin
        @allocator = Allocator.new(incrementing_by: increment_by, connection: @connection) if active?
      rescue InvalidIncrementException => e
        GlobalUid::Base.notify(e, "#{e.message}")
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
      @allocator = nil
    end

    private

    attr_accessor :connection_retry, :connection_timeout, :retry_at, :increment_by

    def retry_connection?
      return Time.now > retry_at if retry_at

      update_retry_at(connection_retry)
      true
    end

    def mysql2_connection(name)
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
