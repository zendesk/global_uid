# frozen_string_literal: true
module GlobalUid
  module ActiveRecordExtension

    def self.included(base)
      base.extend(ClassMethods)
      base.before_create :global_uid_before_create
    end

    def global_uid_before_create
      return if GlobalUid::Base.global_uid_options[:disabled]
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

      def generate_uid(options = {})
        GlobalUid::Base.get_uid_for_class(self, options)
      end

      def generate_many_uids(count, options = {})
        GlobalUid::Base.get_many_uids_for_class(self, count, options)
      end

      def disable_global_uid
        @global_uid_disabled = true
      end

      def enable_global_uid
        @global_uid_disabled = false
      end

      def global_uid_table
        GlobalUid::Base.id_table_from_name(self.table_name)
      end
    end
  end
end
