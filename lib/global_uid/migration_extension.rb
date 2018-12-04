# frozen_string_literal: true
module GlobalUid
  module MigrationExtension

    def create_table(name, options = {}, &blk)
      uid_enabled = !(GlobalUid::Base.global_uid_options[:disabled] || options[:use_global_uid] == false)

      # rules for stripping out auto_increment -- enabled, not dry-run, and not a "PK-less" table
      remove_auto_increment = uid_enabled && !GlobalUid::Base.global_uid_options[:dry_run] && !(options[:id] == false)

      options.merge!(:id => false) if remove_auto_increment

      super(name, options) { |t|
        if remove_auto_increment
          # need to honor specifically named tables
          id_column_name = options.fetch(:id_column_name, :id)
          t.column id_column_name, "int(10) NOT NULL PRIMARY KEY"
        end
        blk.call(t) if blk
      }

      if uid_enabled
        id_table_name = options[:global_uid_table] || GlobalUid::Base.id_table_from_name(name)
        GlobalUid::Base.create_uid_tables(id_table_name, options)
      end

    end

    def drop_table(name, options = {})
      if !GlobalUid::Base.global_uid_options[:disabled] && options[:use_global_uid] == true
        id_table_name = options[:global_uid_table] || GlobalUid::Base.id_table_from_name(name)
        GlobalUid::Base.drop_uid_tables(id_table_name,options)
      end
      super(name, options)
    end
  end
end
