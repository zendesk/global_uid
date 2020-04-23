module GlobalUid
  class Server

    attr_accessor :cx, :name, :retry_at, :new, :allocator

    def initialize(name)
      @cx        = nil
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
