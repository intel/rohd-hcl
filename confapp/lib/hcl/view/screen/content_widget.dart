// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// content_widget.dart
// Implementation of the widget for viewing the main content
//
// 2023 December

import 'dart:async' show unawaited;

import 'package:confapp/hcl/cubit/component_cubit.dart';
import 'package:confapp/hcl/cubit/system_verilog_cubit.dart';
import 'package:confapp/hcl/cubit/theme_cubit.dart';
import 'package:confapp/hcl/module_source_assets.dart';
import 'package:confapp/hcl/view/screen/browser_interop.dart';
import 'package:confapp/hcl/view/screen/dart_syntax_code_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight/languages/cpp.dart' as highlight_cpp;
import 'package:highlight/languages/verilog.dart' as highlight_verilog;
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:material_ui/material_ui.dart';
import 'package:rohd/rohd.dart' show Module, NetlistSynthesizer, SynthBuilder;
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_schematic_viewer/schematic_viewer.dart';

/// Maps Module runtimeType names to their asset source file paths.
const _rohdIconAsset = 'assets/rohd_icon.png';
const _systemVerilogIconAsset = 'assets/systemverilog_icon.png';
const _yosysIconAsset = 'assets/yosys_icon.png';

typedef _RohdSourceDocument = ({
  String source,
  DartSyntaxHighlighter syntaxHighlighter,
});

class _ConfappRohdExtensionClient implements RohdExtensionClient {
  _ConfappRohdExtensionClient({
    required this.getModuleFormats,
    required this.lookupFrames,
  });

  final Future<Set<String>> Function(
    String module, {
    List<String>? instancePath,
  }) getModuleFormats;
  final Future<List<Map<String, dynamic>>> Function({
    required List<Map<String, String>> signals,
    String? format,
  }) lookupFrames;

  @override
  final isAvailable = ValueNotifier<bool>(true);

  @override
  final currentModuleInfo = ValueNotifier<RohdModuleInfo?>(null);

  @override
  Future<bool> ping() async {
    isAvailable.value = true;
    return true;
  }

  @override
  Future<RohdModuleInfo> queryModule(
    String module, {
    List<String>? instancePath,
  }) async {
    final formatKeys = await getModuleFormats(
      module,
      instancePath: instancePath,
    );
    final formats = <RohdSourceFormat, RohdFormatInfo>{};
    for (final key in formatKeys) {
      final format = _parseFormat(key);
      if (format != null) {
        formats[format] = const RohdFormatInfo(
          available: true,
          fileFound: true,
        );
      }
    }
    final info = RohdModuleInfo(
      extensionAvailable: true,
      module: module,
      formats: formats,
    );
    currentModuleInfo.value = info;
    return info;
  }

  void refreshModule(String module) {
    unawaited(queryModule(module));
  }

  @override
  Future<List<Map<String, dynamic>>> lookupSignalFrames({
    required List<Map<String, String>> signals,
    String? format,
  }) =>
      lookupFrames(signals: signals, format: format);

  @override
  void openSourceLocation({
    required String file,
    required int line,
    int col = 0,
  }) {}

  @override
  void dispose() {
    isAvailable.dispose();
    currentModuleInfo.dispose();
  }

  static RohdSourceFormat? _parseFormat(String key) => switch (key) {
        'rohd' => RohdSourceFormat.rohd,
        'sv' => RohdSourceFormat.sv,
        'sc' => RohdSourceFormat.sc,
        'fst' => RohdSourceFormat.fst,
        _ => null,
      };
}

/// Displays component configuration controls and generated outputs.
class SVGenerator extends StatefulWidget {
  /// Creates the generated-output view.
  const SVGenerator({super.key});

  @override
  State createState() => _SVGeneratorState();
}

