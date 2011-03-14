module EventedSpec
  module SpecHelper
    # Represents spec running inside EM.run loop
    class EMExample < EventedExample
      # Runs hooks of specified type (hopefully, inside the event loop)
      #
      def run_em_hooks(type)
        @example_group_instance.class.em_hooks[type].each do |hook|
          @example_group_instance.instance_eval(&hook) #_with_rescue(&hook)
        end
      end

      # Runs given block inside EM event loop.
      # Double-round exception handler needed because some of the exceptions bubble
      # outside of event loop due to asynchronous nature of evented examples
      #
      def run_em_loop
        begin
          EM.run do
            run_em_hooks :em_before

            @spec_exception = nil
            timeout(@opts[:spec_timeout]) if @opts[:spec_timeout]
            begin
              yield
            rescue Exception => @spec_exception
              # p "Inside loop, caught #{@spec_exception.class.name}: #{@spec_exception}"
              done # We need to properly terminate the event loop
            end
          end
        rescue Exception => @spec_exception
          # p "Outside loop, caught #{@spec_exception.class.name}: #{@spec_exception}"
          run_em_hooks :em_after # Event loop broken, but we still need to run em_after hooks
        ensure
          finish_example
        end
      end

      # Stops EM event loop. It is called from #done
      #
      def finish_em_loop
        run_em_hooks :em_after
        EM.stop_event_loop if EM.reactor_running?
      end


      def timeout(spec_timeout)
        EM.cancel_timer(@spec_timer) if @spec_timer
        @spec_timer = EM.add_timer(spec_timeout) do
          @spec_exception = SpecTimeoutExceededError.new "Example timed out"
          done
        end
      end

      # Run @block inside the EM.run event loop
      def run
        run_em_loop do
          @example_group_instance.instance_eval(&@block)
        end
      end

      # Breaks the EM event loop and finishes the spec.
      # Done yields to any given block first, then stops EM event loop.
      #
      def done(delay = nil)
        delayed(delay) do
          yield if block_given?
          EM.next_tick do
            finish_em_loop
          end
        end
      end # done

      def delayed(delay, &block)
        if delay
          EM.add_timer delay, &block
        else
          yield
        end
      end # delayed
    end # class EMExample < EventedExample
  end # module SpecHelper
end # module EventedSpec