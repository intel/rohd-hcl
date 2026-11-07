// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cross_probe.dart
// Cross-probing utilities that consume FLC JSON from SourceTracer
// and map symbols to locations in both the generated SV and ROHD Dart source.
//
// 2026 April 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

/// A location within a text document (1-based line and column).
class SourceLocation {
  /// The file path (relative to package root) this location refers to.
  final String? file;

  /// The one-based line number.
  final int line;

  /// The one-based column number.
  final int column;

  /// Length of the symbol name (useful for highlighting).
  final int length;

  /// Creates a source location.
  const SourceLocation({
    required this.line,
    required this.column,
    this.file,
    this.length = 0,
  });

  @override
  String toString() =>
      '${file != null ? "$file:" : ""}$line:$column (len=$length)';
}

/// Cross-probing data built from the FLC JSON produced by
/// `SourceTracer.traceJsonForHierarchy()`.
///
/// Provides lookups from signal/instance names to their source locations
/// in both the generated SystemVerilog and the original ROHD Dart source.
class CrossProbe {
  /// Signal/instance name → SV source location.
  final Map<String, SourceLocation> svLocations;

  /// Signal/instance name → ROHD Dart source location (from FLC `"src"`
  /// fields, filtered to the file matching the loaded asset).
  final Map<String, SourceLocation> rohdLocations;

  /// Symbols that appear in **both** SV and ROHD source.
  late final Set<String> commonSymbols;

  CrossProbe._({required this.svLocations, required this.rohdLocations}) {
    commonSymbols =
        svLocations.keys.toSet().intersection(rohdLocations.keys.toSet());
  }

  /// Build a [CrossProbe] from FLC JSON (as produced by
  /// `SourceTracer.traceJsonForHierarchy()`), the generated SV text,
  /// and the loaded ROHD Dart source text.
  ///
  /// [flcJson] is the decoded JSON map with `"version"`, `"files"`,
  /// and `"modules"` keys.
  ///
  /// [availableAssets] is the set of asset paths that are loadable in the
  /// confapp (e.g. `{"rohd_src/summation/counter.dart", ...}`).
  /// FLC file references are normalized and matched against this set.
  /// Each ROHD [SourceLocation] will have its [SourceLocation.file] set
  /// to the matching asset path so the UI can open the correct tab.
  ///
  factory CrossProbe.fromFlcJson({
    required Map<String, dynamic> flcJson,
    required Set<String> availableAssets,
  }) {
    final files = (flcJson['files'] as List<dynamic>).cast<String>();
    final modules =
        flcJson['modules'] as Map<String, dynamic>? ?? <String, dynamic>{};

    // Build a mapping from FLC file index → asset path for every
    // rohd-hcl source file that we have as a loadable asset.
    // FLC paths look like `.dart_tool/../lib/src/summation/counter.dart`
    // which normalizes to `rohd_src/summation/counter.dart`.
    final fileIndexToAsset = <int, String>{};
    for (var i = 0; i < files.length; i++) {
      final norm = files[i].replaceAll('.dart_tool/../', '');
      String? assetPath;
      if (norm.startsWith('lib/src/')) {
        assetPath = 'rohd_src/${norm.substring('lib/src/'.length)}';
      } else if (norm.startsWith('package:rohd_hcl/src/')) {
        // DDC web traces produce raw package: URIs.
        assetPath =
            'rohd_src/${norm.substring('package:rohd_hcl/src/'.length)}';
      }
      if (assetPath != null && availableAssets.contains(assetPath)) {
        fileIndexToAsset[i] = assetPath;
      }
    }

    final svLocs = <String, SourceLocation>{};
    final rohdLocs = <String, SourceLocation>{};

    // Walk all modules in the FLC JSON and extract locations.
    // SV locations come exclusively from FLC "sv" fields — no regex
    // fallback — so missing entries surface as debugging signals.
    for (final modEntry in modules.values) {
      final modMap = modEntry as Map<String, dynamic>;
      _extractLocations(
        modMap['signals'] as Map<String, dynamic>?,
        files,
        fileIndexToAsset,
        rohdLocs,
        svLocs,
      );
      _extractLocations(
        modMap['instances'] as Map<String, dynamic>?,
        files,
        fileIndexToAsset,
        rohdLocs,
        svLocs,
      );
    }

    return CrossProbe._(svLocations: svLocs, rohdLocations: rohdLocs);
  }

  /// Fallback builder that scans SV and ROHD text directly (no FLC JSON).
  factory CrossProbe.build({
    required String svText,
    required String rohdText,
  }) {
    final svLocs = _parseSvSymbols(svText);
    final rohdLocs = _scanIdentifiers(rohdText, svLocs.keys.toSet());
    return CrossProbe._(svLocations: svLocs, rohdLocations: rohdLocs);
  }

