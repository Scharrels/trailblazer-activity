module Trailblazer
  class Activity::Process
    # The executable run-time instance for an Activity.
    def initialize(circuit_hash, outputs)
      @default_start_event = circuit_hash.keys.first
      @circuit             = Circuit.new(circuit_hash, outputs.keys, {})
    end

    def call(args, task: @default_start_event, **circuit_options)
      @circuit.(
        args,
        circuit_options.merge( task: task ) , # this passes :runner to the {Circuit}.
      )
    end
  end
end
