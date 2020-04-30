module GlobalUid
  module TestSupport
    # Tables should be created through the MigrationExtension but
    # if you want to manually create and drop the '_id' tables,
    # you can do so via this module
    class << self
      def create_uid_tables(tables: [], uid_type: nil, start_id: nil)
        return if GlobalUid.disabled?

        GlobalUid::Base.with_servers do |server|
          tables.each do |table|
            server.create_uid_table!(
              name: GlobalUid::Base.id_table_from_name(table),
              uid_type: uid_type,
              start_id: start_id
            )
          end
        end
      end

      def drop_uid_tables(tables: [])
        return if GlobalUid.disabled?

        GlobalUid::Base.with_servers do |server|
          tables.each do |table|
            server.drop_uid_table!(
              name: GlobalUid::Base.id_table_from_name(table)
            )
          end
        end
      end

      def recreate_uid_tables(tables: [], uid_type: nil, start_id: nil)
        return if GlobalUid.disabled?

        drop_uid_tables(tables: tables)
        create_uid_tables(tables: tables, uid_type: nil, start_id: start_id)

        # Reset the servers, clearing any allocations from memory
        GlobalUid::Base.disconnect!
      end
    end
  end
end
