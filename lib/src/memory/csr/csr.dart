// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr.dart
// A flexible definition of Control and Status Regisers (CSR)s.
//
// 2024 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:collection/collection.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// [Logic] representation of a Control and Status Register (CSR).
///
/// Semantically, a register can be created with no fields.
/// In this case, a single implicit field is created that is
/// read/write and the entire width of the register.
class Csr extends LogicStructure {
  /// Configuration for the CSR.
  final CsrInstanceConfig config;

  /// A list of indices of all of the reserved fields in the CSR.
  /// This is necessary because the configuration does not explicitly
  /// define reserved fields, but they must be accounted for
  /// in certain logic involving the CSR.
  final List<int> rsvdIndices;

  /// Getter for the address of the CSR.
  int get addr => config.addr;

  /// Getter for the reset value of the CSR.
  int get resetValue => config.resetValue;

  /// Getter for the access control of the CSR.
  CsrAccess get access => config.access;

  /// Accessor to the architectural frontdoor readability of the register.
  bool get isFrontdoorReadable => config.isFrontdoorReadable;

  /// Accessor to the architectural frontdoor writability of the register.
  bool get isFrontdoorWritable => config.isFrontdoorWritable;

  /// Accessor to the architectural backdoor readability of the register.
  bool get isBackdoorReadable => config.isBackdoorReadable;

  /// Accessor to the architectural backdoor writability of the register.
  bool get isBackdoorWritable => config.isBackdoorWritable;

  /// Getter for the field configuration of the CSR
  List<CsrFieldConfig> get fields => config.fields;

  /// Factory constructor for [Csr].
  ///
  /// Because [LogicStructure] requires a [List<Logic>] upon construction,
  /// the factory method assists in creating the [List] upfront before
  /// the [LogicStructure] constructor is called.
  factory Csr(
    CsrInstanceConfig config,
  ) {
    final fields = <Logic>[];
    final rsvds = <int>[];
    var currIdx = 0;
    var rsvdCount = 0;

    // semantically a register with no fields means that
    // there is one read/write field that is the entire register
    if (config.fields.isEmpty) {
      fields.add(Logic(name: 'data', width: config.width));
    }
    // there is at least one field explicitly defined so
    // process them individually
    else {
      for (final field in config.fields) {
        if (field.start > currIdx) {
          fields.add(
              Logic(name: 'rsvd_$rsvdCount', width: field.start - currIdx));
          rsvds.add(fields.length - 1);
          rsvdCount++;
        }
        fields.add(Logic(name: field.name, width: field.width));
        currIdx = field.start + field.width;
      }
      if (currIdx < config.width) {
        fields
            .add(Logic(name: 'rsvd_$rsvdCount', width: config.width - currIdx));
        rsvds.add(fields.length - 1);
      }
    }
    return Csr._(
      config: config,
      rsvdIndices: rsvds,
      fields: fields,
    );
  }

  /// Explicit constructor.
  ///
  /// This constructor is private and should not be used directly.
  /// Instead, the factory constructor [Csr] should be used.
  /// This facilitates proper calling of the super constructor.
  Csr._({
    required this.config,
    required this.rsvdIndices,
    required List<Logic> fields,
    String? logicName,
  }) : super(fields, name: logicName ?? config.name);

  // Historically the CSR disallowed renaming because the architectural
  // name is tied to its configuration. However, interface cloning and
  // IO uniquification can pass a `name` to clone; to support that
  // workflow we ignore the requested `name` here and preserve the
  // CSR's configured name while still cloning the underlying elements.
  /// Creates a clone of this CSR.
  ///
  /// The CSR is not allowed to be renamed, so [name] must be null.
  @override
  Csr clone({String? name}) => Csr._(
        config: config,
        rsvdIndices: rsvdIndices,
        fields: elements.map((e) => e.clone()).toList(),
        logicName: name,
      );

  /// Accessor to the bits of a particular field
  /// within the CSR by name [name].
  Logic getField(String name) =>
      elements.firstWhereOrNull((element) => element.name == name) ??
      (throw RohdHclException(
          'Field with name $name not found in CSR ${config.name}.'));

  /// Accessor to the config of a particular field
  /// within the CSR by name [name].
  CsrFieldConfig getFieldConfigByName(String name) =>
      config.getFieldByName(name);

  /// Given some arbitrary data [wd] to write to this CSR,
  /// return the data that should actually be written based
  /// on the access control of the CSR and its fields.
  Logic getWriteData(Logic wd) {
    // if the whole register is ready only, return the current value
    if (access == CsrAccess.readOnly) {
      return this;
    }
    // register can be written, but still need to look at the fields...
    else {
      // special case of no explicit fields defined
      // in this case, we have an implicit read/write field
      // so there is nothing special to do
      if (fields.isEmpty) {
        return wd;
      }

      // otherwise, we need to look at the fields
      var finalWd = wd;
      var currIdx = 0;
      var currField = 0;
      for (var i = 0; i < elements.length; i++) {
        // if the given field is reserved or read only
        // take the current value instead of the new value
        final chk1 = rsvdIndices.contains(i);
        if (chk1) {
          finalWd = finalWd.withSet(currIdx, elements[i]);
          currIdx += elements[i].width;
          continue;
        }

        // if the given field is read only
        // take the current value instead of the new value
        final chk2 = fields[currField].access == CsrFieldAccess.readOnly ||
            fields[currField].access == CsrFieldAccess.writeOnesClear;
        if (chk2) {
          finalWd = finalWd.withSet(currIdx, elements[i]);
          currField++;
          currIdx += elements[i].width;
          continue;
        }

        if (fields[currField].access == CsrFieldAccess.readWriteLegal) {
          // if the given field is write legal
          // make sure the value is in fact legal
          // and transform it if not
          final origVal =
              wd.getRange(currIdx, currIdx + fields[currField].width);
          final legalCases = <Logic, Logic>{};
          for (var i = 0; i < fields[currField].legalValues.length; i++) {
            legalCases[Const(fields[currField].legalValues[i],
                width: fields[currField].width)] = origVal;
          }
          final newVal = cases(
              origVal,
              conditionalType: ConditionalType.unique,
              legalCases,
              defaultValue: Const(fields[currField].transformIllegalValue(),
                  width: fields[currField].width));

          finalWd = finalWd.withSet(currIdx, newVal);
          currField++;
          currIdx += elements[i].width;
        } else {
          // normal read/write field
          currField++;
          currIdx += elements[i].width;
        }
      }
      return finalWd;
    }
  }
}
