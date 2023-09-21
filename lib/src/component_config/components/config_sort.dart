import 'package:rohd/rohd.dart';
// ignore: implementation_imports
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

class BitonicSortConfigurator extends Configurator {
  final lengthOfListKnob = IntConfigKnob(value: 4);
  final logicWidthKnob = IntConfigKnob(value: 16);
  final isAscendingKnob = ToggleConfigKnob(value: true);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = {
    'Number of Inputs (power of 2)': lengthOfListKnob,
    'Input Width': logicWidthKnob,
    'Sort in Ascending': isAscendingKnob,
  };

  @override
  final name = 'Bitonic Sort';

  @override
  Module createModule() {
    final listToSort = List.generate(
      lengthOfListKnob.value,
      (index) => Logic(width: logicWidthKnob.value),
    );

    return BitonicSort(
      Logic(),
      Logic(),
      isAscending: isAscendingKnob.value,
      toSort: listToSort,
    );
  }

  @override
  // TODO: implement exampleTestVectors
  List<Vector> get exampleTestVectors => throw UnimplementedError();
}
