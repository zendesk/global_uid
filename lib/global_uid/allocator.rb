module GlobalUid
  class Allocator
    attr_reader :recent_allocations, :max_window_size, :incrementing_by, :connection

    def initialize(incrementing_by:, connection:)
      @recent_allocations = []
      @max_window_size = 5
      @incrementing_by = incrementing_by
      @connection = connection
      validate_connection_increment
    end

    def allocate_one(table)
      identifier = connection.insert("REPLACE INTO #{table} (stub) VALUES ('a')")
      allocate(identifier)
    end

    def allocate_many(table, count:)
      return [] unless count > 0

      increment_by = validate_connection_increment

      start_id = connection.insert("REPLACE INTO #{table} (stub) VALUES " + (["('a')"] * count).join(','))
      identifiers = start_id.step(start_id + (count - 1) * increment_by, increment_by).to_a
      identifiers.each { |identifier| allocate(identifier) }
      identifiers
    end

    private

    def allocate(identifier)
      recent_allocations.shift if recent_allocations.size >= max_window_size
      recent_allocations << identifier

      if !valid_allocation?
        db_increment = connection.select_value("SELECT @@auto_increment_increment")
        message = "Configured: '#{incrementing_by}', Found: '#{db_increment}' on '#{connection.current_database}'. Recently allocated IDs: #{recent_allocations}"
        alert(InvalidIncrementException.new(message))
      end

      identifier
    end

    def valid_allocation?
      recent_allocations[1..-1].all? do |identifier|
        (identifier > recent_allocations[0]) &&
          (identifier - recent_allocations[0]) % incrementing_by == 0
      end
    end

    def validate_connection_increment
      db_increment = connection.select_value("SELECT @@auto_increment_increment")

      if db_increment != incrementing_by
        alert(InvalidIncrementException.new("Configured: '#{incrementing_by}', Found: '#{db_increment}' on '#{connection.current_database}'"))
      end

      db_increment
    end

    def alert(exception)
      if GlobalUid.configuration.suppress_increment_exceptions?
        GlobalUid::Base.notify(exception, exception.message)
      else
        raise exception
      end
    end
  end
end
