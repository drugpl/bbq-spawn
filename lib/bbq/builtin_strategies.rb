module Bbq
  module Spawn
    module IOStrategy
      class Squelch
        def initialize
          _, @writer = IO.pipe
        end

        def run(io)
          io.stdout = io.stderr = @writer
        end

        def after_spawn
          @writer.close
        end
      end

      class Inherit
        def run(io)
          io.inherit!
        end
      end
    end
  end
end
