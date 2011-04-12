module GlobalUid
  module ActiveRecordExtension

    def self.included(base)
      base.extend(ClassMethods)
      base.before_create :global_uid_before_create
    end

    def global_uid_before_create
      return if GlobalUid::Base.global_uid_options[:disabled]
      global_uid = nil
      realtime = Benchmark::realtime do
        global_uid = self.class.generate_uid
      end
      if GlobalUid::Base.global_uid_options[:dry_run]
        Rails.logger.info("GlobalUid dry-run: #{self.class.name}\t#{global_uid}\t#{"%.4f" % realtime}")
        return
      end

      self.id ||= global_uid
    end

    module ClassMethods
      def generate_uid(options = {})
        return if GlobalUid::Base.global_uid_options[:disabled]
        return if @_global_uid_disabled

        uid_table_name  = self.global_uid_table

        self.ensure_global_uid_table

        GlobalUid::Base.get_uid_for_class(self, options)
      end

      def disable_global_uid
        @_global_uid_disabled = true
      end

      def global_uid_table
        GlobalUid::Base.id_table_from_name(self.table_name)
      end

      def ensure_global_uid_table
        return @global_uid_table_exists if @global_uid_table_exists
        GlobalUid::Base.with_connections do |connection|
          raise "Global UID table #{global_uid_table} not found!" unless connection.table_exists?(global_uid_table)
        end
        @global_uid_table_exists = true
      end
    end
  end
end
