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
          @connection = GlobalUid::Base.new_connection(name, connection_timeout)

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

  end
end
