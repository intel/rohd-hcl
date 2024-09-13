import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/uniquifier.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

class ClockGateControlInterface extends PairInterface {
  // TODO: maybe not even have the clock here? just control logic?

  final bool hasEnableOverride;
  Logic? get enableOverride => tryPort('en_override');

  final bool isPresent;

  static Logic defaultGenerateGatedClock(
    ClockGateControlInterface intf,
    Logic clk,
    Logic enable,
  ) =>
      clk &
      ([
        enable,
        if (intf.hasEnableOverride) intf.enableOverride!,
      ].swizzle().or());

  final Logic Function(
    ClockGateControlInterface intf,
    Logic clk,
    Logic enable,
  ) gatedClockGenerator;

  ClockGateControlInterface({
    this.isPresent = true,
    this.hasEnableOverride = false,
    List<Port>? additionalPorts,
    this.gatedClockGenerator = defaultGenerateGatedClock,
  }) : super(portsFromProvider: [
          if (hasEnableOverride) Port('en_override'),
          ...?additionalPorts,
        ]);

  ClockGateControlInterface.clone(ClockGateControlInterface otherInterface)
      : isPresent = otherInterface.isPresent,
        hasEnableOverride = otherInterface.hasEnableOverride,
        gatedClockGenerator = otherInterface.gatedClockGenerator,
        super.clone(otherInterface);

  // ClockGateControlInterface clone({bool? isPresent}) =>
  //     ClockGateControlInterface.clone(this);
}

class ClockGate extends Module {
  Map<Logic, Logic> _controlledCache = {};

  Logic controlled(Logic original, {dynamic resetValue}) {
    if (_controlIntf == null || !_controlIntf!.isPresent || !hasDelay) {
      return original;
    }

    if (_controlledCache.containsKey(original)) {
      return _controlledCache[original]!;
    } else {
      final o = super.addOutput(
          _uniquifier.getUniqueName(initialName: '${original.name}_delayed'));

      _controlledCache[original] = o;

      o <=
          flop(
            _clk,
            reset: _reset,
            resetValue: resetValue,
            super.addInput(
              _uniquifier.getUniqueName(initialName: original.name),
              original,
              width: original.width,
            ),
          );

      return o;
    }
  }

  final _uniquifier = Uniquifier();

  @override
  Logic addInput(String name, Logic x, {int width = 1}) {
    _uniquifier.getUniqueName(initialName: name, reserved: true);
    return super.addInput(name, x, width: width);
  }

  @override
  Logic addOutput(String name, {int width = 1}) {
    _uniquifier.getUniqueName(initialName: name, reserved: true);
    return super.addOutput(name, width: width);
  }

  late final Logic gatedClk;

  late final Logic _reset;

  late final Logic _enable;

  late final Logic _clk;

  late final ClockGateControlInterface? _controlIntf;

  final bool hasDelay;

  ClockGate(
    Logic clk, {
    required Logic enable,
    required Logic reset,
    ClockGateControlInterface? controlIntf,
    this.hasDelay = true,
    super.name = 'clock_gate',
  }) {
    // if this clock gating is not intended to be present, then just do nothing
    if (!(controlIntf?.isPresent ?? true)) {
      _controlIntf = null;
      gatedClk = clk;
      return;
    }

    _clk = addInput('clk', clk);
    _enable = addInput('enable', enable);

    if (controlIntf == null) {
      // if we are not provided an interface, make our own to use with default
      // configuration
      _controlIntf = ClockGateControlInterface();
    } else {
      _controlIntf = ClockGateControlInterface.clone(controlIntf)
        ..pairConnectIO(this, controlIntf, PairRole.consumer);
    }

    _reset = addInput('reset', reset);

    gatedClk = addOutput('gatedClk');

    _buildLogic();
  }

  void _buildLogic() {
    final internalEnable = _enable |
        ShiftRegister(
          _enable,
          clk: _clk,
          reset: _reset,

          resetValue: 1, // during reset, keep the clock enabled

          // always at least 1 cycle so we can caputure the last one, but also
          // an extra if there's a delay on the inputs relative to the enable
          depth: hasDelay ? 2 : 1,
        ).stages.swizzle().or() |

        // we want to enable the clock during reset so that synchronous resets
        // work properly
        _reset;

    gatedClk <=
        _controlIntf!.gatedClockGenerator(_controlIntf!, _clk, internalEnable);
  }
}
