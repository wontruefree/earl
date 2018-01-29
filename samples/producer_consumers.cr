require "../src/earl"

alias Message = Int32

class Consumer
  include Earl::Actor
  include Earl::Mailbox(Message)

  def initialize(@id : Int32)
  end

  def call
    while message = receive?
      puts "client id=#{@id} received=#{message} (#{message.class.name})"
    end
  end
end

class Producer
  include Earl::Actor
  include Earl::Registry(Consumer, Message)

  def initialize
    @i = 0
  end

  def call
    while running?
      registry.send(@i += 1)
      sleep 0.5
      raise "chaos monkey" if rand(0..9) == 1
    end
  end

  def terminate
    registry.stop
  end

  def reset
    @i = 0
  end
end

supervisor = Earl::Supervisor.new

queue = Producer.new
supervisor.monitor(queue)

2.times do |id|
  client = Consumer.new(id)
  queue.register(client)
  client.spawn
end

Signal::INT.trap do
  if supervisor.stopping?
    Earl.logger.warn "forced interruption"
    exit 1
  else
    supervisor.stop
  end
end

supervisor.start