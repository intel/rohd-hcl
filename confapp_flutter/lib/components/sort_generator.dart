import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd/rohd.dart';
import 'package:confapp_flutter/components/config.dart';

class _BitonicSortComponent extends Module {
  late final BitonicSort bitonicSort;
  _BitonicSortComponent(int lengthOfList, int logicWidth, int isAscending) {
    final List<Logic> listToSort = List.generate(
      lengthOfList,
      (index) => Logic(name: 'toSort$index', width: logicWidth),
    );

    bitonicSort = BitonicSort(
      SimpleClockGenerator(10).clk,
      Logic(name: 'reset'),
      isAscending: isAscending == 1 ? true : false,
      toSort: listToSort,
    );
  }
}

class BitonicSortGenerator extends ConfigGenerator {
  final IntConfigKnob lengthOfListKnob =
      IntConfigKnob('Length of List (power of 2)', defaultVal: 4);
  final IntConfigKnob logicWidthKnob =
      IntConfigKnob('Logic Width', defaultVal: 16);
  final IntConfigKnob isAscendingKnob =
      IntConfigKnob('Sort in Ascending (1: true, 0: false)', defaultVal: 1);

  @override
  final componentName = 'Bitonic Sort';

  @override
  late final List<ConfigKnob> knobs = [
    lengthOfListKnob,
    logicWidthKnob,
    isAscendingKnob,
  ];

  @override
  Future<String> generate() async {
    var bitonicSort = _BitonicSortComponent(
            lengthOfListKnob.value, logicWidthKnob.value, isAscendingKnob.value)
        .bitonicSort;

    await bitonicSort.build();
    return bitonicSort.generateSynth();
  }
}
