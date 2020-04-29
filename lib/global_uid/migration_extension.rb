# frozen_string_literal: true
module GlobalUid
  module MigrationExtension

    def create_table(name, options = {}, &blk)
      uid_enabled = !(GlobalUid.configuration.disabled? || options[:use_global_uid] == false)

      # rules for stripping out auto_increment -- enabled and not a "PK-less" table
      remove_auto_increment = uid_enabled && !(options[:id] == false)

      options.merge!(:id => false) if remove_auto_increment

      super(name, options) { |t|
        t.column :id, "int(10) NOT NULL PRIMARY KEY" if remove_auto_increment
        blk.call(t) if blk
      }

      if uid_enabled
        id_table_name = options[:global_uid_table] || GlobalUid::Base.id_table_from_name(name)
        GlobalUid::Base.with_servers do |server|
          server.create_uid_table!(
            name: id_table_name,
            uid_type: options[:uid_type],
            start_id: options[:start_id]
          )
        end
      end

    end

    def drop_table(name, options = {})
      if !GlobalUid.configuration.disabled? && options[:use_global_uid] == true
        id_table_name = options[:global_uid_table] || GlobalUid::Base.id_table_from_name(name)
        GlobalUid::Base.with_servers do |server|
          server.drop_uid_table!(name: id_table_name)
        end
      end
      super(name, options)
    end
  end
end
