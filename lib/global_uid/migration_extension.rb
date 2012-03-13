module GlobalUid
  module MigrationExtension
    def self.included(base)
      base.alias_method_chain :create_table, :global_uid
      base.alias_method_chain :drop_table, :global_uid
    end

    def create_table_with_global_uid(name, options = {}, &blk)
      uid_enabled = !(GlobalUid::Base.global_uid_options[:disabled] || options[:use_global_uid] == false)

      # rules for stripping out auto_increment -- enabled, not dry-run, and not a "PK-less" table
      remove_auto_increment = uid_enabled && !GlobalUid::Base.global_uid_options[:dry_run] && !(options[:id] == false)

      if remove_auto_increment
        old_id_option = options[:id]
        options.merge!(:id => false)
      end

      if uid_enabled
        id_table_name = options[:global_uid_table] || GlobalUid::Base.id_table_from_name(name)
        GlobalUid::Base.create_uid_tables(id_table_name, options)
      end

      create_table_without_global_uid(name, options) { |t|
        if remove_auto_increment
          # need to honor specifically named tables
          id_column_name = (old_id_option || :id)
          t.column id_column_name, "int(10) NOT NULL PRIMARY KEY"
        end
        blk.call(t) if blk
      }
    end

    def drop_table_with_global_uid(name, options = {})
      if !GlobalUid::Base.global_uid_options[:disabled] && options[:use_global_uid] == true
        id_table_name = options[:global_uid_table] || GlobalUid::Base.id_table_from_name(name)
        GlobalUid::Base.drop_uid_tables(id_table_name,options)
      end
      drop_table_without_global_uid(name)
    end

  end
end
