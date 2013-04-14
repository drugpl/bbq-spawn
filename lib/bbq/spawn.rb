require "bbq/spawn/version"
require "childprocess"
require "forwardable"

module Bbq
  module Spawn
    class Executor
      extend Forwardable

      def_delegators :@process, :start, :stop, :io

      def initialize(*args)
        @process = ChildProcess.build(*args)
        yield @process if block_given?
        @process
      end
    end

    class CoordinatedExecutor
      extend Forwardable

      def_delegators :@executor, :stop

      def initialize(executor, banner)
        @executor = executor
        @banner   = banner
        @reader, @writer = IO.pipe
      end

      def start
        @executor.io.stdout = @executor.io.stderr = @writer
        @executor.start
        @writer.close
      end

      def join
        return unless @banner
        loop do
          case @reader.readpartial(8192)
          when @banner then break
          end
        end
      rescue EOFError
      end
    end

    class Orchestrator
      def initialize
        @executors = []
      end

      def coordinate(executor, wait_banner = nil)
        @executors << CoordinatedExecutor.new(executor, wait_banner)
      end

      def start
        @executors.each(&:start)
        @executors.each(&:join)
      end

      def stop
        @executors.each(&:stop)
      end
    end
  end
end
