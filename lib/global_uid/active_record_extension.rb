module GlobalUid
  module ActiveRecordExtension

    def self.included(base)
      base.extend(ClassMethods)
      base.before_create :global_uid_before_create
    end

    def global_uid_before_create
      return if GlobalUid::Base.global_uid_options[:disabled]
      return if self.class.global_uid_disabled

      global_uid = self.class.get_reserved_global_uid
      if !global_uid
        realtime = Benchmark::realtime do
          global_uid = self.class.generate_uid
        end
      end

      if GlobalUid::Base.global_uid_options[:dry_run]
        ActiveRecord::Base.logger.info("GlobalUid dry-run: #{self.class.name}\t#{global_uid}\t#{"%.4f" % realtime}")
        return
      end

      # Morten, Josh, and Ben have discussed this particular line of code, whether "||=" or "=" is correct.
      # "||=" allows for more flexibility and more correct behavior (crashing) upon EBCAK
      self.id ||= global_uid
    end

    module ClassMethods
      def global_uid_disabled
        if @global_uid_disabled.nil?
          if superclass.respond_to?(:global_uid_disabled)
            @global_uid_disabled = superclass.send(:global_uid_disabled)
          else
            @global_uid_disabled = false
          end
        end

        @global_uid_disabled
      end

      def generate_uid(options = {})
        uid_table_name  = self.global_uid_table
        self.ensure_global_uid_table
        GlobalUid::Base.get_uid_for_class(self, options)
      end

      def disable_global_uid
        @global_uid_disabled = true
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

      def with_reserved_global_uids(n_to_reserve)
        old_should_reserve = @should_reserve_global_uids
        @should_reserve_global_uids = n_to_reserve
        yield
      ensure
        @should_reserve_global_uids = old_should_reserve
      end

      def get_reserved_global_uid
        @reserved_global_uids ||= []
        id = @reserved_global_uids.shift
        return id if id

        if @should_reserve_global_uids
          @reserved_global_uids += GlobalUid::Base.get_multiples_for_class(self, @should_reserve_global_uids)
          @reserved_global_uids.shift
        else
          nil
        end
      end

    end
  end
end
