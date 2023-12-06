// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// example_component.dart
// An example component that uses multiple different types of knobs
//
// 2023 December

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

enum ExampleEnum { yes, no, maybe }

class ExampleModule extends Module {
  ExampleModule() {
    addInput('inp', Logic());
  }
}

class ExampleConfigurator extends Configurator {
  @override
  Module createModule() => ExampleModule();

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = {
    'a': StringConfigKnob(value: 'apple'),
    'b': IntConfigKnob(value: 5),
    'c': ToggleConfigKnob(value: true),
    'd': ChoiceConfigKnob<ExampleEnum>(ExampleEnum.values,
        value: ExampleEnum.maybe),
    'e': ListOfKnobsKnob(
        count: 3, generateKnob: (i) => IntConfigKnob(value: i), name: 'MyList'),
    'f': GroupOfKnobs({
      '1': StringConfigKnob(value: '1'),
      '2': StringConfigKnob(value: '2'),
    }, name: 'MyGroup'),
  };

  @override
  String get name => 'exampleName';
}