  /// Pick a random symbol that exists in both sources.
  String? randomCommonSymbol([Random? rng]) {
    if (commonSymbols.isEmpty) {
      return null;
    }
    final list = commonSymbols.toList();
    return list[(rng ?? Random()).nextInt(list.length)];
  }

  // ---------------------------------------------------------------------------
  // FLC JSON extraction
  // ---------------------------------------------------------------------------

  /// Extracts ROHD source locations from a `"signals"` or `"instances"` map
  /// in the FLC JSON.
  ///
  /// Each entry can be either:
  ///  - v2 enriched: `{ "sv": "42", "src": ["0:55:10", ...] }`
  ///  - v1 plain: `["0:55:10", ...]`
  ///
  /// [primaryAsset] (if given) is the primary source file for the current
  /// module — frames from this file are preferred over deeper frames.
  static void _extractLocations(
    Map<String, dynamic>? section,
    List<String> files,
    Map<int, String> fileIndexToAsset,
    Map<String, SourceLocation> rohdLocs,
    Map<String, SourceLocation> svLocs, {
    String? primaryAsset,
  }) {
    if (section == null) {
      return;
    }

    for (final entry in section.entries) {
      final name = entry.key;
      final value = entry.value;

      List<dynamic> srcFrames;
      String? svLine;

      if (value is Map) {
        srcFrames = (value['src'] as List<dynamic>?) ?? [];
        svLine = value['sv']?.toString();
      } else if (value is List) {
        srcFrames = value;
      } else {
        continue;
      }

      // If the FLC provides an SV line, use it (overrides regex-based).
      if (svLine != null) {
        final svParts = svLine.split(':');
        final svLineNum = int.tryParse(svParts[0]);
        final svCol = svParts.length > 1 ? (int.tryParse(svParts[1]) ?? 1) : 1;
        if (svLineNum != null) {
          svLocs[name] = SourceLocation(
            line: svLineNum,
            column: svCol,
            length: name.length,
          );
        }
      }

      // Find the best FLC frame: prefer the first frame in the primary
      // asset (the module's own source), falling back to the first frame
      // in any available asset.
      if (!rohdLocs.containsKey(name)) {
        SourceLocation? primaryLoc;
        SourceLocation? fallbackLoc;
        for (final frame in srcFrames) {
          final parts = frame.toString().split(':');
          if (parts.length < 2) {
            continue;
          }
          final fileIdx = int.tryParse(parts[0]);
          if (fileIdx == null) {
            continue;
          }
          final assetPath = fileIndexToAsset[fileIdx];
          if (assetPath == null) {
            continue;
          }
          final line = int.tryParse(parts[1]) ?? 1;
          final col = parts.length > 2 ? (int.tryParse(parts[2]) ?? 1) : 1;
          final loc = SourceLocation(
            file: assetPath,
            line: line,
            column: col,
            length: name.length,
          );
          if (primaryAsset != null && assetPath == primaryAsset) {
            // Take the first (deepest) frame in the primary file — that's
            // the actual instantiation/creation site.
            primaryLoc ??= loc;
          }
          fallbackLoc ??= loc;
        }
        if (primaryLoc != null) {
          rohdLocs[name] = primaryLoc;
        } else if (fallbackLoc != null) {
          rohdLocs[name] = fallbackLoc;
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // SV text parsing (fallback / supplement)
  // ---------------------------------------------------------------------------

  static final _svDeclRe = RegExp(
    r'(?:input|output|inout)?\s*logic\s*(?:\[[^\]]*\])?\s*(\w+)|'
    r'assign\s+(\w+)',
  );

  static Map<String, SourceLocation> _parseSvSymbols(String text) {
    final map = <String, SourceLocation>{};
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      for (final m in _svDeclRe.allMatches(lines[i])) {
        final name = m.group(1) ?? m.group(2);
        if (name == null || map.containsKey(name)) {
          continue;
        }
        final col = lines[i].indexOf(name);
        map[name] = SourceLocation(
          line: i + 1,
          column: col + 1,
          length: name.length,
        );
      }
    }
    return map;
  }

  // ---------------------------------------------------------------------------
  // ROHD source scanning (fallback when no FLC JSON)
  // ---------------------------------------------------------------------------

  static Map<String, SourceLocation> _scanIdentifiers(
      String text, Set<String> targets) {
    if (targets.isEmpty) {
      return {};
    }
    final map = <String, SourceLocation>{};
    final lines = text.split('\n');
    final pattern = RegExp(
      r'\b(' + targets.map(RegExp.escape).join('|') + r')\b',
    );
    for (var i = 0; i < lines.length; i++) {
      for (final m in pattern.allMatches(lines[i])) {
        final name = m.group(1)!;
        if (map.containsKey(name)) {
          continue;
        }
        map[name] = SourceLocation(
          line: i + 1,
          column: m.start + 1,
          length: name.length,
        );
      }
    }
    return map;
  }
}
