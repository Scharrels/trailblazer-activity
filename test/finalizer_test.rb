require "test_helper"

class DrawGraphTest < Minitest::Spec
  Right = Circuit::Right
  Left  = Circuit::Left
  # Z = "bla"

  S = ->(*) { snippet }

  class A; end
  class E; end
  class B; end
  class C; end
  class F; end

  class ES; end
  class EF; end
=begin
[
  S: -R>
  R> A: -R> -L> a is magnetic to R (incoming)
]
=end


  # Mutable object to track what open lines are waiting to be connected
  # to a node.

  Magnetic = Trailblazer::Activity::Magnetic

  R = Magnetic::Output(Right, :success)
  L = Magnetic::Output(Left,  :failure)
  Z = Magnetic::Output("bla", :my_z)

  it do
    tripletts = [
      #  magnetic to
      #  color | signal|outputs
      [ [:success], A,  [R, L] ],
      [ [:failure], E, [] ],
      [ [:success], B, [R, L] ],
      [ [:success], C, [R, L] ],
      [ [:failure], F, [L, Z] ],
        [ [:my_z], S, [] ], # "connect"


      [ [:success], ES, [] ],
      [ [:failure], EF, [] ],
    ]

    graph = Trailblazer::Activity::Magnetic::Builder::Finalizer.adds_to_tripletts( tripletts )

    puts graph.inspect
    Inspect(graph.inspect).must_equal %{"{#<Trailblazer::Circuit::Start: @name=:default, @options={}>=>{Trailblazer::Circuit::Right=>DrawGraphTest::A}, DrawGraphTest::A=>{Trailblazer::Circuit::Left=>DrawGraphTest::E, Trailblazer::Circuit::Right=>DrawGraphTest::B}, DrawGraphTest::E=>{}, DrawGraphTest::B=>{Trailblazer::Circuit::Right=>DrawGraphTest::C, Trailblazer::Circuit::Left=>DrawGraphTest::F}, DrawGraphTest::C=>{Trailblazer::Circuit::Left=>DrawGraphTest::F, Trailblazer::Circuit::Right=>DrawGraphTest::ES}, DrawGraphTest::F=>{\\\"bla\\\"=>#<Proc:@test/draw_graph_test.rb:11 (lambda)>, Trailblazer::Circuit::Left=>DrawGraphTest::EF}, #<Proc:@test/draw_graph_test.rb:11 (lambda)>=>{}, DrawGraphTest::ES=>{}, DrawGraphTest::EF=>{}}"}
  end

  # A points to C
  it do
    tripletts = [
      #  magnetic to
      #  color | signal|outputs
      [ [:success], A,  [ Z, L ] ],
      [ [], B, [R, L] ],
      [ [:success, :my_z], C, [R, L] ],

      [ [:success], ES, [] ],
      [ [:failure], EF, [] ],
    ]

    graph = Trailblazer::Activity::Magnetic::Builder::Finalizer.adds_to_tripletts( tripletts )

    Inspect(graph.inspect).must_equal %{"{#<Trailblazer::Circuit::Start: @name=:default, @options={}>=>{Trailblazer::Circuit::Right=>DrawGraphTest::A}, DrawGraphTest::A=>{\\\"bla\\\"=>DrawGraphTest::C, Trailblazer::Circuit::Left=>DrawGraphTest::EF}, DrawGraphTest::B=>{Trailblazer::Circuit::Right=>DrawGraphTest::C, Trailblazer::Circuit::Left=>DrawGraphTest::EF}, DrawGraphTest::C=>{Trailblazer::Circuit::Right=>DrawGraphTest::ES, Trailblazer::Circuit::Left=>DrawGraphTest::EF}, DrawGraphTest::ES=>{}, DrawGraphTest::EF=>{}}"}
  end

  # circular
  it do
    tripletts = [
      [ [:success, :to_a], A, [ R, Magnetic::Output("SIG", :to_a) ] ],
      [ [:success], B, [ R ] ],

      [ [:success], ES, [] ],
      [ [:failure], EF, [] ],
    ]

    graph = Trailblazer::Activity::Magnetic::Builder::Finalizer.adds_to_tripletts( tripletts )

    Inspect(graph.inspect).must_equal %{"{#<Trailblazer::Circuit::Start: @name=:default, @options={}>=>{Trailblazer::Circuit::Right=>DrawGraphTest::A}, DrawGraphTest::A=>{\\\"SIG\\\"=>DrawGraphTest::A, Trailblazer::Circuit::Right=>DrawGraphTest::B}, DrawGraphTest::B=>{Trailblazer::Circuit::Right=>DrawGraphTest::ES}, DrawGraphTest::ES=>{}, DrawGraphTest::EF=>{}}"}
  end

  describe "Alterations" do
    it do
      alterations = Trailblazer::Activity::Schema::Alterations.new

      # happens in Operation::initialize_sequence
      alterations.add( :EF,  [ [:failure], EF, {} ], group: :end )
      alterations.add( :ES,  [ [:success], ES, {} ], group: :end )

      # step A
      alterations.add( :A,   [ [:success], A, [ Magnetic.Output(Right, :success), Magnetic.Output(Left, :failure) ] ] )

      # fail E, success: "End.success"
      alterations.add( :E,   [ [:failure], E, [ Magnetic.Output(Right, :failure, :success), Magnetic.Output(Left, :failure) ] ], )
      alterations.connect_to( :E, { success: "e_to_success" } )
      alterations.magnetic_to( :ES, ["e_to_success"] ) # existing target: add a "magnetic_to" to it!



      graph, _     = Trailblazer::Activity::Magnetic::Finalizer.( alterations.to_a )

