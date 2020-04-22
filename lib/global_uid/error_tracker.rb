module GlobalUid
  class ErrorTracker
    def notify(exception)
      ActiveRecord::Base.logger.error("GlobalUID error: #{exception.class} #{exception.message}")
    end
  end
end
