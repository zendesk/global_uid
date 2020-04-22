module GlobalUid
  class Configuration

    attr_accessor :connection_timeout
    attr_accessor :connection_retry
    attr_accessor :notifier
    attr_accessor :query_timeout
    attr_accessor :increment_by
    attr_accessor :disabled
    attr_accessor :per_process_affinity
    attr_accessor :suppress_increment_exceptions
    attr_accessor :storage_engine

    alias_method :disabled?, :disabled
    alias_method :per_process_affinity?, :per_process_affinity
    alias_method :suppress_increment_exceptions?, :suppress_increment_exceptions

    # Set defaults
    def initialize
      # Timeout (in seconds) for connecting to a global UID server
      @connection_timeout = 3

      # Duration (in seconds) to wait before attempting another connection to UID server
      @connection_retry = 600 # 10 minutes

      # This proc is called with two parameters upon UID server failure -- an exception and a message
      @notifier = Proc.new { |exception, message| ActiveRecord::Base.logger.error("GlobalUID error: #{exception.class} #{message}") }

      # Timeout (in seconds) for retrieving a global UID from a server before moving to the next server
      @query_timeout = 10

      # Used for validation, compared with the value on the alloc servers to prevent allocation of duplicate IDs
      #   NB: The value configured here does not dictate the value on your alloc server and must remain in
      #       sync with the value of auto_increment_increment in the database.
      @increment_by = 5

      # Disable GlobalUid entirely
      @disabled = false

      # Select alloc server from list of configured `id_servers` at random
      @per_process_affinity = true

      # Suppress configuration validation, allowing updates to auto_increment_increment while alloc servers in use.
      # The InvalidIncrementException will be swallowed and logged when suppressed
      @suppress_increment_exceptions = false

      # The name of the alloc DB servers, defined in your database.yml
      # e.g. ["id_server_1", "id_server_2"]
      @id_servers = []

      # The storage engine used during GloblaUid table creation
      # Supported and tested: InnoDB, MyISAM
      @storage_engine = "MyISAM"
    end

    def id_servers=(value)
      raise "More servers configured than increment_by: #{value.size} > #{increment_by} -- this will create duplicate IDs." if value.size > increment_by
      @id_servers = value
    end

    def id_servers
      raise "You haven't configured any id servers" if @id_servers.empty?
      @id_servers
    end
  end
end
