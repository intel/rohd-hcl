import 'package:confapp_flutter/hcl/cubit/component_cubit.dart';
import 'package:confapp_flutter/hcl/cubit/system_verilog_cubit.dart';
import 'package:flutter/material.dart';
import 'package:confapp_flutter/components/config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  late ConfigGenerator component;
  final ButtonStyle btnStyle =
      ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 20));

  Future<String> _generateRTL({bool form = true}) async {
    if (form && _formKey.currentState!.validate()) {
      _formKey.currentState!.save();
    }

    final res = await component.generate();

    return res;
  }

  @override
  Widget build(BuildContext context) {
    final rtlCubit = context.read<SystemVerilogCubit>();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        BlocBuilder<ComponentCubit, ConfigGenerator>(
          builder: (context, state) {
            textFormField = [];
            component = state;

            // Add a title
            textFormField.add(
              Text(
                state.componentName,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );

            for (int i = 0; i < component.knobs.length; i++) {
              final knob = component.knobs[i];
              final knobLabel = knob.name;
              final knobDefaultVal = knob.defaultVal;

              textFormField.add(
                const SizedBox(
                  height: 16,
                ),
              );

              textFormField.add(
                SizedBox(
                  width: 400,
                  child: TextFormField(
                    initialValue: knobDefaultVal.toString(),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: knobLabel,
                    ),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Please enter value';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      if (knob.runtimeType == IntConfigKnob) {
                        component.knobs[i].value = int.parse(value.toString());
                      } else {
                        component.knobs[i].value = value ?? '10';
                      }
                    },
                  ),
                ),
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
                            final rtlRes = await _generateRTL();
                            rtlCubit.setRTL(rtlRes);
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
