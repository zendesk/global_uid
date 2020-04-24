# frozen_string_literal: true
require "active_record"
require "active_support/all"
require "mysql2"
require "timeout"

module GlobalUid
  class Base
    def self.servers
      # Thread local storage is inheritted on `fork`, include the pid
      Thread.current["global_uid_servers_#{$$}"]
    end

    def self.servers=(s)
      Thread.current["global_uid_servers_#{$$}"] = s
    end

    def self.init_server_info
      GlobalUid.configuration.id_servers.map do |name|
        GlobalUid::Server.new(name,
          increment_by: GlobalUid.configuration.increment_by,
          connection_retry: GlobalUid.configuration.connection_retry,
          connection_timeout: GlobalUid.configuration.connection_timeout,
          query_timeout: GlobalUid.configuration.query_timeout
        )
      end.shuffle # so each process uses a random server
    end

    def self.disconnect!
      servers.each(&:disconnect!) unless servers.nil?
      self.servers = nil
    end

    def self.with_servers
      self.servers ||= init_server_info
      servers = self.servers.each(&:connect)

      if GlobalUid.configuration.connection_shuffling?
        servers.shuffle! # subsequent requests are made against different servers
      end

      errors = []
      servers.each do |server|
        begin
          yield server if server.active?
        rescue TimeoutException, Exception => e
          notify(e, e.message)
          errors << e
          server.disconnect!
          server.update_retry_at(1.minute)
        end
      end

      # in the case where all servers are gone, put everyone back in.
      if servers.all?(&:disconnected?)
        servers.each do |server|
          server.update_retry_at(0)
        end
        message = errors.empty? ? "" : "Errors hit: #{errors.map(&:to_s).join(', ')}"
        exception = NoServersAvailableException.new(message)
        notify(exception, message)
        raise exception
      end

      servers
    end

    def self.notify(exception, message)
      if GlobalUid.configuration.notifier
        GlobalUid.configuration.notifier.call(exception, message)
      end
    end

    def self.id_table_from_name(name)
      "#{name}_ids".to_sym
    end
  end
end
