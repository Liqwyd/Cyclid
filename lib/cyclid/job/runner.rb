# Top level module for the core Cyclid code.
module Cyclid
  # Module for the Cyclid API
  module API
    # Module for Cyclid Job related classes
    module Job
      # Run a job
      class Runner
        include Constants::JobStatus

        def initialize(job_id, job_definition, notifier)
          # The notifier for updating the job status & writing to the log
          # buffer
          @notifier = notifier

          # Un-serialize the job
          begin
            @job = Oj.load(job_definition, symbol_keys: true)
            Cyclid.logger.debug "job=#{@job.inspect}"

            environment = @job[:environment]
          rescue StandardError => ex
            Cyclid.logger.error "couldn't un-serialize job for job ID #{job_id}"
            raise 'job failed'
          end

          begin
            # We're off!
            @notifier.status = WAITING

            # Create a Builder
            builder = get_builder(environment)

            # Obtain a host to run the job on
            build_host = get_build_host(builder)

            # Connect a transport to it; the notifier is a proxy to the log
            # buffer
            @transport = get_transport(build_host, @notifier)

            # Prepare the host
            builder.prepare(@transport, build_host, environment)
          rescue StandardError => ex
            Cyclid.logger.error "job runner failed: #{ex}"

            @notifier.status = FAILED
            @notifier.ended = Time.now.to_s

            builder.release(@transport, build_host) if build_host
            @transport.close if @transport

            raise # XXX Raise an internal exception
          end
        end

        def run
          status = STARTED
          @notifier.status = status

          # Run the Job stage actions
          stages = @job[:stages]
          sequence = @job[:sequence].first

          loop do
            # Find the stage
            raise 'stage not found' unless stages.key? sequence.to_sym

            # Un-serialize the stage into a StageView
            stage_definition = stages[sequence.to_sym]
            stage = Oj.load(stage_definition, symbol_keys: true)

            # Run the stage
            success, rc = run_stage(stage)

            Cyclid.logger.info "stage #{(success ? 'succeeded' :'failed')} and returned #{rc}"

            # Decide which stage to run next depending on the outcome of this
            # one
            if success
              sequence = stage.on_success
            else
              sequence = stage.on_failure

              # Remember the failure while the failure handlers run
              status = FAILING
              @notifier.status = status
            end

            # Stop if we have no further sequences
            break if sequence.nil?
          end

          # Either all of the stages succeeded, and thus the job suceeded, or
          # (at least one of) the stages failed, and thus the job failed
          if status == FAILING
            @notifier.status = FAILED
            success = false
          else
            @notifier.status = SUCCEEDED
            success = true
          end

          # We no longer require the build host & transport
          builder.release(@transport, build_host)
          @transport.close

          return success
        end

        private

        # Create a suitable Builder
        def get_builder(environment)
          # XXX Do we need a Builder per. Runner, or can we have a single
          # global Builder and let the get() method do all the hard work for
          # each Builder?
          builder_plugin = Cyclid.plugins.find('mist', Cyclid::API::Plugins::Builder)
          raise "couldn't find a builder plugin" unless builder_plugin

          builder = builder_plugin.new(os: environment[:os])
          raise "couldn't create a builder with environment #{environment}" \
            unless builder

          Cyclid.logger.debug "got a builder: #{builder.inspect}"

          return builder
        end

        # Acquire a build host from the builder
        def get_build_host(builder)
          # Request a BuildHost
          build_host = builder.get
          raise "couldn't obtain a build host" unless build_host

          return build_host
        end

        # Find a transport that can be used with the build host, create one and
        # connect them together
        def get_transport(build_host, log_buffer)
          # Create a Transport & connect it to the build host
          host, username, password = build_host.connect_info
          Cyclid.logger.debug "host: #{host} username: #{username} password: #{password}"

          # Try to match a transport that the host supports, to a transport we know how
          # to create; transports should be listed in the order they're preferred.
          transport_plugin = nil
          build_host.transports.each do |t|
            transport_plugin = Cyclid.plugins.find(t, Cyclid::API::Plugins::Transport)
          end

          raise "couldn't find a valid transport from #{build_host.transports}" \
            unless transport_plugin

          # Connect the transport to the build host
          transport = transport_plugin.new(host: host, user: username, password: password, log: log_buffer)
          raise "failed to connect the transport" unless transport

          return transport
        end

        # Perform each action defined in the steps of the given stage, until
        # either an action fails or we run out of steps
        def run_stage(stage)
          stage.steps.each do |step|
            begin
              # Un-serialize the Action for this step
              action = Oj.load(step[:action], symbol_keys: true)
            rescue StandardError => ex
              Cyclid.logger.error "couldn't un-serialize action for job ID #{job_id}"
              raise 'job failed'
            end

            # Run the action
            # XXX We need a proper job context! Should be a hash created
            # initialize (& updated by run?)
            action.prepare(transport: @transport, ctx: {})
            success, rc = action.perform(@notifier)

            return [false, rc] unless success
          end

          return [true, 0]
        end

      end
    end
  end
end