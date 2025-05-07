import 'package:rohd/rohd.dart';

class StateWithUpdates<StateIdentifier> extends State<StateIdentifier> {
  List<Conditional> updates;
  StateWithUpdates(super.identifier,
      {required super.events, required super.actions, this.updates = const []});
}

class FiniteStateMachineWithUpdates<StateIdentifier>
    extends FiniteStateMachine<StateIdentifier> {
  final Map<Logic, dynamic> updateResetValues;

  FiniteStateMachineWithUpdates(
    Logic clk,
    Logic reset,
    StateIdentifier resetState,
    List<State<StateIdentifier>> states, {
    bool asyncReset = false,
    List<Conditional> setupActions = const [],
    Map<Logic, dynamic> updateResetValues = const {},
  }) : this.multi([clk], reset, resetState, states,
            asyncReset: asyncReset,
            setupActions: setupActions,
            updateResetValues: updateResetValues);

  FiniteStateMachineWithUpdates.multi(List<Logic> clks, Logic reset,
      StateIdentifier resetState, List<State<StateIdentifier>> states,
      {super.asyncReset, super.setupActions, this.updateResetValues = const {}})
      : super.multi(
          clks,
          reset,
          resetState,
          states,
        ) {
    Sequential.multi(
      clks,
      reset: reset,
      asyncReset: asyncReset,
      resetValues: updateResetValues,
      [
        Case(
            currentState,
            states
                .whereType<StateWithUpdates<StateIdentifier>>()
                .map(
                  (state) => CaseItem(
                    label: state.identifier.toString(),
                    Const(stateIndexLookup[state.identifier], width: stateWidth)
                        .named(state.identifier.toString()),
                    state.updates,
                  ),
                )
                .toList(growable: false))
      ],
    );
  }
}