puts graph

      Inspect(graph.inspect).must_equal %{"{#<Trailblazer::Circuit::Start: @name=:default, @options={}>=>{Trailblazer::Circuit::Right=>DrawGraphTest::A}, DrawGraphTest::A=>{Trailblazer::Circuit::Left=>DrawGraphTest::E, Trailblazer::Circuit::Right=>DrawGraphTest::ES}, DrawGraphTest::E=>{Trailblazer::Circuit::Left=>DrawGraphTest::EF, Trailblazer::Circuit::Right=>DrawGraphTest::ES}, DrawGraphTest::EF=>{}, DrawGraphTest::ES=>{}}"}
    end
  end

  it do
    dependencies = Trailblazer::Activity::Schema::Dependencies.new

    # happens in Operation::initialize_sequence
    dependencies.add( :EF,  [ [:failure], EF, [] ], group: :end )
    dependencies.add( :ES,  [ [:success], ES, [] ], group: :end )

    dependencies.add( :A,   [ [:success], A,  [R, L] ] )

    dependencies.add( :ES,  [ [:another_success], ES, [] ] ) # extend existing input.


    sequence = dependencies.to_a

    sequence.inspect.must_equal %{[[[:success], DrawGraphTest::A, [#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:success>, #<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Left, semantic=:failure>]], [[:another_success], DrawGraphTest::ES, []], [[:failure], DrawGraphTest::EF, []], [[:success], DrawGraphTest::ES, []]]}
  end
end



# * graph API is too low-level


# deleting
# "groups": insert before bla


# FAST_TRACK:
#  => add Output::Line instance(s) to outgoing                 before insert!ing on the Sequence
#  => add resp ends (:pass_fast, End::PassFast.new, [])        when do we do this? "override Sequence#to_a ?"


=begin
seq = Seq.new
 .insert!
 .insert! right_before: end_fail
 .insert!
 .insert!
 .insert! end_fail
 .insert! end_success
=end

=begin
Sequence::Dependencies.new
  .add Policy, id: "Policy", group: :prepend, // magnetic_to: [Input(:success), Input("Policy")], ...

[
  [{prepend}
    prepend!, Policy, magnetic_to: [Input(:success), Input("Policy")]
  ],
  [{step}
    insert!, A,                          Output(Right, :success), Output(Left, :failure)
    insert!, B,
    insert!, C, :success => End.special # will have special edge, not :railway ===>
                Output(Right, "End.special")
  ],
  [{end/append}
    append!, End.success,
    append!, End.failure,
    append!, End.pass_fast,  magnetic_to: Input(:success, "End.success")
    append!, End.special, magnetic_to: Input("End.special")
  ],
  [{unresolved}
    insert, F, before: End.success
  ]
]

=> Sequence

=> Instructions (for Drawer)
  here we need to take care of things like C has special color edge to End.special
=end
