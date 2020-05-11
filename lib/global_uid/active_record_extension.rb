# frozen_string_literal: true
module GlobalUid
  module ActiveRecordExtension

    def self.included(base)
      base.extend(ClassMethods)
      base.before_create :global_uid_before_create
    end

    def global_uid_before_create
      return if GlobalUid.disabled?
      return if self.class.global_uid_disabled

      self.id = self.class.generate_uid
    end

    module ClassMethods
      def global_uid_disabled
        if !defined?(@global_uid_disabled) || @global_uid_disabled.nil?
          if superclass.respond_to?(:global_uid_disabled)
            @global_uid_disabled = superclass.send(:global_uid_disabled)
          else
            @global_uid_disabled = false
          end
        end

        @global_uid_disabled
      end

      def generate_uid
        GlobalUid::Base.with_servers do |server|
          return server.allocate(self)
        end
      end

      def generate_many_uids(count)
        GlobalUid::Base.with_servers do |server|
          return server.allocate(self, count: count)
        end
      end

      def disable_global_uid
        @global_uid_disabled = true
      end

      def enable_global_uid
        @global_uid_disabled = false
      end

      def global_uid_table
        @_global_uid_table ||= GlobalUid::Base.id_table_from_name(self.table_name)
      end
    end
  end
end
