# frozen_string_literal: true
module GlobalUid
  module SchemaDumperExtension
    def table(table, stream)
      io = super(table, StringIO.new)
      schema = io.string

      pk = get_pk(table)
      columns = @connection.columns(table)

      pkcol = columns.detect { |c| c.name == pk }
      use_global_uid = !(pkcol.extra =~ /auto/i)

      schema.sub!(/(create_table.*) do/, "\\1, use_global_uid: #{use_global_uid.inspect} do")
      stream.write(schema)
      stream
    end

    def get_pk(table)
      if @connection.respond_to?(:pk_and_sequence_for)
        pk, _ = @connection.pk_and_sequence_for(table)
      elsif @connection.respond_to?(:primary_key)
        pk = @connection.primary_key(table)
      end
      pk
    end
  end
end
