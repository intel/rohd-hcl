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

  /// FSM for completion states.
  @protected
  late final FiniteStateMachine<ApbCompleterState> fsm;

  /// Indicator that data from APB can be consumed downstream.
  /// This can be used as an input for the consuming logic.
  @protected
  late final Logic downstreamValid;

  /// Indicator that data from downstream is consumable on APB
  /// This must be properly driven in any child class.
  @protected
  late final Logic upstreamValid;

  /// Constructor.
  ApbCompleter({required ApbInterface apb, super.name = 'apb_completer'}) {
    this.apb = apb.clone()
      ..connectIO(this, apb,
          inputTags: {
            ApbDirection.fromRequester,
            ApbDirection.fromRequesterExceptSelect,
            ApbDirection.misc
          },
          outputTags: {ApbDirection.fromCompleter},
          uniquify: (orig) => '${name}_$orig');

    downstreamValid = Logic(name: 'downstreamValid');
    upstreamValid = Logic(name: 'downstreamValid');
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
          downstreamValid < 0,
        ],
      ),
      // SELECTED move when we get an ENABLE if the transaction has latency,
      //    move to ACCESS state if the transaction has no latency, can move
      //    directly back to IDLE for performance
      State(
        ApbCompleterState.selected,
        events: {
          this.apb.enable & ~upstreamValid: ApbCompleterState.access,
          this.apb.enable & upstreamValid: ApbCompleterState.idle,
        },
        actions: [
          downstreamValid < this.apb.enable,
        ],
      ),
      // ACCESS
      //    move to IDLE when the transaction is done
      State(
        ApbCompleterState.access,
        events: {
          upstreamValid: ApbCompleterState.idle,
        },
        actions: [
          downstreamValid < 1,
        ],
      ),
    ]);

    _build();
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
            upstreamValid;
  }
}

/// APB Completer that is meant to be used against CSRs
/// as defined in ROHD-HCL.
class ApbCsrCompleter extends ApbCompleter {
  /// How many APB clock cycles before we should indicate
  /// data is complete.
  late final int apbClkLatency;

  /// CSR frontdoor reads.
  late final DataPortInterface rd;

  /// CSR frontdoor writes.
  late final DataPortInterface wr;

  /// Constructor.
  ApbCsrCompleter(
      {required super.apb,
      required DataPortInterface csrRd,
      required DataPortInterface csrWr,
      this.apbClkLatency = 0,
      super.name}) {
    rd = csrRd.clone()
      ..connectIO(
        this,
        csrRd,
        inputTags: {DataPortGroup.data},
        outputTags: {DataPortGroup.control},
        uniquify: (original) => '${name}_rd_$original',
      );
    wr = csrWr.clone()
      ..connectIO(
        this,
        csrWr,
        inputTags: {},
        outputTags: {DataPortGroup.control, DataPortGroup.data},
        uniquify: (original) => '${name}_wr_$original',
      );

    buildCustomLogic();
  }

  /// Calculates a strobed version of data.
  Logic _strobeData(Logic originalData, Logic newData, Logic strobe) =>
      List.generate(
          strobe.width,
          (i) => mux(strobe[i], newData.getRange(i * 8, (i + 1) * 8),
              originalData.getRange(i * 8, (i + 1) * 8))).rswizzle();

  @override
  void buildCustomLogic() {
    // we drop the following APB inputs on the floor
    // apb.aUser;
    // apb.nse;
    // apb.prot;
    // apb.wUser;

    // drive downstream
    // reads must happen unconditionally for strobing
    rd.en <= downstreamValid;
    rd.addr <= apb.addr;

    wr.en <= downstreamValid & apb.write;
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
      upstreamValid <= rd.en | wr.en;
    }
    // non-zero latency operation
    else {
      upstreamValid <=
          ShiftRegister(rd.en | wr.en, clk: apb.clk, depth: apbClkLatency)
              .dataOut;
    }
  }
}
