require "bbq/spawn/version"
require "childprocess"
require "forwardable"

module Bbq
  module Spawn
    class Executor
      extend Forwardable

      def_delegators :@process, :start, :stop

      def initialize(*args)
        @process = ChildProcess.build(*args)
        yield @process if block_given?
        @process
      end
    end

    class Orchestrator
      def initialize
        @executors = []
      end

      def coordinate(executor, wait_banner = nil)
        @executors << executor
      end

      def start
        @executors.each { |exec| exec.start }
      end

      def stop
        @executors.each { |exec| exec.stop }
      end
    end
  end
end