class _SVGeneratorState extends State<SVGenerator>
    with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ButtonStyle btnStyle = ElevatedButton.styleFrom(
    textStyle: const TextStyle(fontSize: 20),
  );

  late TabController _tabController;
  late final _ConfappRohdExtensionClient _sourceFormatClient;

  /// Labels for each logical tab index.
  static const _tabLabels = [
    'ROHD Schematic',
    'ROHD Source',
    'Generated SV',
    'Synth Schematic',
  ];

  /// Returns the icon widget for tab checkbox at [index].
  Widget _tabIconWidget(int index) {
    switch (index) {
      case 0:
        return const SchematicIcon(size: 26);
      case 1:
        return _tabAssetIcon(
          _rohdIconAsset,
          semanticLabel: _tabTooltips[index],
        );
      case 2:
        return _tabAssetIcon(
          _systemVerilogIconAsset,
          semanticLabel: _tabTooltips[index],
        );
      case 3:
        return _tabAssetIcon(
          _yosysIconAsset,
          width: 28,
          height: 28,
          semanticLabel: _tabTooltips[index],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _tabAssetIcon(
    String asset, {
    required String semanticLabel,
    double width = 26,
    double height = 26,
  }) =>
      Image.asset(
        asset,
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: semanticLabel,
      );

  Widget _tabLabelWidget(int index) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tabIconWidget(index),
          const SizedBox(width: 8),
          Text(_tabLabels[index]),
        ],
      );

  /// Tooltips for the tab-enable checkboxes.
  static const _tabTooltips = [
    'ROHD Schematic',
    'ROHD Source',
    'Generated SV',
    'Synth Schematic (Yosys)',
  ];

  /// Logical indices of currently visible tabs.
  List<int> get _visibleTabs => [
        for (var i = 0; i < _tabLabels.length; i++)
          if (_tabEnabled[i]) i
      ];

  /// Returns the current visible-tab index for a logical tab index.
  int? _visibleTabIndexForLogical(int logicalIndex) {
    final idx = _visibleTabs.indexOf(logicalIndex);
    return idx >= 0 ? idx : null;
  }

  /// Show a logical tab, optionally enabling it first when currently hidden.
  void _showLogicalTab(int logicalIndex, {bool enableIfHidden = false}) {
    if (!_tabEnabled[logicalIndex]) {
      if (!enableIfHidden) {
        return;
      }
      setState(() {
        _tabEnabled[logicalIndex] = true;
        _rebuildTabController(selectLogical: logicalIndex);
      });
      return;
    }

    final visibleIdx = _visibleTabIndexForLogical(logicalIndex);
    if (visibleIdx != null && _tabController.index != visibleIdx) {
      _tabController.animateTo(visibleIdx);
    }
  }

  /// Rebuild the TabController to match the current set of visible tabs.
  void _rebuildTabController({int? selectLogical}) {
    final visible = _visibleTabs;
    if (visible.isEmpty) {
      return;
    }
    final oldIndex = _tabController.index;
    final oldLogical =
        oldIndex < visible.length ? visible[oldIndex] : visible.first;
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();

    final newVisible = _visibleTabs;
    final initialIndex = () {
      if (selectLogical != null) {
        final idx = newVisible.indexOf(selectLogical);
        if (idx >= 0) {
          return idx;
        }
      }
      // Try to stay on the same logical tab.
      final idx = newVisible.indexOf(oldLogical);
      return idx >= 0 ? idx : 0;
    }();

    _tabController = TabController(
      length: newVisible.length,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final visible = _visibleTabs;
        if (_tabController.index < visible.length) {
          _applyPendingScroll(visible[_tabController.index]);
        }
      });
    }
  }

  void _scheduleSourceFormatRefresh() {
    final moduleName = _lastModuleName;
    if (moduleName == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _sourceFormatClient.refreshModule(moduleName);
    });
  }

  @override
  void initState() {
    super.initState();
    _sourceFormatClient = _ConfappRohdExtensionClient(
      getModuleFormats: _getModuleFormats,
      lookupFrames: _lookupSignalFrames,
    );
    final visible = _visibleTabs;
    _tabController = TabController(length: visible.length, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Listen for cross-probe events from viewers and highlight editors.
    _crossProbeBus.addListener(_onCrossProbeSignals);

    // Clear generated outputs when the selected component changes.
    final componentCubit = context.read<ComponentCubit>();
    final rtlCubit = context.read<SystemVerilogCubit>();
    componentCubit.stream.listen((component) {
      rtlCubit.initializeData();
      _disposeRohdSubtabs();
      setState(() {
        _rohdNetlistJson = null;
        _yosysJson = null;
        _synthSchematicLoading = false;
        _synthSchematicRequestId++;
        _flcData = null;
        _flcModuleName = null;
        _hierarchyService = null;
        _lastRohdSource = null;
        _highlightedSvLine = null;
        _highlightedRohdLine = null;
        _rohdSourceFiles = [];
        // Clear cached generation state.
        _lastBuiltModule = null;
        _lastRtlRes = null;
        _lastScRes = null;
        _lastModuleName = null;
        _lastFlcJson = null;
        _highlightedScLine = null;
      });
      // Set up the primary ROHD source subtab (no FLC until Generate).
      _initPrimaryRohdSubtab(component);
    });

    // Also set up for the initial component.
    _initPrimaryRohdSubtab(componentCubit.state);
  }

  /// Set up a single ROHD source subtab for the primary source file of
  /// [component].  Additional subtabs are added at generation time when
  /// the FLC JSON is loaded by [_buildCrossProbeAndHighlight].
  void _initPrimaryRohdSubtab(Configurator component) {
    final mod = component.createModule();
    final rawType = mod.runtimeType.toString();
    final typeName = rawType.contains('<')
        ? rawType.substring(0, rawType.indexOf('<'))
        : rawType;
    final primaryAsset = moduleSourceAssets[typeName];
    if (primaryAsset == null) {
      return;
    }

    _disposeRohdSubtabs();

    final subtabCtrl = TabController(length: 1, vsync: this);
    subtabCtrl.addListener(() {
      if (!subtabCtrl.indexIsChanging) {
        setState(() {});
        _applyPendingRohdSubtabScroll(subtabCtrl.index);
      }
    });

    setState(() {
      _rohdSourceFiles = [primaryAsset];
      _rohdSourceTabController = subtabCtrl;
    });
  }

  final yosysWorker = YosysWorker('yosysWorker.js');
  String? _rohdNetlistJson;
  String? _yosysJson;
  bool _synthSchematicLoading = false;
  int _synthSchematicRequestId = 0;
  String _moduleName = '';

  /// Hierarchy service built from the ROHD netlist JSON, used to resolve
  /// signal names into full occurrence paths for cross-probe.
  HierarchyService? _hierarchyService;

  /// Cross-probe data built after each generation (shared FlcData model).
  FlcData? _flcData;

  /// The module name used for FlcData lookups (definition name from build).
  String? _flcModuleName;

  /// Cached ROHD source text reserved for the planned source-navigation UI.
  // The planned source-navigation UI will read this cached source.
  // ignore: unused_field
  String? _lastRohdSource;

  /// Current expansion mode for the ROHD schematic viewer.
  SchematicExpansionMode _expansionMode = SchematicExpansionMode.defaultView;

  /// Fraction of the total width allocated to the config (left) pane.
  /// Defaults to 0.25 (i.e. the old flex 1:3 ratio).
  double _splitFraction = 0.25;

  /// Persistent controllers for the code editors so they can be targeted
  /// programmatically (e.g. scroll-to-line from a schematic node click).
  HighlightCodeController? _svController;
  HighlightCodeController? _scController;
  SyntaxCodeController? _rohdSourceController;
  late final Future<DartSyntaxHighlighter> _dartSyntaxHighlighter =
      DartSyntaxHighlighter.load();

  /// Focus nodes for the code editors — needed so that selection highlights
  /// are visible (Flutter only renders selection when the field has focus).
  final FocusNode _svFocusNode = FocusNode();
  final FocusNode _scFocusNode = FocusNode();
  final FocusNode _rohdSourceFocusNode = FocusNode();

  /// Scroll controllers for the outer SingleChildScrollView wrappers so we
  /// can programmatically center a target line in the viewport.
  final ScrollController _svScrollController = ScrollController();
  final ScrollController _scScrollController = ScrollController();
  final ScrollController _rohdSourceScrollController = ScrollController();
  final ScrollController _configScrollController = ScrollController();
  final ScrollController _svHorizontalScrollController = ScrollController();
  final ScrollController _scHorizontalScrollController = ScrollController();

  // ── ROHD Source subtab state ──────────────────────────────────────────

  /// Ordered list of asset paths for all ROHD source files referenced by
  /// the current FLC. Each entry corresponds to one subtab.  The "primary"
  /// source (from [moduleSourceAssets]) is always first.
  List<String> _rohdSourceFiles = [];

  /// Tab controller for the ROHD source subtabs (one per file).
  TabController? _rohdSourceTabController;

  /// Per-file controllers, scroll controllers, focus nodes, and highlights.
  final Map<String, SyntaxCodeController> _rohdFileControllers = {};
  final Map<String, ScrollController> _rohdFileScrollControllers = {};
  final Map<String, ScrollController> _rohdFileHorizontalScrollControllers = {};
  final Map<String, FocusNode> _rohdFileFocusNodes = {};
  final Map<String, int?> _rohdFileHighlightLines = {};

  /// Cached asset-loading futures so FutureBuilder doesn't restart on rebuild.
  final Map<String, Future<String>> _rohdFileFutures = {};
  final Map<String, Future<_RohdSourceDocument>> _rohdSourceViewFutures = {};

  /// GlobalKey for the TabBarView to preserve element identity across rebuilds.
  GlobalKey? _subtabViewKey;

  /// Pending scroll offsets when the target subtab isn't visible yet.
  final Map<String, double?> _rohdFilePendingScrolls = {};

  // ── End ROHD Source subtab state ──────────────────────────────────────

  // ── Tab visibility checkboxes ─────────────────────────────────────────

  /// Which output tabs are enabled.  Controls both visibility in the TabBar
  /// and whether the corresponding generation step runs.
  ///
  /// Index mapping:
  ///  0 = ROHD Schematic (netlist)
  ///  1 = ROHD Source (FLC/cross-probe)
  ///  2 = Generated SV (always on — base for others)
  ///  3 = Synth Schematic (Yosys)
  final List<bool> _tabEnabled = [true, true, true, false];

  /// Cached module and generated outputs from the last generate, so that lazy
  /// generation of newly-enabled tabs can reuse the built module.
  Module? _lastBuiltModule;
  String? _lastRtlRes;
  String? _lastScRes;
  String? _lastModuleName;
  Map<String, Object>? _lastFlcJson;

  // ── End tab visibility checkboxes ─────────────────────────────────────

  /// Pending scroll offsets for editors that aren't currently visible.
  /// Applied when the tab becomes visible.
  double? _pendingSvScroll;
  int? _pendingSvLine;
  int? _pendingSvColumn;
  double? _pendingScScroll;
  int? _pendingScLine;
  int? _pendingScColumn;
  double? _pendingRohdScroll;

  /// Persistently highlighted line (1-based) for each editor, or null.
  int? _highlightedSvLine;
  int? _highlightedScLine;
  // The planned consolidated ROHD editor will read this highlight.
  // ignore: unused_field
  int? _highlightedRohdLine;

  /// Last known pointer position (global) — used to anchor popup menus.
  Offset _lastPointerPosition = Offset.zero;

  /// When true, `_onCrossProbeSignals` skips source navigation.
  /// Set temporarily when "Show Signal in Schematic" triggers the bus.
  bool _suppressCrossProbeNav = false;

  /// Cross-probe bus: signal paths shared between all panes.
  /// Schematic/wave viewers write to this via `onSendSignals`; editors
  /// and viewers listen via `addListener` / `incomingSignalPaths`.
  final ValueNotifier<List<String>?> _crossProbeBus =
      ValueNotifier<List<String>?>(null);

  /// The shared text style used in all CodeField widgets.
  ///
  /// `height` is set explicitly so it overrides the theme's titleMedium
  /// height multiplier that CodeField merges in.  This keeps our overlay
  /// line-height calculation in sync with the actual rendered text.
  static const _codeTextStyle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    height: 1.5,
  );

  /// Line height (px) computed from the actual font metrics.
  late final double _lineHeight = () {
    final tp = TextPainter(
      text: const TextSpan(text: 'X', style: _codeTextStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.preferredLineHeight;
  }();

  /// Vertical offset (px) from the top of the CodeField to the first line
  /// of rendered text.  Empirically determined — the package's gutter uses
  /// `Padding(vertical: 16)` but the TextField with `isCollapsed: true` and
  /// the same `contentPadding` renders text at a slightly different offset.
  /// We use a custom gutter (below) so that line-numbers, code, and
  /// highlight all share this same value.
  static const _codeTopPad = 13.0;
  static const _minimumCodeColumns = 80;
  static const _codeHorizontalEndPad = 96.0;

  /// Cache of measured scroll widths keyed by editor text so that rebuilds
  /// triggered by highlight changes don't re-measure every line.
  final Map<String, double> _scrollExtentWidthCache = {};

  double _measureCodeViewportWidth() =>
      _measureCodeLineWidth(''.padRight(_minimumCodeColumns, 'M'));

  /// Measure the horizontal scroll extent for [text] using the shared code
  /// text style. This is intentionally separate from the viewport width: the
  /// viewport stays near 80 columns, while this width lets very long generated
  /// lines be reached by horizontal scrolling without visual wrapping.
  double _measureCodeScrollExtentWidth(String text) {
    final cached = _scrollExtentWidthCache[text];
    if (cached != null) {
      return cached;
    }
    var maxWidth = 0.0;
    for (final line in text.split('\n')) {
      final lineWidth = _measureCodeLineWidth(line);
      if (lineWidth > maxWidth) {
        maxWidth = lineWidth;
      }
    }
    final viewportWidth = _measureCodeViewportWidth();
    final contentWidth = maxWidth < viewportWidth ? viewportWidth : maxWidth;
    final width = contentWidth + _codeHorizontalEndPad;
    if (_scrollExtentWidthCache.length > 16) {
      _scrollExtentWidthCache.clear();
    }
    _scrollExtentWidthCache[text] = width;
    return width;
  }

  double _codeViewportWidthFor(BoxConstraints constraints) {
    final targetWidth = _measureCodeViewportWidth();
    final availableWidth = constraints.maxWidth;
    if (!availableWidth.isFinite || availableWidth >= targetWidth) {
      return targetWidth;
    }
    return availableWidth;
  }

  double _measureCodeLineWidth(String line) {
    final tp = TextPainter(
      text: TextSpan(text: line, style: _codeTextStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp.width;
  }

  /// Navigate a [SyntaxCodeController] to [line] (1-based) and optionally
  /// highlight from [column] (1-based) to end-of-line.
  ///
  /// Sets the selection immediately (works even when off-screen).
  /// Returns the ideal scroll offset for centering the line, or null
  /// if the scroll controller isn't attached.
  double? _setSelectionAndComputeScroll(
    SyntaxCodeController controller, {
    required int line,
    int? column,
    ScrollController? scrollController,
  }) {
    final idx = line - 1; // 0-based
    final lineRange = controller.lineRangeAt(idx);
    if (lineRange == null) {
      return null;
    }

    final startOffset = lineRange.start + ((column ?? 1) - 1);
    final endOffset = lineRange.end;

    // Clamp to actual text length to avoid invalid selection errors
    // (can happen when the controller text is shorter than expected,
    // e.g. during tab switches or when folded ranges shift offsets).
    final textLen = controller.text.length;
    final clampedStart = startOffset.clamp(lineRange.start, endOffset);
    final clampedEnd = endOffset.clamp(0, textLen);

    controller.selection = TextSelection(
      baseOffset: clampedStart,
      extentOffset: clampedEnd,
    );

    // Compute ideal scroll offset.
    if (scrollController != null && scrollController.hasClients) {
      final targetPixel = idx * _lineHeight;
      final viewportHeight = scrollController.position.viewportDimension;
      return (targetPixel - viewportHeight / 2).clamp(
        0.0,
        scrollController.position.maxScrollExtent,
      );
    }

    // Return a raw estimate when the scroll controller isn't attached yet.
    final targetPixel = idx * _lineHeight;
    return targetPixel > 200 ? targetPixel - 200 : 0;
  }

  /// Apply a pending scroll offset for the tab at [tabIndex].
  void _applyPendingScroll(int tabIndex) {
    if (tabIndex == 1 && _pendingRohdScroll != null) {
      final offset = _pendingRohdScroll!;
      _pendingRohdScroll = null;
      if (_rohdSourceScrollController.hasClients) {
        final clamped = offset.clamp(
          0.0,
          _rohdSourceScrollController.position.maxScrollExtent,
        );
        _rohdSourceScrollController.animateTo(
          clamped,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
    // When the ROHD Source main tab becomes visible, also apply any
    // pending scroll for the currently-selected subtab.
    if (tabIndex == 1 && _rohdSourceTabController != null) {
      _applyPendingRohdSubtabScroll(_rohdSourceTabController!.index);
    }
    if (tabIndex == 2 && _pendingSvScroll != null) {
      final offset = _pendingSvScroll!;
      final line = _pendingSvLine;
      final col = _pendingSvColumn;
      _pendingSvScroll = null;
      _pendingSvLine = null;
      _pendingSvColumn = null;
      if (_svScrollController.hasClients) {
        final clamped = offset.clamp(
          0.0,
          _svScrollController.position.maxScrollExtent,
        );
        _svScrollController.animateTo(
          clamped,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      // Re-apply selection since the controller may have rebuilt.
      if (line != null && _svController != null) {
        _setSelectionAndComputeScroll(
          _svController!,
          line: line,
          column: col,
        );
      }
    }
    if (tabIndex == 3 && _pendingScScroll != null) {
      final offset = _pendingScScroll!;
      final line = _pendingScLine;
      final col = _pendingScColumn;
      _pendingScScroll = null;
      _pendingScLine = null;
      _pendingScColumn = null;
      if (_scScrollController.hasClients) {
        final clamped = offset.clamp(
          0.0,
          _scScrollController.position.maxScrollExtent,
        );
        _scScrollController.animateTo(
          clamped,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      if (line != null && _scController != null) {
        _setSelectionAndComputeScroll(
          _scController!,
          line: line,
          column: col,
        );
      }
    }
  }

  /// Set highlight on the Generated SV editor at [line]:[column].
  /// If the SV tab is visible, scrolls immediately; otherwise defers.
  void navigateToSV({required int line, int? column}) {
    if (_svController == null) {
      return;
    }
    final effectiveLine = line;
    setState(() {
      _highlightedSvLine = effectiveLine;
    });
    final offset = _setSelectionAndComputeScroll(
      _svController!,
      line: effectiveLine,
      column: column,
      scrollController: _svScrollController,
    );
    final svTabIndex = _visibleTabIndexForLogical(2);
    if (svTabIndex != null && _tabController.index != svTabIndex) {
      // Switch to the SV tab so the user can see it.
      _pendingSvScroll = offset;
      _pendingSvLine = effectiveLine;
      _pendingSvColumn = column;
      _tabController.animateTo(svTabIndex);
    } else if (_svScrollController.hasClients) {
      // Tab is already visible — scroll now.
      if (offset != null) {
        _svScrollController.animateTo(
          offset.clamp(0.0, _svScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      _svFocusNode.requestFocus();
    } else {
      _pendingSvScroll = offset;
      _pendingSvLine = effectiveLine;
      _pendingSvColumn = column;
    }
  }

  /// Set highlight on the generated SystemC editor at [line]:[column].
  /// If the SystemC tab is visible, scrolls immediately; otherwise defers.
  void navigateToSC({required int line, int? column}) {
    if (_scController == null) {
      return;
    }
    final effectiveLine = line;
    setState(() {
      _highlightedScLine = effectiveLine;
    });
    final offset = _setSelectionAndComputeScroll(
      _scController!,
      line: effectiveLine,
      column: column,
      scrollController: _scScrollController,
    );
    final scTabIndex = _visibleTabIndexForLogical(3);
    if (scTabIndex != null && _tabController.index != scTabIndex) {
      _pendingScScroll = offset;
      _pendingScLine = effectiveLine;
      _pendingScColumn = column;
      _tabController.animateTo(scTabIndex);
    } else if (_scScrollController.hasClients) {
      if (offset != null) {
        _scScrollController.animateTo(
          offset.clamp(0.0, _scScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      _scFocusNode.requestFocus();
    } else {
      _pendingScScroll = offset;
      _pendingScLine = effectiveLine;
      _pendingScColumn = column;
    }
  }

  /// Set highlight on the ROHD Source editor at [line]:[column].
  /// If [file] is given, switches to the correct subtab first.
  /// If the Source tab is visible, scrolls immediately; otherwise defers.
  void navigateToSource({required int line, int? column, String? file}) {
    // Determine which subtab file to target.
    final targetFile =
        file ?? (_rohdSourceFiles.isNotEmpty ? _rohdSourceFiles.first : null);

    // Switch to the ROHD Source main tab, enabling it if hidden.
    _showLogicalTab(1, enableIfHidden: true);

    // Switch to the correct subtab if we have subtabs.
    if (targetFile != null && _rohdSourceFiles.contains(targetFile)) {
      final tabIdx = _rohdSourceFiles.indexOf(targetFile);
      if (_rohdSourceTabController != null &&
          _rohdSourceTabController!.index != tabIdx) {
        _rohdSourceTabController!.animateTo(tabIdx);
      }
    }

    // Get or create the per-file controller.
    final ctrl = targetFile != null
        ? _rohdFileControllers[targetFile]
        : _rohdSourceController;
    if (ctrl == null) {
      // Controller not yet created (tab not built yet). Store pending state.
      if (targetFile != null) {
        _rohdFileHighlightLines[targetFile] = line;
        _rohdFilePendingScrolls[targetFile] = 0;
      }
      return;
    }

    // Set highlight line for the target file.
    setState(() {
      if (targetFile != null) {
        // Clear highlights on all other files.
        for (final f in _rohdSourceFiles) {
          if (f != targetFile) {
            _rohdFileHighlightLines[f] = null;
          }
        }
        _rohdFileHighlightLines[targetFile] = line;
      }
      _highlightedRohdLine = line;
    });

    final scrollCtrl = targetFile != null
        ? _rohdFileScrollControllers[targetFile]
        : _rohdSourceScrollController;

    final offset = _setSelectionAndComputeScroll(
      ctrl,
      line: line,
      column: column,
      scrollController: scrollCtrl,
    );

    // Store pending scroll. The scroll is applied either:
    // - Immediately below (if scroll controller already has clients), or
    // - From the _rohdSourceFileView builder when the widget is mounted.
    if (targetFile != null) {
      _rohdFilePendingScrolls[targetFile] = offset;
    } else {
      _pendingRohdScroll = offset;
    }

    // If scroll controller is already attached, scroll now.
    if (scrollCtrl != null && scrollCtrl.hasClients && offset != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollCtrl.hasClients) {
          scrollCtrl.animateTo(
            offset.clamp(0.0, scrollCtrl.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          if (targetFile != null) {
            _rohdFilePendingScrolls[targetFile] = null;
          } else {
            _pendingRohdScroll = null;
          }
        }
      });
    }
  }

  /// Shallow list equality check.
  static bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  /// Look up [pathOrName] in the FlcData as either a signal or instance.
  ///
  /// [pathOrName] may be a bare signal name (`"highBitsLSB"`) or a full
  /// occurrence path rooted at an **instance** name
  /// (`"FloatingPointAdderSinglePath/highBitsLSB"`).
  ///
  /// FLC data is keyed by module **definition** names (e.g.
  /// `FloatingPointAdderSinglePath_E4M4`), whereas the schematic canvas roots
  /// signal paths at module **instance** names (e.g.
  /// `FloatingPointAdderSinglePath`).  Following the rohd_devtools_extension
  /// convention, the owning module path is translated to its definition name
  /// before lookup:
  ///   1. Sub-modules: the leading path segment (the top block's instance
  ///      name) is normalized to the hierarchy root name (its definition
  ///      name) so `occurrenceByPathname` can resolve the owning module; the
  ///      resolved [HierarchyOccurrence.definition] is the FLC key.
  ///   2. Top module: the netlist roots at the instance name, so we fall back
  ///      to [_flcModuleName] (the definition name captured at build time).
  ///   3. As a final safety net, search all modules by signal name.
  ///
  /// Returns the FlcEntry if found, null otherwise.
  FlcEntry? _lookupFlcEntry(String pathOrName) {
    final flcData = _flcData;
    if (flcData == null) {
      return null;
    }

    final segments = pathOrName.split('/');
    final signalName = segments.last;

    // 1. Module-qualified lookup: translate the instance path of the owning
    //    module to its definition name (the FLC key) via the hierarchy.
    if (segments.length >= 2) {
      var moduleSegments = segments.sublist(0, segments.length - 1);
      // The schematic roots its paths at the top block's *instance* name
      // (e.g. `FloatingPointAdderSinglePath`), but the hierarchy/FLC key by
      // its *definition* name (e.g. `FloatingPointAdderSinglePath_E4M4`).
      // Normalize the leading segment so `occurrenceByPathname` can resolve
      // sub-module paths.  (For modules whose instance name already matches
      // the definition name, this is a no-op.)
      final rootName = _hierarchyService?.root.name;
      if (rootName != null &&
          moduleSegments.isNotEmpty &&
          moduleSegments.first != rootName) {
        moduleSegments = [rootName, ...moduleSegments.skip(1)];
      }
      final modulePath = moduleSegments.join('/');
      final defName =
          _hierarchyService?.occurrenceByPathname(modulePath)?.definition;
      if (defName != null) {
        final entry = flcData.lookupSignalEntry(defName, signalName) ??
            flcData.lookupInstanceEntry(defName, signalName);
        if (entry != null) {
          return entry;
        }
      }
    }

    // 2. Top module: the netlist roots at the instance name, but FLC keys by
    //    the definition name captured at build time.
    final modName = _flcModuleName;
    if (modName != null) {
      final entry = flcData.lookupSignalEntry(modName, signalName) ??
          flcData.lookupInstanceEntry(modName, signalName);
      if (entry != null) {
        return entry;
      }
    }

    // 3. Fallback: search all other modules by signal name.
    for (final mod in flcData.moduleNames) {
      if (mod == modName) {
        continue;
      }
      final entry = flcData.lookupSignalEntry(mod, signalName) ??
          flcData.lookupInstanceEntry(mod, signalName);
      if (entry != null) {
        return entry;
      }
    }
    return null;
  }

  FlcFrame? _outputFrame(FlcEntry entry, String type) => entry.outputFrames
      .cast<FlcFrame?>()
      .firstWhere((frame) => frame!.type == type, orElse: () => null);

  /// Resolve a bare signal name to its full occurrence path using the
  /// hierarchy service (e.g. `"equalsMax"` → `"Serializer_W80_8/counter/equalsMax"`).
  ///
  /// Returns null if the hierarchy service is not available or the signal
  /// cannot be found. When multiple matches exist, returns the first.
  String? _resolveOccurrencePath(String signalName) {
    final service = _hierarchyService;
    if (service == null) {
      return null;
    }
    final results = service.searchSignalPaths(signalName, limit: 5);
    // Prefer exact leaf-name match (path ends with /signalName).
    for (final path in results) {
      final leaf = path.contains('/') ? path.split('/').last : path;
      if (leaf == signalName) {
        return path;
      }
    }
    // Fall back to first result if any.
    return results.isNotEmpty ? results.first : null;
  }

  /// Convert an FLC file path to the confapp asset path.
  /// `.dart_tool/../lib/src/memory/fifo.dart` → `rohd_src/memory/fifo.dart`
  String? _flcFileToAsset(String flcPath) {
    final norm = flcPath.replaceAll('.dart_tool/../', '');
    if (norm.startsWith('lib/src/')) {
      return 'rohd_src/${norm.substring('lib/src/'.length)}';
    }
    return null;
  }

  /// Convert a confapp asset path back to the FLC file path suffix.
  /// `rohd_src/serialization/serializer.dart` → `lib/src/serialization/serializer.dart`
  static String? _assetToFlcFile(String assetPath) {
    if (assetPath.startsWith('rohd_src/')) {
      return 'lib/src/${assetPath.substring('rohd_src/'.length)}';
    }
    return null;
  }

  /// Extract the selected text from a [SyntaxCodeController], or if no
  /// selection is active, extract the word surrounding the cursor position.
  ///
  /// Returns null if no meaningful word can be found.
  String? _getWordFromController(SyntaxCodeController controller) {
    final sel = controller.selection;
    final text = controller.text;
    if (text.isEmpty) {
      return null;
    }

    // If there's an active selection (non-collapsed), return the selected text.
    if (sel.isValid && !sel.isCollapsed) {
      final selected = sel.textInside(text).trim();
      if (selected.isNotEmpty) {
        return selected;
      }
    }

    // No selection — try to extract the word at the cursor.
    if (!sel.isValid || sel.baseOffset < 0 || sel.baseOffset > text.length) {
      return null;
    }
    final offset = sel.baseOffset;

    // Expand left/right to find word boundaries (alphanumeric + underscore).
    var start = offset;
    while (start > 0 && _isWordChar(text.codeUnitAt(start - 1))) {
      start--;
    }
    var end = offset;
    while (end < text.length && _isWordChar(text.codeUnitAt(end))) {
      end++;
    }
    if (start == end) {
      return null;
    }
    return text.substring(start, end);
  }

  /// Whether [codeUnit] is a word character (letter, digit, or underscore).
  static bool _isWordChar(int codeUnit) =>
      (codeUnit >= 0x30 && codeUnit <= 0x39) || // 0-9
      (codeUnit >= 0x41 && codeUnit <= 0x5A) || // A-Z
      (codeUnit >= 0x61 && codeUnit <= 0x7A) || // a-z
      codeUnit == 0x5F; // _

  /// Return the 1-based line number at the cursor position, or null.
  static int? _cursorLineFromController(SyntaxCodeController controller) {
    final sel = controller.selection;
    if (!sel.isValid || sel.baseOffset < 0) {
      return null;
    }
    final text = controller.text;
    if (text.isEmpty) {
      return null;
    }
    final offset = sel.baseOffset.clamp(0, text.length);
    // Count newlines before the offset → 1-based line.
    var line = 1;
    for (var i = 0; i < offset; i++) {
      if (text.codeUnitAt(i) == 0x0A) {
        line++;
      }
    }
    return line;
  }

  /// Show a cross-probe context menu at [position] for the word found in
  /// [controller].  Offers "Go to ROHD Source" and "Go to Generated SV"
  /// when FLC data is available and the symbol is found.
  ///
  /// When [sourceFile] is provided (ROHD source editors), a reverse lookup
  /// by file + line is attempted if the word-based lookup fails.
  Future<void> _showCodeContextMenu(
    Offset position,
    SyntaxCodeController controller, {
    String? sourceFile,
  }) async {
    final word = _getWordFromController(controller);

    final items = <PopupMenuEntry<String>>[];

    // Always offer Copy if there is a selection.
    final sel = controller.selection;
    final hasSelection = sel.isValid && !sel.isCollapsed;
    if (hasSelection) {
      items.add(
        const PopupMenuItem<String>(
          value: 'copy',
          height: 32,
          child: Text('Copy', style: TextStyle(fontSize: 13)),
        ),
      );
    }

    // Cross-probe items when we have FLC data and a valid word.
    var entry = word != null ? _lookupFlcEntry(word) : null;
    var resolvedWord = word;

    // Reverse lookup: if word-based lookup failed and we know the source
    // file, find a signal whose ROHD stack trace passes through this line.
    if (entry == null && sourceFile != null && _flcData != null) {
      final cursorLine = _cursorLineFromController(controller);
      if (cursorLine != null) {
        final hits = _flcData!.lookupByRohdLine(
          sourceFile,
          line: cursorLine,
        );
        if (hits.isNotEmpty) {
          entry = hits.first.entry;
          resolvedWord = hits.first.signal;
        }
      }
    }

    if (entry != null) {
      if (items.isNotEmpty) {
        items.add(const PopupMenuDivider(height: 8));
      }
      items.add(
        PopupMenuItem<String>(
          value: 'showSignal',
          height: 32,
          child: Text(
            'Show Signal in Schematic  ($resolvedWord)',
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
      if (entry.frames.isNotEmpty) {
        items.add(
          PopupMenuItem<String>(
            value: 'goToRohd',
            height: 32,
            child: Text(
              'Go to ROHD Source  ($resolvedWord)',
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
      if (entry.svFrame != null) {
        items.add(
          PopupMenuItem<String>(
            value: 'goToSv',
            height: 32,
            child: Text(
              'Go to Generated SV  ($resolvedWord)',
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    }

    if (items.isEmpty) {
      return;
    }

    final rect = RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx,
      position.dy,
    );

    if (!mounted) {
      return;
    }
    final selected = await showMenu<String>(
      context: context,
      position: rect,
      items: items,
    );
    if (selected == null || !mounted) {
      return;
    }

    switch (selected) {
      case 'copy':
        final text = sel.textInside(controller.text);
        await Clipboard.setData(ClipboardData(text: text));
      case 'showSignal':
        // Switch to the ROHD Schematic tab.
        _showLogicalTab(0, enableIfHidden: true);
        // Suppress source navigation while sending to schematic.
        _suppressCrossProbeNav = true;
        // Resolve the signal to its full occurrence path using the hierarchy.
        final occPath = _resolveOccurrencePath(resolvedWord!);
        if (occPath != null) {
          _crossProbeBus.value = [occPath];
        } else {
          // Fallback: prefix with top module name for single-level case.
          final prefix = _moduleName.isNotEmpty ? '$_moduleName/' : '';
          _crossProbeBus.value = ['$prefix$resolvedWord'];
        }
        _suppressCrossProbeNav = false;
      case 'goToRohd':
        await _onGoToSource([resolvedWord!]);
      case 'goToSv':
        await _onGoToSv([resolvedWord!]);
    }
  }

  FlcData? _currentFlcData() {
    final flcData = _flcData;
    if (flcData != null) {
      return flcData;
    }
    final flcJson = _lastFlcJson;
    if (flcJson == null) {
      return null;
    }
    return FlcData.fromJson(flcJson.cast<String, dynamic>());
  }

  /// Return source format identifiers available for [module].
  ///
  /// Mirrors the local FlcService used by ROHD DevTools: scan both signals
  /// and block/instance entries for ROHD stack frames and output-language
  /// frames (`sv`, `sc`, etc.), then fall back to the instance name when the
  /// schematic queried by definition name but FLC data is keyed by instance.
  Future<Set<String>> _getModuleFormats(
    String module, {
    List<String>? instancePath,
  }) async {
    var formats = _formatsForModule(module);
    if (formats.isNotEmpty) {
      return formats;
    }

    if (instancePath != null) {
      final instanceName = instancePath.lastWhere(
        (segment) => segment.isNotEmpty,
        orElse: () => '',
      );
      if (instanceName.isNotEmpty && instanceName != module) {
        formats = _formatsForModule(instanceName);
        if (formats.isNotEmpty) {
          return formats;
        }
      }
    }

    final primaryModule = _flcModuleName ?? _lastModuleName;
    if (primaryModule != null && primaryModule != module) {
      return _formatsForModule(primaryModule);
    }

    return const {};
  }

  Set<String> _formatsForModule(String moduleName) {
    final flcData = _currentFlcData();
    if (flcData == null) {
      return const {};
    }

    final formats = <String>{};
    void addEntryFormats(FlcEntry? entry) {
      if (entry == null) {
        return;
      }
      if (entry.frames.isNotEmpty) {
        formats.add('rohd');
      }
      for (final outputFrame in entry.outputFrames) {
        if (outputFrame.type.isNotEmpty) {
          formats.add(outputFrame.type);
        }
      }
    }

    for (final signal in flcData.signalNamesFor(moduleName)) {
      addEntryFormats(flcData.lookupSignalEntry(moduleName, signal));
      if (formats.containsAll(['rohd', 'sv', 'sc'])) {
        return formats;
      }
    }
    for (final instance in flcData.instanceNamesFor(moduleName)) {
      addEntryFormats(flcData.lookupInstanceEntry(moduleName, instance));
      if (formats.containsAll(['rohd', 'sv', 'sc'])) {
        return formats;
      }
    }
    return formats;
  }

  Future<List<Map<String, dynamic>>> _lookupSignalFrames({
    required List<Map<String, String>> signals,
    String? format,
  }) async {
    final frames = <Map<String, dynamic>>[];
    final flcData = _currentFlcData();
    if (flcData == null) {
      return frames;
    }

    for (final signal in signals) {
      final module = signal['module'] ?? _flcModuleName ?? _lastModuleName;
      final name = signal['name'];
      if (module == null || name == null) {
        continue;
      }
      final entry = flcData.lookupSignalEntry(module, name) ??
          flcData.lookupInstanceEntry(module, name);
      if (entry == null) {
        continue;
      }
      frames.addAll(_entryToSourceFrameMaps(entry, signalName: name));
    }

    if (format == null) {
      return frames;
    }
    return frames.where((frame) => frame['type'] == format).toList();
  }

  List<Map<String, dynamic>> _entryToSourceFrameMaps(
    FlcEntry entry, {
    String? signalName,
  }) {
    final frames = <Map<String, dynamic>>[];
    for (final frame in entry.frames.reversed) {
      frames.add(_frameToSourceMap(frame, signalName: signalName));
    }
    for (final frame in entry.outputFrames) {
      frames.add(_frameToSourceMap(frame, signalName: signalName));
    }
    return frames;
  }

  Map<String, dynamic> _frameToSourceMap(
    FlcFrame frame, {
    String? signalName,
  }) =>
      {
        'file': frame.file,
        'line': frame.line,
        'col': frame.column,
        'desc': signalName,
        'type': frame.type,
      };

  /// Ensure FLC data is available for source navigation.
  ///
  /// The ROHD Source tab is optional and disabled by default, but source
  /// navigation from the schematic still needs FLC data. Lazily build it from
  /// the last generated module when needed.
  Future<bool> _ensureFlcDataLoaded() async {
    if (_flcData != null && !_flcData!.isEmpty) {
      return true;
    }

    if (_lastBuiltModule == null ||
        _lastRtlRes == null ||
        _lastModuleName == null) {
      return false;
    }

    final component = context.read<ComponentCubit>().state;
    if (_lastFlcJson != null) {
      await _buildCrossProbeAndHighlight(
        component,
        _lastRtlRes!,
        _lastModuleName!,
        flcJson: _lastFlcJson,
      );
    } else {
      await _generateFlcTrace(component);
    }
    return _flcData != null && !_flcData!.isEmpty;
  }

  /// Handle "Go to SV" from the schematic's context menu.
  ///
  /// Looks up the signal in FlcData and navigates to the corresponding
  /// SV position, switching to the Generated SV tab.
  Future<void> _onGoToSv(List<String> paths) async {
    if (paths.isEmpty) {
      return;
    }
    final hasFlcData = await _ensureFlcDataLoaded();
    if (!mounted) {
      return;
    }
    if (!hasFlcData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No source-location data available for this component'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final path = paths.first;
    final leaf = path.contains('/') ? path.split('/').last : path;

    final entry = _lookupFlcEntry(path);
    if (entry == null || entry.svFrame == null) {
      debugPrint('[GoToSV] "$leaf" not found in FlcData or has no SV frame');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No generated SV position for this symbol'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final svFile = entry.svFrame!.file.split('/').last;
    _setSvHighlightAndPendingScroll(
      line: entry.svFrame!.line,
      column: entry.svFrame!.column,
    );

    // Switch to the Generated SV tab.
    _showLogicalTab(2, enableIfHidden: true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Generated SV position found '
          '$svFile:${entry.svFrame!.line}:${entry.svFrame!.column}',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Handles "Go to SystemC" from schematic/editor context menus.
  // The planned SystemC tab will register this navigation handler.
  // ignore: unused_element
  Future<void> _onGoToSc(List<String> paths) async {
    if (paths.isEmpty) {
      return;
    }
    final hasFlcData = await _ensureFlcDataLoaded();
    if (!mounted) {
      return;
    }
    if (!hasFlcData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No source-location data available for this component'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final path = paths.first;
    final leaf = path.contains('/') ? path.split('/').last : path;

    final entry = _lookupFlcEntry(path);
    final scFrame = entry == null ? null : _outputFrame(entry, 'sc');
    if (entry == null || scFrame == null) {
      debugPrint('[GoToSC] "$leaf" not found in FlcData or has no SC frame');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No generated SystemC position for this symbol'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final scFile = scFrame.file.split('/').last;
    _setScHighlightAndPendingScroll(
      line: scFrame.line,
      column: scFrame.column,
    );

    _showLogicalTab(3, enableIfHidden: true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Generated SystemC position found '
          '$scFile:${scFrame.line}:${scFrame.column}',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _onGoToSourceFormat(
    RohdSourceFormat format,
    List<String> paths,
  ) async {
    final formatLabel = switch (format) {
      RohdSourceFormat.rohd => 'ROHD (Dart)',
      RohdSourceFormat.sv => 'SystemVerilog',
      RohdSourceFormat.sc => 'SystemC',
      RohdSourceFormat.fst => 'Waveform (FST)',
    };

    switch (format) {
      case RohdSourceFormat.rohd:
        await _onGoToSource(paths);
      case RohdSourceFormat.sv:
        await _onGoToSv(paths);
      case RohdSourceFormat.sc:
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SystemC generation is not available'),
            duration: Duration(seconds: 2),
          ),
        );
      case RohdSourceFormat.fst:
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$formatLabel navigation is not available in Confapp',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  /// Handle "Go to Source" from the schematic's context menu.
  ///
  /// If there are multiple ROHD stack-trace entries, shows a popup menu
  /// to let the user pick.  Then navigates both the ROHD source editor
  /// and the SV editor to the corresponding locations, and shows a
  /// snackbar summarizing what was found.
  Future<void> _onGoToSource(List<String> paths) async {
    if (paths.isEmpty) {
      return;
    }
    final hasFlcData = await _ensureFlcDataLoaded();
    if (!mounted) {
      return;
    }
    if (!hasFlcData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No source-location data available for this component'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final candidates = <MapEntry<String, FlcEntry>>[];
    final seenPaths = <String>{};
    for (final path in paths) {
      if (!seenPaths.add(path)) {
        continue;
      }
      final leaf = path.contains('/') ? path.split('/').last : path;
      final entry = _lookupFlcEntry(path);
      if (entry != null) {
        candidates.add(MapEntry(path, entry));
      } else {
        debugPrint('[GoToSource] "$leaf" not found in FlcData');
      }
    }

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No source position located'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    MapEntry<String, FlcEntry>? selectedCandidate;
    if (candidates.length == 1) {
      selectedCandidate = candidates.first;
    } else {
      selectedCandidate = await _showTraceSelectionMenu(candidates);
      if (selectedCandidate == null || !mounted) {
        return;
      }
    }

    final selectedPath = selectedCandidate.key;
    final leaf = selectedPath.contains('/')
        ? selectedPath.split('/').last
        : selectedPath;
    final entry = selectedCandidate.value;

    final rohdFrames = entry.frames;

    if (rohdFrames.length > 1) {
      // Multiple ROHD frames — show a selection popup.
      await _showFrameSelectionMenu(leaf, entry);
    } else {
      // Single frame (or none) — navigate directly.
      final rohdFrame = rohdFrames.isNotEmpty ? rohdFrames.first : null;
      _navigateBothEditors(leaf, entry, rohdFrame);
    }
  }

  Future<MapEntry<String, FlcEntry>?> _showTraceSelectionMenu(
    List<MapEntry<String, FlcEntry>> candidates,
  ) async {
    final items = <PopupMenuEntry<int>>[];
    for (var i = 0; i < candidates.length; i++) {
      final path = candidates[i].key;
      final entry = candidates[i].value;
      final traceCount = entry.frames.length;
      final traceLabel = traceCount == 1 ? '1 trace' : '$traceCount traces';
      final svLabel = entry.svFrame == null
          ? 'no SV'
          : '${entry.svFrame!.file.split('/').last}:${entry.svFrame!.line}';
      items.add(
        PopupMenuItem<int>(
          value: i,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$path  $traceLabel  $svLabel',
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    final pos = _lastPointerPosition;
    final rect = RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy);

    if (!mounted) {
      return null;
    }
    final selected = await showMenu<int>(
      context: context,
      position: rect,
      items: items,
    );
    if (selected == null || !mounted) {
      return null;
    }
    return candidates[selected];
  }

  /// Show a popup menu listing the ROHD frames so the user can pick one.
  ///
  /// Each menu item is enriched with the source line text loaded from
  /// the bundled asset (similar to EnrichedFrame in the devtools extension).
  Future<void> _showFrameSelectionMenu(
    String symbolName,
    FlcEntry entry,
  ) async {
    // Reverse so outermost (module-level) frames appear first in the menu.
    final rohdFrames = entry.frames.reversed.toList();

    // Load source line text for each frame (prefix string).
    final labels = <String>[];
    for (final frame in rohdFrames) {
      final fileName = frame.file.split('/').last;
      final locationStr = '$fileName:${frame.line}';
      final asset = _flcFileToAsset(frame.file);
      if (asset != null) {
        try {
          // Use the cached future if already loaded, else load now.
          _rohdFileFutures.putIfAbsent(
            asset,
            () => rootBundle.loadString(bundledSourceAssetPath(asset)),
          );
          final source = await _rohdFileFutures[asset]!;
          final lines = source.split('\n');
          if (frame.line > 0 && frame.line <= lines.length) {
            final lineText = lines[frame.line - 1].trim();
            labels.add('$locationStr  $lineText');
          } else {
            labels.add(locationStr);
          }
        } on Object {
          labels.add(locationStr);
        }
      } else {
        labels.add(locationStr);
      }
    }

    final items = <PopupMenuEntry<int>>[];
    for (var i = 0; i < rohdFrames.length; i++) {
      items.add(
        PopupMenuItem<int>(
          value: i,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            labels[i],
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    // Position the menu near the last pointer-down (close to the
    // right-click context menu that triggered "Go to Source").
    final pos = _lastPointerPosition;
    final rect = RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy);

    if (!mounted) {
      return;
    }
    final selected = await showMenu<int>(
      context: context,
      position: rect,
      items: items,
    );
    if (selected == null || !mounted) {
      return; // user dismissed
    }
    final rohdFrame = rohdFrames[selected];
    _navigateBothEditors(symbolName, entry, rohdFrame);
  }

  /// Navigate both the ROHD source editor and SV editor, then show a
  /// snackbar summarizing what was found.
  void _navigateBothEditors(
    String symbolName,
    FlcEntry entry,
    FlcFrame? rohdFrame,
  ) {
    final messages = <String>[];

    // Navigate ROHD source.
    if (rohdFrame != null) {
      final asset = _flcFileToAsset(rohdFrame.file);
      final rohdFile = rohdFrame.file.split('/').last;
      navigateToSource(
        line: rohdFrame.line,
        column: rohdFrame.column,
        file: asset,
      );
      messages.add(
        'ROHD source position found $rohdFile:'
        '${rohdFrame.line}:${rohdFrame.column}',
      );
    }

    // Navigate SV (set highlight + pending scroll; don't switch tabs).
    if (entry.svFrame != null) {
      final svFile = entry.svFrame!.file.split('/').last;
      _setSvHighlightAndPendingScroll(
        line: entry.svFrame!.line,
        column: entry.svFrame!.column,
      );
      messages.add(
        'Generated SV position found $svFile:'
        '${entry.svFrame!.line}:${entry.svFrame!.column}',
      );
    } else {
      messages.add('No generated SV position for this symbol');
    }

    final scFrame = _outputFrame(entry, 'sc');
    if (scFrame != null) {
      final scFile = scFrame.file.split('/').last;
      _setScHighlightAndPendingScroll(
        line: scFrame.line,
        column: scFrame.column,
      );
      messages.add(
        'Generated SystemC position found $scFile:'
        '${scFrame.line}:${scFrame.column}',
      );
    }

    if (messages.isEmpty) {
      messages.add('No source position located');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(messages.join('\n')),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Set the SV editor highlight and store pending scroll without switching
  /// to the SV tab.  The scroll will apply when the user switches to tab 2.
  void _setSvHighlightAndPendingScroll({
    required int line,
    int? column,
  }) {
    if (_svController == null) {
      return;
    }
    final effectiveLine = line;
    setState(() {
      _highlightedSvLine = effectiveLine;
    });
    final offset = _setSelectionAndComputeScroll(
      _svController!,
      line: effectiveLine,
      column: column,
      scrollController: _svScrollController,
    );
    if (_tabController.index == 2 && _svScrollController.hasClients) {
      // SV tab already visible — scroll now.
      if (offset != null) {
        _svScrollController.animateTo(
          offset.clamp(0.0, _svScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // Store for when the user switches to the SV tab.
      _pendingSvScroll = offset;
      _pendingSvLine = effectiveLine;
      _pendingSvColumn = column;
    }
  }

  /// Set the SystemC editor highlight and store pending scroll without
  /// switching to the SystemC tab. The scroll applies when tab 3 is visible.
  void _setScHighlightAndPendingScroll({
    required int line,
    int? column,
  }) {
    if (_scController == null) {
      return;
    }
    final effectiveLine = line;
    setState(() {
      _highlightedScLine = effectiveLine;
    });
    final offset = _setSelectionAndComputeScroll(
      _scController!,
      line: effectiveLine,
      column: column,
      scrollController: _scScrollController,
    );
    if (_tabController.index == 3 && _scScrollController.hasClients) {
      if (offset != null) {
        _scScrollController.animateTo(
          offset.clamp(0.0, _scScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _pendingScScroll = offset;
      _pendingScLine = effectiveLine;
      _pendingScColumn = column;
    }
  }

  /// Handle cross-probe events arriving on the shared bus.
  ///
  /// Signal paths are hierarchical strings like `"top/counter/clk"`.
  /// We strip each to its leaf name and look it up in the [FlcData]
  /// to find SV and ROHD source line numbers.  For "Send Signals" we
  /// navigate automatically to the first/best frame without a popup.
  void _onCrossProbeSignals() {
    if (_suppressCrossProbeNav) {
      return;
    }
    final paths = _crossProbeBus.value;
    if (paths == null || paths.isEmpty || _flcData == null) {
      return;
    }

    // Use the first signal path for highlighting.
    final path = paths.first;
    // Extract leaf signal name: "top/counter/clk" → "clk"
    final leaf = path.contains('/') ? path.split('/').last : path;

    final entry = _lookupFlcEntry(leaf);
    if (entry == null) {
      debugPrint('[CrossProbe] signal "$leaf" not found in FlcData');
      return;
    }

    // Navigate SV if available.
    if (entry.svFrame != null) {
      navigateToSV(
        line: entry.svFrame!.line,
        column: entry.svFrame!.column,
      );
      debugPrint('[CrossProbe] scrolled SV to line ${entry.svFrame!.line}');
    }

    final scFrame = _outputFrame(entry, 'sc');
    if (scFrame != null) {
      navigateToSC(
        line: scFrame.line,
        column: scFrame.column,
      );
      debugPrint('[CrossProbe] scrolled SystemC to line ${scFrame.line}');
    }

    // Navigate ROHD source to the first frame in an available asset.
    if (entry.frames.isNotEmpty) {
      // If multiple ROHD frames are available, show the selection menu
      // so the user can pick the desired call-site.  Otherwise navigate
      // directly to the single available frame.
      final rohdFrames = entry.frames;
      if (rohdFrames.length > 1) {
        unawaited(_showFrameSelectionMenu(leaf, entry));
      } else {
        final frame = rohdFrames.first;
        final asset = _flcFileToAsset(frame.file);
        navigateToSource(line: frame.line, column: frame.column, file: asset);
        debugPrint(
          '[CrossProbe] scrolled ROHD to line ${frame.line}'
          ' in ${frame.file.split('/').last}',
        );
      }
    }
  }

  /// Builds a read-only code field wrapped in a [Stack] with a persistent
  /// line-highlight overlay that is visible regardless of focus.
  ///
  /// [highlightLine] is 1-based (or null for no highlight).
  ///
  /// Uses a custom line-number gutter instead of the package's built-in one
  /// so that line-numbers, code text, and highlight all share the same
  /// vertical top offset ([_codeTopPad]).
  Widget _highlightedCodeField({
    required SyntaxCodeController controller,
    required FocusNode focusNode,
    required ScrollController verticalScrollController,
    required ScrollController horizontalScrollController,
    Key? fieldKey,
    int? highlightLine,
    String? sourceFile,
  }) {
    final lineCount = controller.lineCount;

    return Listener(
      onPointerDown: (event) {
        // Track pointer for downstream popup positioning.
        _lastPointerPosition = event.position;
        if (event.buttons == 2) {
          // Secondary (right) mouse button.  Show our cross-probe menu
          // immediately — the controller's selection is already up-to-date
          // from the previous pointer events.
          unawaited(
            _showCodeContextMenu(
              event.position,
              controller,
              sourceFile: sourceFile,
            ),
          );
        }
      },
      child: browserContextMenuSuppressor(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableCodeWidth = constraints.maxWidth.isFinite
                ? (constraints.maxWidth - 58).clamp(0.0, double.infinity)
                : constraints.maxWidth;
            final viewportWidth = _codeViewportWidthFor(
              BoxConstraints(maxWidth: availableCodeWidth),
            );
            final scrollExtentWidth = _measureCodeScrollExtentWidth(
              controller.text,
            );

            return Scrollbar(
              controller: horizontalScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              thickness: 10,
              radius: const Radius.circular(4),
              scrollbarOrientation: ScrollbarOrientation.top,
              notificationPredicate: (notification) =>
                  notification.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                controller: verticalScrollController,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Custom gutter ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(top: _codeTopPad, left: 8),
                      child: SizedBox(
                        width: 40,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(
                              lineCount,
                              (i) => SizedBox(
                                    height: _lineHeight,
                                    child: Text(
                                      '${i + 1}',
                                      style: _codeTextStyle.copyWith(
                                          color: Colors.grey),
                                      textAlign: TextAlign.right,
                                    ),
                                  )),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // ── Code + highlight overlay ───────────────────────────
                    // Keep the viewport near 80 columns, while the scroll child
                    // is as wide as the longest line so long generated
                    // assignments can be reached horizontally without adding
                    // visual rows.  The horizontal Scrollbar wraps the vertical
                    // viewport, so its top track stays pinned while vertical
                    // scrolling moves the code content underneath it.
                    SizedBox(
                      width: viewportWidth,
                      child: SingleChildScrollView(
                        controller: horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: scrollExtentWidth,
                          child: Stack(
                            children: [
                              TextField(
                                key: fieldKey,
                                controller: controller,
                                focusNode: focusNode,
                                readOnly: true,
                                maxLines: null,
                                scrollPhysics:
                                    const NeverScrollableScrollPhysics(),
                                smartDashesType: SmartDashesType.disabled,
                                smartQuotesType: SmartQuotesType.disabled,
                                style: _codeTextStyle,
                                decoration: const InputDecoration(
                                  isCollapsed: true,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 16),
                                  disabledBorder: InputBorder.none,
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                              if (highlightLine != null)
                                Positioned(
                                  top: _codeTopPad +
                                      (highlightLine - 1) * _lineHeight,
                                  left: 0,
                                  right: 0,
                                  height: _lineHeight,
                                  child: IgnorePointer(
                                    child: Container(
                                      // semi-transparent amber
                                      color: const Color(0x44FFC107),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _invalidateGeneratedOutputs() {
    final component = context.read<ComponentCubit>().state;
    context.read<SystemVerilogCubit>().initializeData();
    _disposeRohdSubtabs();
    setState(() {
      _rohdNetlistJson = null;
      _yosysJson = null;
      _synthSchematicLoading = false;
      _synthSchematicRequestId++;
      _flcData = null;
      _flcModuleName = null;
      _hierarchyService = null;
      _lastRohdSource = null;
      _highlightedSvLine = null;
      _highlightedRohdLine = null;
      _highlightedScLine = null;
      _rohdSourceFiles = [];
      _lastBuiltModule = null;
      _lastRtlRes = null;
      _lastScRes = null;
      _lastModuleName = null;
      _lastFlcJson = null;
      _moduleName = '';
    });
    _initPrimaryRohdSubtab(component);
  }

  Widget _generateKnobControl(String label, ConfigKnob<dynamic> knob) {
    final Widget selector;

    final decoration = InputDecoration(
      border: const OutlineInputBorder(),
      labelText: label,
      isDense: true,
    );
    final key = Key(label);

    if (knob is TextConfigKnob) {
      selector = TextFormField(
        key: key,
        initialValue: knob.valueString,
        decoration: decoration,
        validator: (value) {
          if ((value == null || value.isEmpty) && !knob.allowEmpty) {
            return 'Please enter value';
          }
          return null;
        },
        inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
        onChanged: (value) {
          if (value.isEmpty) {
            return;
          }
          knob.setValueFromString(value);
          _invalidateGeneratedOutputs();
        },
      );
    } else if (knob is ToggleConfigKnob) {
      selector = Row(
        key: key,
        children: [
          Checkbox(
            value: knob.value,
            onChanged: (value) {
              if (value == null || value == knob.value) {
                return;
              }
              knob.value = value;
              _invalidateGeneratedOutputs();
            },
          ),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (knob is ChoiceConfigKnob) {
      selector = DropdownButtonFormField(
        key: key,
        decoration: decoration,
        items: knob.choices
            .map(
              (choice) => DropdownMenuItem(
                value: choice,
                child: Text(choice.toString().split('.').last),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value == null || value == knob.value) {
            return;
          }
          knob.value = value;
          _invalidateGeneratedOutputs();
        },
        initialValue: knob.value,
      );
    } else if (knob is ListOfKnobsKnob) {
      selector = _containerOfKnobs(
        title: knob.name,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Add or remove: '),
              IconButton(
                onPressed: () {
                  knob.value += 1;
                  _invalidateGeneratedOutputs();
                },
                icon: const Icon(Icons.add),
              ),
              IconButton(
                onPressed: () {
                  if (knob.value == 0) {
                    return;
                  }
                  knob.value -= 1;
                  _invalidateGeneratedOutputs();
                },
                icon: const Icon(Icons.remove),
              ),
            ],
          ),
          for (final (index, subKnob) in knob.knobs.indexed)
            // Animate size and add/remove transitions for each generated item.
            // AnimatedSize handles height changes; AnimatedSwitcher provides
            // a fade/size transition when items are added/removed.
            AnimatedSize(
              key: ValueKey('${knob.name}-$index-anim'),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    alignment: Alignment.center,
                    child: child,
                  ),
                ),
                child: Container(
                  key: ValueKey('${knob.name}-$index'),
                  child: subKnob is GroupOfKnobs
                      ? Column(
                          children: [
                            _containerOfKnobs(
                              title: '${subKnob.name} $index',
                              children: [
                                for (final subKnobEntry
                                    in subKnob.subKnobs.entries)
                                  _generateKnobControl(
                                    subKnobEntry.key,
                                    subKnobEntry.value,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        )
                      : Column(
                          children: [
                            _generateKnobControl(
                              '${knob.name} $index',
                              subKnob,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                ),
              ),
            ),
        ],
      );
    } else if (knob is GroupOfKnobs) {
      selector = _containerOfKnobs(
        title: knob.name,
        children: [
          for (final subKnobEntry in knob.subKnobs.entries)
            _generateKnobControl(subKnobEntry.key, subKnobEntry.value),
        ],
      );
    } else {
      selector = Text('Unknown knob type for $label: ${knob.runtimeType}');
    }

    return Padding(padding: const EdgeInsets.only(top: 10), child: selector);
  }

  Widget _containerOfKnobs({
    required List<Widget> children,
    required String title,
  }) =>
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      );

  Widget _copyAndDownloadButtons({
    required bool isLoading,
    required String code,
    required String fileName,
    int maxChars = 1000000,
  }) {
    final tooBig = code.length > maxChars;

    return Align(
      alignment: Alignment.topRight,
      child: isLoading
          ? const CircularProgressIndicator()
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: tooBig
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: code),
                            );
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Text copied to clipboard'),
                              ),
                            );
                          },
                    child: tooBig
                        ? const Text('Copy (too large)')
                        : const Text('Copy'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      downloadFile(content: code, fileName: fileName);
                    },
                    child: const Text('Download'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _generatedRtlCard(double screenHeight, double screenWidth) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: BlocBuilder<SystemVerilogCubit, SystemVerilogCubitState>(
            builder: (context, state) {
              if (state.generationState == GenerationState.initial) {
                return const Center(
                  child: Text(
                    'Click "Generate" to see the generated SV',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }
              final svCode = state.systemVerilog;
              _svController ??= HighlightCodeController(
                text: svCode,
                languageName: 'verilog',
                language: highlight_verilog.verilog,
              );
              _svController!.replaceSource(svCode);
              return Column(
                children: [
                  _copyAndDownloadButtons(
                    isLoading: state.generationState == GenerationState.loading,
                    code: svCode,
                    fileName: '${state.name}.sv',
                  ),
                  Expanded(
                    child: _highlightedCodeField(
                      controller: _svController!,
                      focusNode: _svFocusNode,
                      verticalScrollController: _svScrollController,
                      horizontalScrollController: _svHorizontalScrollController,
                      fieldKey: const Key('generatedSV'),
                      highlightLine: _highlightedSvLine,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );

  // The planned SystemC tab will display this card.
  // ignore: unused_element
  Widget _generatedSystemCCard(double screenHeight, double screenWidth) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: BlocBuilder<SystemVerilogCubit, SystemVerilogCubitState>(
            builder: (context, state) {
              if (state.generationState == GenerationState.initial) {
                return const Center(
                  child: Text(
                    'Click "Generate" to see the generated SystemC',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }
              final scCode = state.systemC;
              _scController ??= HighlightCodeController(
                text: scCode,
                languageName: 'cpp',
                language: highlight_cpp.cpp,
              );
              _scController!.replaceSource(scCode);
              return Column(
                children: [
                  _copyAndDownloadButtons(
                    isLoading: state.generationState == GenerationState.loading,
                    code: scCode,
                    fileName: '${state.name}.sc',
                  ),
                  Expanded(
                    child: _highlightedCodeField(
                      controller: _scController!,
                      focusNode: _scFocusNode,
                      verticalScrollController: _scScrollController,
                      horizontalScrollController: _scHorizontalScrollController,
                      highlightLine: _highlightedScLine,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );

  Widget _generatedSchCard(double screenHeight, double screenWidth) => Card(
        child: Column(
          children: [
            if (_yosysJson != null)
              _copyAndDownloadButtons(
                isLoading: false,
                code: _yosysJson!,
                fileName: '$_moduleName.synth.json',
              ),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                child: BlocBuilder<SystemVerilogCubit, SystemVerilogCubitState>(
                  builder: (context, state) {
                    if (state.generationState == GenerationState.done &&
                        _yosysJson != null) {
                      return BlocBuilder<ThemeCubit, material_ui.ThemeMode>(
                        builder: (context, themeMode) {
                          final isDark =
                              themeMode == material_ui.ThemeMode.dark;
                          return Listener(
                            onPointerDown: (event) {
                              _lastPointerPosition = event.position;
                            },
                            child: EmbeddedSchematicViewer(
                              key: ValueKey('synth-schematic-$_expansionMode'),
                              schematicJson: _yosysJson,
                              initialThemeMode: isDark
                                  ? SchematicThemeMode.dark
                                  : SchematicThemeMode.light,
                              initialExpansionMode: _expansionMode,
                              onSendSignals: (paths) {
                                _crossProbeBus.value = paths;
                              },
                              onGoToSourceCallback: _onGoToSourceFormat,
                              incomingSignalPaths: _crossProbeBus,
                              extensionClient: _sourceFormatClient,
                            ),
                          );
                        },
                      );
                    } else if (state.generationState == GenerationState.done &&
                        _synthSchematicLoading) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text(
                              'Synthesizing schematic...',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return const Center(
                        child: Text(
                          'Click "Generate" to see the synthesized schematic',
                          style: TextStyle(fontSize: 16),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      );

  Widget _rohdSchematicCard(double screenHeight, double screenWidth) => Card(
        child: Column(
          children: [
            Row(
              children: [
                if (_rohdNetlistJson != null)
                  Expanded(
                    child: _copyAndDownloadButtons(
                      isLoading: false,
                      code: _rohdNetlistJson!,
                      fileName: '$_moduleName.rohd.json',
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: DropdownButton<SchematicExpansionMode>(
                    value: _expansionMode,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(
                        value: SchematicExpansionMode.defaultView,
                        child: Text('Default'),
                      ),
                      DropdownMenuItem(
                        value: SchematicExpansionMode.collapsed,
                        child: Text('Collapsed'),
                      ),
                      DropdownMenuItem(
                        value: SchematicExpansionMode.blocksOnly,
                        child: Text('Blocks Only'),
                      ),
                      DropdownMenuItem(
                        value: SchematicExpansionMode.fullyExpanded,
                        child: Text('Fully Expanded'),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null && mode != _expansionMode) {
                        setState(() {
                          _expansionMode = mode;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                child: BlocBuilder<SystemVerilogCubit, SystemVerilogCubitState>(
                  builder: (context, state) {
                    if (state.generationState == GenerationState.done &&
                        _rohdNetlistJson != null) {
                      return BlocBuilder<ThemeCubit, material_ui.ThemeMode>(
                        builder: (context, themeMode) {
                          final isDark =
                              themeMode == material_ui.ThemeMode.dark;
                          return Listener(
                            onPointerDown: (event) {
                              _lastPointerPosition = event.position;
                            },
                            child: EmbeddedSchematicViewer(
                              // Force re-render when expansion mode changes.
                              key: ValueKey('rohd-schematic-$_expansionMode'),
                              schematicJson: _rohdNetlistJson,
                              initialThemeMode: isDark
                                  ? SchematicThemeMode.dark
                                  : SchematicThemeMode.light,
                              initialExpansionMode: _expansionMode,
                              onSendSignals: (paths) {
                                _crossProbeBus.value = paths;
                              },
                              onGoToSourceCallback: _onGoToSourceFormat,
                              incomingSignalPaths: _crossProbeBus,
                              extensionClient: _sourceFormatClient,
                            ),
                          );
                        },
                      );
                    } else {
                      return const Center(
                        child: Text(
                          'Click "Generate" to see the ROHD schematic',
                          style: TextStyle(fontSize: 16),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      );

  Widget _rohdSourceCard(double screenHeight, double screenWidth) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _rohdSourceFiles.isNotEmpty
              ? _rohdSourceSubtabs()
              : BlocBuilder<ComponentCubit, Configurator>(
                  builder: (context, component) {
                    final mod = component.createModule();
                    final rawType = mod.runtimeType.toString();
                    final typeName = rawType.contains('<')
                        ? rawType.substring(0, rawType.indexOf('<'))
                        : rawType;
                    final assetPath = moduleSourceAssets[typeName];
                    if (assetPath == null) {
                      return Center(
                        child: Text('No source available for $typeName'),
                      );
                    }
                    return _rohdSourceFileView(assetPath);
                  },
                ),
        ),
      );

  /// The subtab view for ROHD source files. Separated so it doesn't get
  /// rebuilt inside a BlocBuilder — TabBarView needs stable widget identity
  /// during page animations.
  Widget _rohdSourceSubtabs() {
    final tabCtrl = _rohdSourceTabController;
    if (tabCtrl == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Ensure a stable GlobalKey so that Flutter preserves the TabBarView
    // element across parent setState rebuilds (highlight changes, etc.).
    _subtabViewKey ??= GlobalKey();

    return Column(
      children: [
        TabBar(
          controller: tabCtrl,
          isScrollable: true,
          tabs: _rohdSourceFiles
              .map((p) => Tab(text: p.split('/').last))
              .toList(),
        ),
        Expanded(
          child: TabBarView(
            key: _subtabViewKey,
            controller: tabCtrl,
            children: _rohdSourceFiles
                .map(
                  (p) => KeyedSubtree(
                    key: ValueKey(p),
                    child: _rohdSourceFileView(p),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  /// Build a single ROHD source file viewer for asset at [assetPath].
  Widget _rohdSourceFileView(String assetPath) {
    // Cache the future so FutureBuilder doesn't restart on every rebuild.
    _rohdFileFutures.putIfAbsent(
      assetPath,
      () => rootBundle.loadString(bundledSourceAssetPath(assetPath)),
    );
    _rohdSourceViewFutures.putIfAbsent(
      assetPath,
      () async => (
        source: await _rohdFileFutures[assetPath]!,
        syntaxHighlighter: await _dartSyntaxHighlighter,
      ),
    );
    return FutureBuilder<_RohdSourceDocument>(
      future: _rohdSourceViewFutures[assetPath],
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error preparing source view: ${snapshot.error}'),
          );
        }
        final document = snapshot.data!;
        final source = document.source;

        // Create or update per-file controller.
        if (!_rohdFileControllers.containsKey(assetPath)) {
          _rohdFileControllers[assetPath] = DartSyntaxCodeController(
            text: source,
            syntaxHighlighter: document.syntaxHighlighter,
          );
        }
        _rohdFileScrollControllers.putIfAbsent(
          assetPath,
          ScrollController.new,
        );
        _rohdFileHorizontalScrollControllers.putIfAbsent(
          assetPath,
          ScrollController.new,
        );
        _rohdFileFocusNodes.putIfAbsent(assetPath, FocusNode.new);

        final ctrl = _rohdFileControllers[assetPath]!;
        final scrollCtrl = _rohdFileScrollControllers[assetPath]!;
        final horizontalScrollCtrl =
            _rohdFileHorizontalScrollControllers[assetPath]!;
        final focusNode = _rohdFileFocusNodes[assetPath]!;
        final highlightLine = _rohdFileHighlightLines[assetPath];

        // Also keep legacy single-controller in sync for backwards compat.
        if (_rohdSourceFiles.isNotEmpty &&
            assetPath == _rohdSourceFiles.first) {
          _rohdSourceController = ctrl;
        }

        // Apply any pending scroll — schedule via postFrameCallback so
        // the SingleChildScrollView has attached to scrollCtrl.
        final pendingScroll = _rohdFilePendingScrolls[assetPath];
        if (pendingScroll != null) {
          // Recompute the offset now that the controller exists (the stored
          // value may be a placeholder 0 from navigateToSource).
          final hl = _rohdFileHighlightLines[assetPath];
          final effectiveScroll = (hl != null)
              ? (_setSelectionAndComputeScroll(
                    ctrl,
                    line: hl,
                    scrollController: scrollCtrl,
                  ) ??
                  pendingScroll)
              : pendingScroll;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (scrollCtrl.hasClients) {
              _rohdFilePendingScrolls[assetPath] = null;
              scrollCtrl.animateTo(
                effectiveScroll.clamp(0.0, scrollCtrl.position.maxScrollExtent),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _copyAndDownloadButtons(
              isLoading: false,
              code: source,
              fileName: assetPath.split('/').last,
            ),
            Expanded(
              child: _highlightedCodeField(
                controller: ctrl,
                focusNode: focusNode,
                verticalScrollController: scrollCtrl,
                horizontalScrollController: horizontalScrollCtrl,
                highlightLine: highlightLine,
                sourceFile: _assetToFlcFile(assetPath),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Generation subroutines ─────────────────────────────────────────────
  //
  // Each subroutine handles one output tab's generation step.
  // The Generate button calls all enabled steps; lazy enable of a tab
  // can call its step individually using cached state.

  /// Step: Build the module and generate SystemVerilog (base output).
  /// Populates [_lastBuiltModule], generated text, and module name.
  Future<void> _generateBase(Configurator component) async {
    final mod = component.createModule();
    await mod.build();
    final moduleName = mod.definitionName;
    final rtlRes = mod.generateSynth();

    _lastBuiltModule = mod;
    _lastRtlRes = rtlRes;
    _lastScRes = 'SystemC generation is unavailable with this ROHD version.';
    _lastModuleName = moduleName;
  }

  /// Step: Generate ROHD netlist JSON → Tab 0 (ROHD Schematic).
  Future<void> _generateRohdSchematic() async {
    final mod = _lastBuiltModule;
    if (mod == null) {
      return;
    }
    final synthesizer = NetlistSynthesizer();
    final builder = SynthBuilder(mod, synthesizer);
    final netlistJson = synthesizer.generateCombinedJson(builder, mod);
    setState(() {
      _rohdNetlistJson = netlistJson;
      _moduleName = _lastModuleName ?? mod.definitionName;
      try {
        _hierarchyService = NetlistHierarchyAdapter.fromJson(netlistJson);
      } on FormatException {
        _hierarchyService = null;
      }
    });
  }

  /// Step: Run Yosys synthesis → Tab 4 (Synth Schematic).
  void _generateSynthSchematic() {
    final moduleName = _lastModuleName;
    final rtlRes = _lastRtlRes;
    if (moduleName == null || rtlRes == null) {
      return;
    }
    final requestId = ++_synthSchematicRequestId;
    setState(() {
      _synthSchematicLoading = true;
    });
    yosysWorker.postMessage({'module': moduleName, 'verilog': rtlRes});
    unawaited(
      yosysWorker.nextMessage().then((message) {
        if (!mounted || requestId != _synthSchematicRequestId) {
          return;
        }
        setState(() {
          _synthSchematicLoading = false;
          _yosysJson = message;
        });
      }),
    );
  }

  /// Capture FLC trace JSON while `SourceTraceRegistry` data is still live.
  Map<String, Object>? _captureFlcTraceJson() {
    final mod = _lastBuiltModule;
    final moduleName = _lastModuleName;
    if (mod == null || moduleName == null) {
      return null;
    }

    _lastFlcJson = null;
    return null;
  }

  /// Step: Generate FLC trace data → Tab 1 (ROHD Source / cross-probe).
  Future<void> _generateFlcTrace(Configurator component) async {
    final rtlRes = _lastRtlRes;
    final moduleName = _lastModuleName;
    if (rtlRes == null || moduleName == null) {
      return;
    }

    final flcJson = _captureFlcTraceJson();

    await _buildCrossProbeAndHighlight(
      component,
      rtlRes,
      moduleName,
      flcJson: flcJson,
    );
  }

  // ── End generation subroutines ────────────────────────────────────────

  /// Dispatch the content widget for a given logical tab [index].
  Widget _tabContentForIndex(
      int index, double screenHeight, double screenWidth) {
    switch (index) {
      case 0:
        return _rohdSchematicCard(screenHeight, screenWidth);
      case 1:
        return _rohdSourceCard(screenHeight, screenWidth);
      case 2:
        return _generatedRtlCard(screenHeight, screenWidth);
      case 3:
        return _generatedSchCard(screenHeight, screenWidth);
      default:
        return const SizedBox.shrink();
    }
  }

  /// Lazily generate data for a newly-enabled tab using cached module.
  Future<void> _lazyGenerate(int tabIndex) async {
    switch (tabIndex) {
      case 0:
        if (_rohdNetlistJson == null) {
          await _generateRohdSchematic();
        }
      case 1:
        if (_lastFlcJson == null) {
          final component = context.read<ComponentCubit>().state;
          await _generateFlcTrace(component);
        }
        _scheduleSourceFormatRefresh();
      case 3:
        if (_yosysJson == null && !_synthSchematicLoading) {
          _generateSynthSchematic();
        }
      // cases 2 and 3 are generated by _generateBase.
    }
  }

  Widget _genRtlButton(SystemVerilogCubit rtlCubit, Configurator component) =>
      BlocBuilder<SystemVerilogCubit, SystemVerilogCubitState>(
        builder: (context, state) {
          final isLoading = state.generationState == GenerationState.loading;
          return ElevatedButton(
            key: const Key('generateRTL'),
            onPressed: isLoading
                ? null
                : () async {
                    try {
                      rtlCubit.setLoading();

                      // allow some time for loading spinner to appear
                      await Future<void>.delayed(
                        const Duration(milliseconds: 10),
                      );

                      // Validate and save form state.
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                      }

                      // Base: always build the module and generate
                      // SystemVerilog.
                      await _generateBase(component);

                      // Tab 0: ROHD Schematic
                      if (_tabEnabled[0]) {
                        await _generateRohdSchematic();
                      }

                      // Tab 4: Synth Schematic (Yosys)
                      if (_tabEnabled[3]) {
                        _generateSynthSchematic();
                      }

                      // Capture FLC while traces are still live so schematic
                      // source navigation works when the source tab is off.
                      _captureFlcTraceJson();

                      // Tab 1: ROHD Source (FLC/cross-probe)
                      if (_tabEnabled[1]) {
                        await _generateFlcTrace(component);
                      }

                      // allow some time for registration to happen
                      rtlCubit.setLoading();
                      await Future<void>.delayed(
                        const Duration(milliseconds: 200),
                      );

                      rtlCubit.setRTL(
                        _lastRtlRes!,
                        _lastScRes!,
                        component.sanitaryName,
                        _lastModuleName!,
                      );
                      _scheduleSourceFormatRefresh();
                    } on Exception catch (e) {
                      var message = e.toString();
                      if (e is RohdHclException) {
                        message = e.message;
                      }
                      rtlCubit.setRTL(
                        'Error generating:\n\n$message',
                        'Error generating:\n\n$message',
                        'error',
                        '',
                      );
                    }
                  },
            style: btnStyle,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Generate'),
          );
        },
      );

  /// Build [FlcData] from the directly-generated FLC JSON, load the ROHD
  /// source, and populate the ROHD source subtabs.
  Future<void> _buildCrossProbeAndHighlight(
    Configurator component,
    String svText,
    String moduleName, {
    Map<String, Object>? flcJson,
  }) async {
    // Resolve the ROHD source asset path for this component.
    final mod = component.createModule();
    final rawType = mod.runtimeType.toString();
    final typeName = rawType.contains('<')
        ? rawType.substring(0, rawType.indexOf('<'))
        : rawType;
    final primaryAsset = moduleSourceAssets[typeName];
    if (primaryAsset == null) {
      return;
    }

    try {
      final rohdSource =
          await rootBundle.loadString(bundledSourceAssetPath(primaryAsset));
      _lastRohdSource = rohdSource;

      // Build FlcData from the directly-generated hierarchy JSON.
      FlcData flcData;
      if (flcJson != null) {
        flcData = FlcData.fromJson(
          flcJson.cast<String, dynamic>(),
        );
        debugPrint(
          '[FlcData] Built from traced hierarchy '
          '(${flcData.files.length} files, '
          'modules: ${flcData.moduleNames.join(', ')})',
        );
      } else {
        flcData = FlcData.empty();
        debugPrint('[FlcData] No trace data available');
      }

      // Build the set of available rohd_src asset paths from the FLC files.
      final availableAssets = <String>{primaryAsset};
      for (final fp in flcData.files) {
        final asset = _flcFileToAsset(fp);
        if (asset != null && !asset.startsWith('rohd_src/component_config/')) {
          availableAssets.add(asset);
        }
      }

      // Collect distinct ROHD source files for subtabs.
      final sortedFiles = <String>[primaryAsset];
      final others = availableAssets.where((a) => a != primaryAsset).toList()
        ..sort();
      sortedFiles.addAll(others);

      // Reuse existing subtab state if the file list hasn't changed.
      final filesChanged = !_listsEqual(_rohdSourceFiles, sortedFiles) ||
          _rohdSourceTabController == null;
      if (filesChanged) {
        _disposeRohdSubtabs();

        final subtabCtrl = TabController(
          length: sortedFiles.length,
          vsync: this,
        );
        subtabCtrl.addListener(() {
          if (!subtabCtrl.indexIsChanging) {
            _applyPendingRohdSubtabScroll(subtabCtrl.index);
          }
        });

        setState(() {
          _flcData = flcData;
          _flcModuleName = moduleName;
          _rohdSourceFiles = sortedFiles;
          _rohdSourceTabController = subtabCtrl;
          _highlightedSvLine = null;
          _highlightedScLine = null;
          _highlightedRohdLine = null;
        });
      } else {
        setState(() {
          _flcData = flcData;
          _flcModuleName = moduleName;
          _highlightedSvLine = null;
          _highlightedScLine = null;
          _highlightedRohdLine = null;
        });
      }
    } on Exception catch (e) {
      // Non-fatal: cross-probe is optional.
      // ignore: avoid_print
      print('[FlcData] failed to build: $e');
    }
  }

  /// Apply a pending scroll for the ROHD source subtab at [subtabIndex].
  void _applyPendingRohdSubtabScroll(int subtabIndex) {
    if (subtabIndex < 0 || subtabIndex >= _rohdSourceFiles.length) {
      return;
    }
    final file = _rohdSourceFiles[subtabIndex];
    final pending = _rohdFilePendingScrolls[file];
    if (pending == null) {
      return;
    }

    final scrollCtrl = _rohdFileScrollControllers[file];
    final ctrl = _rohdFileControllers[file];
    final highlightLine = _rohdFileHighlightLines[file];

    // Re-apply selection and recompute the scroll offset now that the
    // controller is available (the stored `pending` may be a placeholder 0
    // from when the controller didn't exist yet).
    var effectiveOffset = pending;
    if (ctrl != null && highlightLine != null) {
      effectiveOffset = _setSelectionAndComputeScroll(
            ctrl,
            line: highlightLine,
            scrollController: scrollCtrl,
          ) ??
          pending;
    }

    void attemptScroll(int retries) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollCtrl != null && scrollCtrl.hasClients) {
          _rohdFilePendingScrolls[file] = null;
          scrollCtrl.animateTo(
            effectiveOffset.clamp(0.0, scrollCtrl.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else if (retries > 0) {
          attemptScroll(retries - 1);
        }
      });
    }

    attemptScroll(10);
  }

  /// Dispose all per-file subtab controllers and reset state.
  void _disposeRohdSubtabs() {
    // Capture references to old resources and clear the maps immediately
    // so new widgets won't see stale entries.
    final oldControllers = _rohdFileControllers.values.toList();
    final oldScrollControllers = _rohdFileScrollControllers.values.toList();
    final oldHorizontalScrollControllers =
        _rohdFileHorizontalScrollControllers.values.toList();
    final oldFocusNodes = _rohdFileFocusNodes.values.toList();
    final oldTabController = _rohdSourceTabController;

    _rohdFileControllers.clear();
    _rohdFileScrollControllers.clear();
    _rohdFileHorizontalScrollControllers.clear();
    _rohdFileFocusNodes.clear();
    _rohdFileHighlightLines.clear();
    _rohdFilePendingScrolls.clear();
    _rohdFileFutures.clear();
    _rohdSourceViewFutures.clear();
    _rohdSourceController = null;
    _subtabViewKey = null;
    _rohdSourceTabController = null;

    // Defer actual disposal to after the current frame so the widget tree
    // can cleanly detach from these resources during rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in oldControllers) {
        c.dispose();
      }
      for (final sc in oldScrollControllers) {
        sc.dispose();
      }
      for (final sc in oldHorizontalScrollControllers) {
        sc.dispose();
      }
      for (final fn in oldFocusNodes) {
        fn.dispose();
      }
      oldTabController?.dispose();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _svController?.dispose();
    _scController?.dispose();
    _svFocusNode.dispose();
    _scFocusNode.dispose();
    _rohdSourceFocusNode.dispose();
    _svScrollController.dispose();
    _scScrollController.dispose();
    _rohdSourceScrollController.dispose();
    _configScrollController.dispose();
    _svHorizontalScrollController.dispose();
    _scHorizontalScrollController.dispose();
    // Dispose subtab resources synchronously on final teardown.
    for (final c in _rohdFileControllers.values) {
      c.dispose();
    }
    for (final sc in _rohdFileScrollControllers.values) {
      sc.dispose();
    }
    for (final sc in _rohdFileHorizontalScrollControllers.values) {
      sc.dispose();
    }
    for (final fn in _rohdFileFocusNodes.values) {
      fn.dispose();
    }
    _rohdSourceTabController?.dispose();
    _crossProbeBus.removeListener(_onCrossProbeSignals);
    _crossProbeBus.dispose();
    _sourceFormatClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtlCubit = context.read<SystemVerilogCubit>();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const dividerWidth = 8.0;
        const minimumLeftWidth = 150.0;
        const minimumRightWidth = 300.0;
        const minimumContentWidth =
            minimumLeftWidth + dividerWidth + minimumRightWidth;
        final contentWidth =
            totalWidth < minimumContentWidth ? minimumContentWidth : totalWidth;
        final leftWidth = (contentWidth * _splitFraction).clamp(
          minimumLeftWidth,
          contentWidth - minimumRightWidth - dividerWidth,
        );
        final rightWidth = contentWidth - leftWidth - dividerWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            child: Row(
              children: [
                SizedBox(
                  width: leftWidth,
                  child: BlocBuilder<ComponentCubit, Configurator>(
                    builder: (context, component) => Column(
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(10),
                            child: Card(
                              child: Scrollbar(
                                controller: _configScrollController,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _configScrollController,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Add a title
                                          Text(
                                            component.name,
                                            style: const TextStyle(
                                              fontSize: 25,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          for (final knobEntry
                                              in component.knobs.entries)
                                            _generateKnobControl(
                                              knobEntry.key,
                                              knobEntry.value,
                                            ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _genRtlButton(rtlCubit, component),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                // ---- Draggable vertical divider ----
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _splitFraction =
                          ((_splitFraction * contentWidth + details.delta.dx) /
                                  contentWidth)
                              .clamp(
                        minimumLeftWidth / contentWidth,
                        (contentWidth - minimumRightWidth - dividerWidth) /
                            contentWidth,
                      );
                    });
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: SizedBox(
                      width: dividerWidth,
                      child: Center(
                        child: Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // ---- Right (viewer) pane ----
                SizedBox(
                  width: rightWidth,
                  child: Card(
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      child: Scaffold(
                        appBar: AppBar(
                          title: const Text('Generated Outputs'),
                          actions: [
                            // Tab-visibility checkboxes
                            for (var i = 0; i < _tabLabels.length; i++)
                              Tooltip(
                                message: _tabTooltips[i],
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: () {
                                    if (_tabEnabled[i] &&
                                        _visibleTabs.length == 1) {
                                      return;
                                    }
                                    setState(() {
                                      _tabEnabled[i] = !_tabEnabled[i];
                                      _rebuildTabController(
                                        selectLogical:
                                            _tabEnabled[i] ? i : null,
                                      );
                                    });
                                    // Lazy generation when a tab is enabled.
                                    if (_tabEnabled[i] &&
                                        _lastBuiltModule != null) {
                                      unawaited(_lazyGenerate(i));
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 2, vertical: 4),
                                    child: Opacity(
                                      opacity: _tabEnabled[i] ? 1.0 : 0.35,
                                      child: _tabIconWidget(i),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            BlocBuilder<ThemeCubit, material_ui.ThemeMode>(
                              builder: (context, themeMode) {
                                final isDark =
                                    themeMode == material_ui.ThemeMode.dark;
                                return Tooltip(
                                  message: isDark
                                      ? 'Switch to light theme'
                                      : 'Switch to dark theme',
                                  child: IconButton(
                                    icon: Text(
                                      isDark ? '☀️' : '🌙',
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    onPressed: () {
                                      context.read<ThemeCubit>().toggleTheme();
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                          bottom: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabs: [
                              for (final i in _visibleTabs)
                                Tab(child: _tabLabelWidget(i)),
                            ],
                          ),
                        ),
                        body: IndexedStack(
                          index: _tabController.index,
                          children: [
                            for (final i in _visibleTabs)
                              _tabContentForIndex(i, screenHeight, screenWidth),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ButtonStyle>('btnStyle', btnStyle))
      ..add(
        DiagnosticsProperty<YosysWorker>('yosysWorker', yosysWorker),
      );
  }
}
