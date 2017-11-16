module Trailblazer
  module Activity::Magnetic
    class Builder
      def self.build(options={}, &block)
        tripletts = plan( options, &block )

        circuit_hash = Generate.( tripletts )

        Activity.new( circuit_hash, end_events_for(circuit_hash) )
      end

      def self.end_events_for(circuit_hash)
        ary = circuit_hash.collect do |task, connections|
          task.kind_of?(Circuit::End) && connections.empty? ? [task, task.instance_variable_get(:@options)[:semantic]] : nil
        end

        Hash[ ary.compact ]
      end

      def initialize(strategy_options={})
        @strategy_options = strategy_options

        @sequence = DSL::Alterations.new
      end

      def draft # FIXME: discuss
        @sequence.to_a
      end

      def finalize # FIXME: discuss
        tripletts = draft
        circuit_hash = Trailblazer::Activity::Magnetic::Generate.( tripletts )
      end

      module DSLMethods
        #   Output( Left, :failure )
        #   Output( :failure ) #=> Output::Semantic
        def Output(signal, semantic=nil)
          return DSL::Output::Semantic.new(signal) if semantic.nil?

          Activity::Magnetic.Output(signal, semantic)
        end

        def End(name, semantic)
          Activity::Magnetic.End(name, semantic)
        end

        def Path(track_color: "track_#{rand}", end_semantic: :success, **options)
          options = options.merge(track_color: track_color, end_semantic: end_semantic)

          ->(block) { [ track_color, Path::Builder.plan( options, &block ) ] }
        end
      end

      include DSLMethods

      private


      # merge @strategy_options (for the track colors)
      # normalize options
      def add(strategy, task, options, &block)
        local_options, options = normalize(options, keywords)

        @sequence = DSL::ProcessElement.( @sequence, task, options, id: local_options[:id],
          # the strategy (Path.task) has nothing to do with (Output=>target) tuples
          strategy: [ strategy, @strategy_options.merge( local_options ) ],
          &block
        )
      end

      def normalize(options, local_keys)
        local, foreign = {}, {}
        options.each { |k,v| local_keys.include?(k) ? local[k] = v : foreign[k] = v }

        return local, foreign
      end
    end


    module FastTrack

    end
    class FastTrack::Builder < Builder
      def keywords
        [:id, :plus_poles, :fail_fast, :pass_fast, :fast_track]
      end

      def initialize(strategy_options={})
        sequence = super
        sequence = DSL::Path.initialize_sequence(sequence, strategy_options)
        sequence = DSL::Railway.initialize_sequence(sequence, strategy_options)
        sequence = DSL::FastTrack.initialize_sequence(sequence, strategy_options)

        @sequence = sequence
      end

      def step(*args, &block)
        add(DSL::FastTrack.method(:step), *args, &block)
      end
      def fail(*args, &block)
        add(DSL::FastTrack.method(:fail), *args, &block)
      end
      def pass(*args, &block)
        add(DSL::FastTrack.method(:pass), *args, &block)
      end
    end

    class Path
      class Builder < Builder
        # @return [Triplett]
        def self.plan(options={}, &block)
          builder = new(
            {
              plus_poles: DSL::PlusPoles.new.merge(
                # Magnetic.Output(Circuit::Right, :success) => :success
                Activity::Magnetic.Output(Circuit::Right, :success) => nil
              ).freeze,


            }.merge(options)
          )

          # TODO: pass new edge color in block?
          builder.instance_exec(&block)

          tripletts = builder.draft
        end

        def keywords
          [:id, :plus_poles]
        end

        # strategy_options:
        #   :track_color
        #   :end_semantic
        def initialize(strategy_options={})
          sequence = super
          sequence = DSL::Path.initialize_sequence(sequence, strategy_options)

          @sequence = sequence
        end

        def task(*args, &block)
          add( DSL::Path.method(:task), *args, &block )
        end
      end
    end # Builder
  end
end

