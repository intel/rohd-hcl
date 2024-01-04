import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/models/ready_valid_bfm/ready_valid_tracker.dart';
import 'package:rohd_vf/rohd_vf.dart';

class ReadyValidPacket extends SequenceItem implements Trackable {
  final LogicValue data;
  ReadyValidPacket(this.data);

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case ReadyValidTracker.timeField:
        return Simulator.time.toString();
      case ReadyValidTracker.dataField:
        return data.toString();
    }

    return null;
  }
}
