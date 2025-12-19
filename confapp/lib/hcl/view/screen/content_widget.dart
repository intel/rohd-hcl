// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// content_widget.dart
// Implementation of the widget for viewing the main content
//
// 2023 December

import 'dart:convert';

// need this for creating a download link
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html';
import 'dart:ui_web' as ui_web;

import 'package:confapp/hcl/cubit/component_cubit.dart';
import 'package:confapp/hcl/cubit/system_verilog_cubit.dart';
import 'package:confapp/hcl/view/screen/schematic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:sidebarx/sidebarx.dart';

class SVGenerator extends StatefulWidget {
  final SidebarXController controller;

  const SVGenerator({
    super.key,
    required this.controller,
  });

  @override
  State createState() => _SVGeneratorState();
}

class _SVGeneratorState extends State<SVGenerator> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ButtonStyle btnStyle =
      ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 20));

  @override
  void initState() {
    super.initState();
  }

  Future<String> _generateRTL(Configurator component,
      {bool form = true}) async {
    if (form && _formKey.currentState!.validate()) {
      _formKey.currentState!.save();
    }

    final res = await component.generateSV();

    return res;
  }

  final yosysWorker = Worker('yosysWorker.js');
  var schematicHTML = "";

  Widget _generateKnobControl(String label, ConfigKnob knob) {
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
        inputFormatters: [
          FilteringTextInputFormatter.singleLineFormatter,
        ],
        onChanged: (value) {
          setState(() {
            if (value.isEmpty) {
              return;
            }

            knob.setValueFromString(value);
          });
        },
      );
    } else if (knob is ToggleConfigKnob) {
      selector = CheckboxListTile(
        key: key,
        value: knob.value,
        onChanged: (value) {
          setState(() {
            knob.value = value ?? knob.value;
          });
        },
        secondary: Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
      );
    } else if (knob is ChoiceConfigKnob) {
      selector = DropdownButtonFormField(
        key: key,
        decoration: decoration,
        items: knob.choices
            .map((choice) => DropdownMenuItem(
                  value: choice,
                  child: Text(choice.toString().split('.').last),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            knob.value = value ?? knob.value;
          });
        },
        value: knob.value,
      );
    } else if (knob is ListOfKnobsKnob) {
      selector = _containerOfKnobs(title: knob.name, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Add or remove: '),
            IconButton(
                onPressed: () {
                  setState(() {
                    knob.value += 1;
                  });
                },
                icon: const Icon(Icons.add)),
            IconButton(
                onPressed: () {
                  setState(() {
                    if (knob.value == 0) return;
                    knob.value -= 1;
                  });
                },
                icon: const Icon(Icons.remove)),
          ],
        ),
        for (final (index, subKnob) in knob.knobs.indexed)
          _generateKnobControl('$index', subKnob),
      ]);
    } else if (knob is GroupOfKnobs) {
      selector = _containerOfKnobs(title: knob.name, children: [
        for (final subKnobEntry in knob.subKnobs.entries)
          _generateKnobControl(subKnobEntry.key, subKnobEntry.value),
      ]);
    } else {
      selector = Text('Unknown knob type for $label: ${knob.runtimeType}');
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: selector,
    );
  }

  Widget _containerOfKnobs(
      {required List<Widget> children, required String title}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: title,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.0),
        child: Column(children: children),
      ),
    );
  }

  Widget _generateJsonCard(
    double screenHeight,
    double screenWidth,
  ) {
    return Card(
      child: Container(
        constraints: BoxConstraints(
            maxHeight: screenHeight * 0.8, maxWidth: screenWidth / 3),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: BlocBuilder<ComponentCubit, Configurator>(
                builder: (context, component) {
              final jsonCode = component.toJson(pretty: true);
              return Column(
                children: [
                  _copyAndDownloadButtons(
                      isLoading: false,
                      code: jsonCode,
                      fileName: '${component.name}.config.json'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      jsonCode,
                      style: GoogleFonts.robotoMono(
                        fontSize: 12,
                      ),
                    ),
                  )
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _copyAndDownloadButtons(
      {required bool isLoading,
      required String code,
      required String fileName,
      int maxChars = 10000}) {
    final tooBig = code.length > maxChars;

    return Align(
        alignment: Alignment.topRight,
        child: isLoading
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  ElevatedButton(
                    onPressed: tooBig
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Text copied to clipboard')),
                            );
                          },
                    child: tooBig
                        ? const Text('Copy (too large)')
                        : const Text('Copy'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final bytes = base64Encode(code.codeUnits);
                      final uri = 'data:application/octet-stream;base64,$bytes';
                      AnchorElement(href: uri)
                        ..setAttribute('download', fileName)
                        ..click();
                    },
                    child: const Text('Download'),
                  ),
                ])));
  }

  Widget _generatedRtlCard(double screenHeight, double screenWidth) {
    return Card(
      child: Container(
        constraints: BoxConstraints(
            maxHeight: screenHeight * 0.8, maxWidth: screenWidth / 3),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: BlocBuilder<SystemVerilogCubit, SystemVerilogCubitState>(
              builder: (context, state) {
                final svCode = state.systemVerilog;
                const maxChars = 10000;
                final tooBig = svCode.length > maxChars;
                return Column(
                  children: [
                    if (state.generationState != GenerationState.initial)
                      _copyAndDownloadButtons(
                          isLoading:
                              state.generationState == GenerationState.loading,
                          code: svCode,
                          fileName: '${state.name}.sv'),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        tooBig
                            ? '${svCode.substring(0, maxChars)}'
                                '\n...too long to show'
                            : svCode,
                        style: GoogleFonts.robotoMono(
                          fontSize: 12,
                        ),
                      ),
                    )
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _generatedSchCard(double screenHeight, double screenWidth) {
    return Card(
        child: Container(
            alignment: Alignment.center,
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: BlocBuilder<SystemVerilogCubit, SystemVerilogCubitState>(
                    builder: (context, state) {
                  if (state.generationState == GenerationState.done) {
                    return const Card(
                        child: HtmlElementView(
                      viewType: 'schematic-html',
                    ));
                  } else {
                    return const Padding(padding: EdgeInsets.all(16.0));
                  }
                }))));
  }

  Widget _genRtlButton(SystemVerilogCubit rtlCubit, Configurator component) {
    return ElevatedButton(
      key: const Key('generateRTL'),
      onPressed: () async {
        try {
          rtlCubit.setLoading();

          // allow some time for loading spinner to appear
          await Future.delayed(const Duration(milliseconds: 10));

          final rtlRes = await _generateRTL(component);
          final moduleName = component.createModule().definitionName;

          yosysWorker.postMessage({'module': moduleName, 'verilog': rtlRes});

          yosysWorker.onMessage.first.then((msg) {
            schematicHTML = d3Schematic(msg.data);
            ui_web.platformViewRegistry.registerViewFactory(
                'schematic-html',
                (int viewID) => IFrameElement()
                  ..height = '100%'
                  ..width = '100%'
                  ..srcdoc = schematicHTML
                  ..style.border = 'none');
          });

          // allow some time for registration to happen
          rtlCubit.setLoading();
          await Future.delayed(const Duration(milliseconds: 200));

          rtlCubit.setRTL(rtlRes, component.sanitaryName, moduleName);
        } on Exception catch (e) {
          var message = e.toString();
          if (e is RohdHclException) {
            message = e.message;
          }
          rtlCubit.setRTL('Error generating:\n\n$message', 'error', '');
        }
      },
      style: btnStyle,
      child: const Text('Generate RTL'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rtlCubit = context.read<SystemVerilogCubit>();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        BlocBuilder<ComponentCubit, Configurator>(
            builder: (context, component) {
          return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              margin: const EdgeInsets.all(10),
              constraints: BoxConstraints(
                maxHeight: screenHeight * 0.8,
                maxWidth: screenWidth / 3,
              ),
              child: Card(
                child: SingleChildScrollView(
                    child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                        for (var knobEntry in component.knobs.entries)
                          _generateKnobControl(knobEntry.key, knobEntry.value),
                        const SizedBox(
                          height: 16,
                        ),
                      ],
                    ),
                  ),
                )),
              ),
            ),
            _genRtlButton(rtlCubit, component),
          ]);
        }),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
                child: Container(
                    constraints: BoxConstraints(
                        maxHeight: screenHeight * 0.85,
                        maxWidth: screenWidth / 3),
                    child: DefaultTabController(
                      length: 3,
                      child: Scaffold(
                        appBar: AppBar(
                          title: const Text('Generated Outputs'),
                          bottom: const TabBar(
                            isScrollable: false,
                            tabs: [
                              Tab(text: 'Generated RTL'),
                              Tab(text: 'Generated Schematic'),
                              Tab(text: 'JSON Configuration'),
                            ],
                          ),
                        ),
                        body: TabBarView(
                          children: [
                            _generatedRtlCard(screenHeight, screenWidth),
                            _generatedSchCard(screenHeight, screenWidth),
                            _generateJsonCard(screenHeight, screenWidth),
                          ],
                        ),
                      ),
                    ))),
          ],
        ),
      ],
    );
  }
}
