module Bbq
  module Spawn
    module IOStrategy
      class Squelch
        def initialize
          _, @writer = IO.pipe
        end

        def run(io)
          io.stdout = io.stderr = @writer
          @writer.close
        end
      end
    end
  end
end
