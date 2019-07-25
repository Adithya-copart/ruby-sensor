require "instana/version"
require 'instana/logger'
require "instana/util"
require "instana/helpers"

module Instana
  class << self
    attr_accessor :agent
    attr_accessor :collector
    attr_accessor :tracer
    attr_accessor :processor
    attr_accessor :config
    attr_accessor :logger
    attr_accessor :pid

    ##
    # setup
    #
    # Setup the Instana language agent to an informal "ready
    # to run" state.
    #
    def setup
      @agent  = ::Instana::Agent.new
      @tracer = ::Instana::Tracer.new
      @processor = ::Instana::Processor.new
      @collector = ::Instana::Collector.new
    end
  end
end

# Setup the logger as early as possible
::Instana.logger = ::Instana::XLogger.new(STDOUT)
::Instana.logger.info "Stan is on the scene.  Starting Instana instrumentation version #{::Instana::VERSION}"
