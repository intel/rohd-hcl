// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// group_of_knobs_knob.dart
// A knob for grouping other knobs.
//
// 2023 December 5
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';

/// A knob which groups together other [ConfigKnob]s.
class GroupOfKnobs extends ConfigKnob<String> {
  /// A mapping from a sub-knob name to a corresponding sub-[ConfigKnob].
  final Map<String, ConfigKnob<dynamic>> subKnobs;

  /// The name of this group.
  String get name => value;

  /// Creates a new group of [subKnobs] under one knob.
  GroupOfKnobs(this.subKnobs, {String name = 'Group'}) : super(value: name);

  @override
  Map<String, dynamic> toJson() => {
        for (final subKnob in subKnobs.entries)
          subKnob.key: subKnob.value.toJson(),
      };

  @override
  void loadJson(Map<String, dynamic> decodedJson) {
    for (final subKnobJsonMap in decodedJson.entries) {
      subKnobs[subKnobJsonMap.key]!
          .loadJson(subKnobJsonMap.value as Map<String, dynamic>);
    }
  }
}
