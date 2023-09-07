import 'package:confapp_flutter/hcl/cubit/component_cubit.dart';
import 'package:confapp_flutter/hcl/cubit/system_verilog_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:sidebarx/sidebarx.dart';

class SVGenerator extends StatefulWidget {
  final SidebarXController controller;

  const SVGenerator({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State createState() => _SVGeneratorState();
}

class _SVGeneratorState extends State<SVGenerator> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<Widget> textFormField = [];
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

  Widget _generateKnobControl(String label, ConfigKnob knob) {
    final Widget selector;

    final decoration = InputDecoration(
      border: const OutlineInputBorder(),
      labelText: label,
    );
    final key = Key(label);

    if (knob is IntConfigKnob || knob is StringConfigKnob) {
      selector = TextFormField(
        key: key,
        initialValue: knob.value.toString(),
        decoration: decoration,
        validator: (value) {
          if (value!.isEmpty) {
            return 'Please enter value';
          }
          return null;
        },
        inputFormatters: [
          if (knob is IntConfigKnob) FilteringTextInputFormatter.digitsOnly,
          FilteringTextInputFormatter.singleLineFormatter,
        ],
        onSaved: (value) {
          setState(() {
            if (knob is IntConfigKnob) {
              knob.value = int.parse(value.toString());
            } else {
              knob.value = value;
            }
          });
        },
      );
    } else if (knob is ToggleConfigKnob) {
      selector = CheckboxListTile(
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
    } else {
      selector = Text('Unknown knob type for $label: ${knob.runtimeType}');
    }

    return SizedBox(width: 400, child: selector);
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
            textFormField = [];

            // Add a title
            textFormField.add(
              Text(
                component.name,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
            for (var knobEntry in component.knobs.entries) {
              final knob = knobEntry.value;
              final knobLabel = knobEntry.key;

              textFormField.add(
                const SizedBox(
                  height: 16,
                ),
              );

              textFormField.add(
                _generateKnobControl(knobLabel, knob),
              );
            }

            return Container(
              margin: const EdgeInsets.all(10),
              constraints: BoxConstraints(
                maxHeight: screenHeight / 1.2,
                maxWidth: screenWidth / 3,
              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...textFormField,
                        const SizedBox(
                          height: 16,
                        ),
                        ElevatedButton(
                          key: const Key('generateRTL'),
                          onPressed: () async {
                            try {
                              final rtlRes = await _generateRTL(component);
                              rtlCubit.setRTL(rtlRes);
                            } on Exception catch (e) {
                              var message = e.toString();
                              if (e is RohdHclException) {
                                message = e.message;
                              }
                              rtlCubit.setRTL('Error generating:\n\n$message');
                            }
                          },
                          style: btnStyle,
                          child: const Text('Generate RTL'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Card(
          child: Container(
            constraints: BoxConstraints(
                maxHeight: screenHeight / 2, maxWidth: screenWidth / 3),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: BlocBuilder<SystemVerilogCubit, String>(
                  builder: (context, state) {
                    return Column(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: ElevatedButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: state));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Text copied to clipboard')),
                              );
                            },
                            child: const Text('Copy SV'),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SelectableText(
                            state,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'RobotoMono',
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
        ),
      ],
    );
  }
}
