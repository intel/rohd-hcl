import 'package:rohd_hcl/src/models/models.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A tracker for a ready/valid protocol.
class ReadyValidTracker extends Tracker<ReadyValidPacket> {
  /// Tracker field for simulation time.
  static const timeField = 'time';

  /// Tracker field for data.
  static const dataField = 'data';

  /// Creates a new tracker for a ready/valid protocol.
  ReadyValidTracker({
    String name = 'readyValidTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    int dataColumnWidth = 14,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          TrackerField(dataField, columnWidth: dataColumnWidth),
        ]);
}
