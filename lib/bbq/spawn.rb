require "bbq/spawn/version"
require 'bbq/builtin_strategies'
require "childprocess"
require "forwardable"
require "socket"
require "timeout"
require "uri"
require "net/http"

module Bbq
  module Spawn
    class Executor
      extend Forwardable

      attr_accessor :io_strategy

      def_delegators :@process, :start, :stop, :io

      def initialize(*args)
        @strategy = :mute
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
        @url      = options[:url]

        @reader, @writer = IO.pipe

        @strategy = options[:strategy] || IOStrategy::Squelch.new(@writer)
      end

      def start
        @strategy.run(@executor.io)
        @executor.start
        @strategy.after_run if @strategy.respond_to? :after_run
      end

      def join
        Timeout.timeout(@timeout) do
          wait_for_io       if @banner
          wait_for_socket   if @port and @host
          wait_for_response if @url
        end
      end

      private
      def wait_for_io
        loop do
          output = @reader.readpartial(8192)
          break if output.include?(@banner)
        end
      rescue EOFError
      end

      def wait_for_socket
        socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
        addr   = Socket.pack_sockaddr_in(@port, @host)

        socket.connect(addr)
      rescue Errno::ECONNREFUSED
        retry
      ensure
        socket.close
      end

      def wait_for_response
        uri = URI.parse(@url)
        begin
          Net::HTTP.start(uri.host, uri.port) do |http|
            http.open_timeout = 5
            http.read_timeout = 5
            http.head(uri.path)
          end
        rescue SocketError, IOError, Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError
          retry
        end
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
