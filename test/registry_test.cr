require "./test_helper"

class Consumer
  include Earl::Agent
  include Earl::Logger
  include Earl::Mailbox(Int32)

  def call : Nil
    while message = receive?
      log.info "received: #{message}"
    end
  end
end

class Producer
  include Earl::Agent

  def initialize
    @registry = Earl::Registry(Consumer, Int32).new
  end

  def register(agent)
    @registry.register(agent)
  end

  def unregister(agent)
    @registry.unregister(agent)
  end

  def call : Nil
    0.upto(999) do |i|
      @registry.send(i)
    end
  end

  def terminate
    @registry.stop
  end
end

module Earl
  class RegistryTest < Minitest::Test
    def test_registry
      producer = Producer.new

      5.times do
        consumer = Consumer.new
        producer.register(consumer)
        consumer.spawn
      end

      producer.start
    end
  end
end
