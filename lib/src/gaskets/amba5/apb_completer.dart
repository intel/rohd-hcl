import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// For APB completion.
enum ApbCompleterState {
  /// Waiting for a transaction.
  idle,

  /// Selected, waiting for transaction enable.
  selected,

  /// Executing the transaction.
  access,
}

/// A generic implementation for an APB Completer.
abstract class ApbCompleter extends Module {
  /// APB interface.
  late final ApbInterface apb;

  /// Some arbitrary downstream interface.
  late final List<Interface<Enum>> downstream;

  @protected

  /// FSM for completion states.
  late final FiniteStateMachine<ApbCompleterState> fsm;

  @protected

  /// Indicator that data from APB can be consumed downstream.
  /// This can be used as an input for the consuming logic.
  late final Logic downstreamDataReady;

  @protected

  /// Indicator that data from downstream is consumable on APB
  /// This must be properly driven in any child class.
  late final Logic upstreamDataReady;

  /// Constructor.
  ApbCompleter(
      {required ApbInterface apb,
      required List<Interface<Enum>> downstream,
      super.name = 'apb_completer',
      List<Iterable<Enum>?> downstreamInputTags = const [],
      List<Iterable<Enum>?> downstreamOutputTags = const []}) {
    this.apb = apb.clone()
      ..connectIO(this, apb,
          inputTags: {
            ApbDirection.fromRequester,
            ApbDirection.fromRequesterExceptSelect,
            ApbDirection.misc
          },
          outputTags: {ApbDirection.fromCompleter},
          uniquify: (orig) => '${name}_$orig');
    for (var i = 0; i < downstream.length; i++) {
      this.downstream.add(downstream[i].clone()
        ..connectIO(
          this,
          downstream[i],
          inputTags:
              (i < downstreamInputTags.length ? downstreamInputTags[i] : null),
          outputTags: (i < downstreamOutputTags.length
              ? downstreamOutputTags[i]
              : null),
          uniquify: (original) => '${name}_orig',
        ));
    }

    downstreamDataReady = Logic(name: 'downstreamDataReady');
    upstreamDataReady = Logic(name: 'downstreamDataReady');
    fsm = FiniteStateMachine<ApbCompleterState>(
        this.apb.clk, ~this.apb.resetN, ApbCompleterState.idle, [
      // IDLE
      //    move to SELECTED when we get a SELx
      State(
        ApbCompleterState.idle,
        events: {
          this.apb.sel[0] & ~this.apb.enable: ApbCompleterState.selected,
        },
        actions: [
          downstreamDataReady < 0,
        ],
      ),
      // SELECTED move when we get an ENABLE if the transaction has latency,
      //    move to ACCESS state if the transaction has no latency, can move
      //    directly back to IDLE for performance
      State(
        ApbCompleterState.selected,
        events: {
          this.apb.enable & ~upstreamDataReady: ApbCompleterState.access,
          this.apb.enable & upstreamDataReady: ApbCompleterState.idle,
        },
        actions: [
          downstreamDataReady < this.apb.enable,
        ],
      ),
      // ACCESS
      //    move to IDLE when the transaction is done
      State(
        ApbCompleterState.access,
        events: {
          upstreamDataReady: ApbCompleterState.idle,
        },
        actions: [
          downstreamDataReady < 1,
        ],
      ),
    ]);

    _build();
    buildCustomLogic();
  }

  /// User hook to deal with downstream.
  /// Must be implemented by the user.
  void buildCustomLogic();

  // no power management built in so we ignore apb.wakeup if present
  void _build() {
    apb.ready <=
        (fsm.currentState.eq(Const(ApbCompleterState.selected.index,
                    width: fsm.currentState.width)) |
                fsm.currentState.eq(Const(ApbCompleterState.access.index,
                    width: fsm.currentState.width))) &
            upstreamDataReady;
  }
}

/// APB Completer that is meant to be used against CSRs
/// as defined in ROHD-HCL.
class ApbCsrCompleter extends ApbCompleter {
  /// How many APB clock cycles before we should indicate
  /// data is complete.
  late final int apbClkLatency;

  /// Constructor.
  ApbCsrCompleter(
      {required super.apb,
      required DataPortInterface csrRd,
      required DataPortInterface csrWr,
      this.apbClkLatency = 0,
      super.name})
      : super(downstream: [
          csrRd,
          csrWr
        ], downstreamInputTags: [
          {DataPortGroup.control},
          {DataPortGroup.control, DataPortGroup.data}
        ], downstreamOutputTags: [
          {DataPortGroup.data},
          {}
        ]);

  /// Calculates a strobed version of data.
  Logic _strobeData(Logic originalData, Logic newData, Logic strobe) =>
      List.generate(
          strobe.width,
          (i) => mux(strobe[i], newData.getRange(i * 8, (i + 1) * 8),
              originalData.getRange(i * 8, (i + 1) * 8))).rswizzle();

  @override
  void buildCustomLogic() {
    final rd = downstream[0] as DataPortInterface;
    final wr = downstream[1] as DataPortInterface;

    // we drop the following APB inputs on the floor
    // apb.aUser;
    // apb.nse;
    // apb.prot;
    // apb.wUser;

    // drive downstream
    // reads must happen unconditionally for strobing
    rd.en <= downstreamDataReady;
    rd.addr <= apb.addr;

    wr.en <= downstreamDataReady & apb.write;
    wr.addr <= apb.addr;
    wr.data <= _strobeData(rd.data, apb.wData, apb.strb);

    // drive APB output
    apb.rData <= rd.data;

    // NOP outputs
    apb.slvErr?.gets(Const(0, width: apb.slvErr?.width));
    apb.bUser?.gets(Const(0, width: apb.bUser?.width));
    apb.rUser?.gets(Const(0, width: apb.rUser?.width));

    // zero latency operation
    if (apbClkLatency == 0) {
      upstreamDataReady <= rd.en | wr.en;
    }
    // non-zero latency operation
    else {
      upstreamDataReady <=
          ShiftRegister(rd.en | wr.en, clk: apb.clk, depth: apbClkLatency)
              .dataOut;
    }
  }
}
