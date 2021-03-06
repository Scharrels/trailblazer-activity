module Trailblazer
  module Activity::Magnetic
    class Builder
      class Railway < Builder
        def self.keywords
          [:type]
        end

        def initialize(normalizer, builder_options={})
          builder_options = { # Ruby's kw args kind a suck.
            track_color: :success, end_semantic: :success, failure_color: :failure,
          }.merge(builder_options)

          super

          add!(
            Railway.InitialAdds( builder_options )   # add start, success end and failure end.
          )
        end

        def step(task, options={}, &block)
          insert_element!( Railway, Railway.StepPolarizations(@builder_options), task, options, &block )
        end

        def fail(task, options={}, &block)
          insert_element!( Railway, Railway.FailPolarizations(@builder_options), task, options, &block )
        end

        def pass(task, options={}, &block)
          insert_element!( Railway, Railway.PassPolarizations(@builder_options), task, options, &block )
        end

        def self.DefaultPlusPoles
          DSL::PlusPoles.new.merge(
            Activity::Magnetic.Output(Circuit::Right, :success) => nil,
            Activity::Magnetic.Output(Circuit::Left,  :failure) => nil,
          ).freeze
        end

        # Adds the End.failure end to the Path sequence.
        # @return [Adds] list of Adds instances that can be chained or added to an existing sequence.
        def self.InitialAdds(failure_color:raise, failure_end: Activity::Magnetic.End(failure_color, :failure), **builder_options)
          path_adds = Path.InitialAdds(**builder_options)

          end_adds = adds(
            "End.#{failure_color}", failure_end,

            {}, # plus_poles
            Path::TaskPolarizations(builder_options.merge( type: :End )),
            [],

            {},
            { group: :end },
            [failure_color]
          )

          path_adds + end_adds
        end

        # ONLY JOB: magnetic_to and Outputs ("Polarization") via PlusPoles.merge
        def self.StepPolarizations(**options)
          [
            *Path.TaskPolarizations(options),
            StepPolarization.new(options)
          ]
        end

        def self.PassPolarizations(options)
          [
            Railway::PassPolarization.new( options )
          ]
        end

        def self.FailPolarizations(options)
          [
            Railway::FailPolarization.new( options )
          ]
        end

        class StepPolarization
          def initialize(track_color: :success, failure_color: :failure, **o)
            @track_color, @failure_color = track_color, failure_color
          end

          def call(magnetic_to, plus_poles, options)
            [
              [@track_color],
              plus_poles.reconnect( :failure => @failure_color )
            ]
          end
        end

        class PassPolarization < StepPolarization
          def call(magnetic_to, plus_poles, options)
            [
              [@track_color],
              plus_poles.reconnect( :failure => @track_color, :success => @track_color )
            ]
          end
        end

        class FailPolarization < StepPolarization
          def call(magnetic_to, plus_poles, options)
            [
              [@failure_color],
              plus_poles.reconnect( :failure => @failure_color, :success => @failure_color )
            ]
          end
        end

      end # Railway
    end # Builder
  end
end
