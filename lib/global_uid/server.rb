module GlobalUid
  class Server

    attr_accessor :cx, :name, :retry_at, :rand, :new, :allocator

    def initialize(name)
      @cx        = nil
      @name      = name
      @retry_at  = nil
      @rand      = rand
      @new       = true
      @allocator = nil
    end

    def new?
      @new
    end

  end
end
