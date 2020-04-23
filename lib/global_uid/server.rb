module GlobalUid
  class Server

    attr_accessor :connection, :name, :retry_at, :new, :allocator, :increment_by

    def initialize(name, increment_by: , connection_retry:, connection_timeout:)
      @connection = nil
      @name      = name
      @retry_at  = nil
      @new       = true
      @allocator = nil
      @increment_by = increment_by
      @connection_retry = connection_retry
      @connection_timeout = connection_timeout
    end

    def connect
      return unless connection.nil?

      if new? || ( retry_at && Time.now > retry_at )
        @new = false

        begin
          @connection = mysql2_connection(name)

          if @connection.nil?
            @retry_at = Time.now + connection_retry
          else
            @allocator = Allocator.new(incrementing_by: increment_by, connection: @connection)
          end
        rescue InvalidIncrementException => e
          GlobalUid::Base.notify e, "#{e.message}"
          @connection = nil
        end
      end
    end

    private

    attr_accessor :connection_retry, :connection_timeout

    def new?
      @new
    end

    def mysql2_connection(name)
      raise "No id server '#{name}' configured in database.yml" unless ActiveRecord::Base.configurations.to_h.has_key?(name)
      config = ActiveRecord::Base.configurations.to_h[name]
      c = config.symbolize_keys

      raise "No global_uid support for adapter #{c[:adapter]}" if c[:adapter] != 'mysql2'

      begin
        Timeout.timeout(connection_timeout, ConnectionTimeoutException) do
          ActiveRecord::Base.mysql2_connection(config)
        end
      rescue ConnectionTimeoutException => e
        GlobalUid::Base.notify e, "Timed out establishing a connection to #{name}"
        nil
      rescue Exception => e
        GlobalUid::Base.notify e, "establishing a connection to #{name}: #{e.message}"
        nil
      end
    end

  end
end
