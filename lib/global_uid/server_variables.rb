# frozen_string_literal: true
# This module is good for testing and development, not so much for production.
# Please note that this is unreliable -- if you lose your CX to the server
# and auto-reconnect, you will be utterly hosed.  Much better to dedicate a server
# or two to the cause, and set their auto_increment_increment globally.
#
# You can include this module in tests like this:
#   GlobalUid::Base.extend(GlobalUid::ServerVariables)
#
module GlobalUid
  module ServerVariables

    def self.extended(base)
      base.singleton_class.send(:alias_method, :new_connection_without_server_variables, :new_connection)
      base.singleton_class.send(:alias_method, :new_connection, :new_connection_with_server_variables)
    end

    def new_connection_with_server_variables(name, connection_timeout, offset, increment_by)
      con = new_connection_without_server_variables(name, connection_timeout, offset, increment_by)

      if con
        con.execute("set @@auto_increment_increment = #{increment_by}")
        con.execute("set @@auto_increment_offset = #{offset}")
      end

      con
    end

  end
end
