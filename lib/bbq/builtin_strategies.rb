module Bbq
  module Spawn
    module IOStrategy
      class Squelch
        def initialize
#          reader, @writer = IO.pipe
        end

        def run(io)
#          io.stdout = io.stderr = @writer
          puts "kaboom"
        end

        def after_spawn
#          @writer.close
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
