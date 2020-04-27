module GlobalUid
  class ErrorTracker
    def call(exception)
      ActiveRecord::Base.logger.error("GlobalUID error: #{exception.class} #{exception.message}")
    end
  end
end
