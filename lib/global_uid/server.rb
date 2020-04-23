module GlobalUid
  class Server

    attr_accessor :connection, :name, :retry_at, :new, :allocator

    def initialize(name)
      @connection = nil
      @name      = name
      @retry_at  = nil
      @new       = true
      @allocator = nil
    end

    def new?
      @new
    end

  end
end
