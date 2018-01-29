require "mutex"
require "./actor"

module Earl
  class Pool(A, M)
    include Actor

    def initialize(@capacity : Int32)
      @actors = Array(A).new(@capacity)
      @channel = Channel(M).new
      @mutex = Mutex.new
      @fiber = nil
    end

    def call : Nil
      @capacity.times do
        spawn do
          actor = A.new
          @mutex.synchronize { @actors << actor }

          while actor.starting?
            actor.mailbox = @channel
            actor.start(link: self)
          end
        end
      end

      @fiber = Fiber.current
      Scheduler.reschedule

      until @actors.empty?
        Fiber.yield
      end
    end

    def trap(actor : A, exception : Exception?) : Nil
      if exception
        Earl.logger.debug "#{self.class.name} worker failed message=#{exception.message} (#{exception.class.name})"
        return actor.recycle if running?
      end
      @mutex.synchronize { @actors.delete(actor) }
    end

    def send(message : M) : Nil
      @channel.send(message)
    end

    def terminate : Nil
      @channel.close

      @actors.each do |actor|
        begin
          actor.stop
        rescue ex
        end
      end

      if fiber = @fiber
        @fiber = nil
        Scheduler.enqueue(fiber)
      end
    end
  end
end