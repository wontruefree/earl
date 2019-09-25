require "../agent"
require "../mailbox"
require "./severity"
require "./backend"

module Earl
  module Logger
    # :nodoc:
    class Actor
      include Agent
      include Mailbox({Severity, Agent, Time, String})

      property level : Severity

      # TODO: use a concurrency-safe array (e.g. copy-on-write array)
      property backends : Array(Backend)

      def initialize(@level, backend : Backend)
        @backends = [backend] of Backend
        @close_mailbox_on_stop = false
      end

      def call : Nil
        while mail = receive?
          severity, agent, time, message = mail

          unless severity < @level
            backends.each(&.write(severity, agent, time, message))
          end
        end
      end

      {% for name in Severity.constants %}
        def {{name.id.downcase}}? : Bool
          Severity::{{name.id}} >= @level
        end
      {% end %}

      def terminate
        until mailbox.@capacity == 0
          Fiber.yield
        end
      end
    end
  end
end
