require "bbq/spawn/version"
require "childprocess"
require "forwardable"
require "socket"
require "timeout"

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

      def initialize(executor, options = {})
        @executor = executor
        @timeout  = options.fetch(:timeout, 10)
        @banner   = options[:banner]
        @host     = options[:host]
        @port     = options[:port]

        @reader, @writer = IO.pipe
      end

      def start
        @executor.io.stdout = @executor.io.stderr = @writer
        @executor.start
        @writer.close
      end

      def join
        Timeout::timeout(@timeout) do
          wait_for_io if @banner
          wait_for_socket if @port and @host
        end
      rescue Timeout::Error
      end

      private
      def wait_for_io
        loop do
          case @reader.readpartial(8192)
          when @banner then break
          end
        end
      rescue EOFError
      end

      def wait_for_socket
        socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
        addr   = Socket.pack_sockaddr_in(@port, @host)

        socket.connect(addr)
      rescue Errno::ECONNREFUSED
        retry
      end
    end

    class Orchestrator
      def initialize
        @executors = []
      end

      def coordinate(executor, options = {})
        @executors << CoordinatedExecutor.new(executor, options)
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
