import 'dart:ui';

import 'package:confapp_flutter/models/component.dart';
import 'package:flutter/material.dart';
import 'package:confapp_flutter/components/config.dart';
import 'package:flutter/services.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:confapp_flutter/hcl_components.dart';
import 'package:provider/provider.dart';

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
  String svTextGen = 'Generated System Verilog here!';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<Widget> textFormField = [];
  late ConfigGenerator component;
  final ButtonStyle btnStyle =
      ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 20));

  void _generateRTL({bool form = true}) async {
    if (form && _formKey.currentState!.validate()) {
      _formKey.currentState!.save();
    }
    final res = await component.generate();

    setState(() {
      svTextGen = res;
    });
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final componentModel =
          Provider.of<ComponentModel>(context, listen: false);
      component = componentModel.currComponent;
      _generateRTL(form: false);
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Form
        Consumer<ComponentModel>(
          builder: (context, componentsModel, child) {
            textFormField = [];
            component = componentsModel.currComponent;
            for (int i = 0; i < component.knobs.length; i++) {
              final knob = component.knobs[i];
              final knobLabel = knob.name;

              textFormField.add(
                const SizedBox(
                  height: 16,
                ),
              );

              textFormField.add(
                SizedBox(
                  width: 250,
                  child: TextFormField(
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
                          component.knobs[i].value =
                              int.parse(value.toString());
                        } else {
                          component.knobs[i].value = value ?? '10';
                        }
                      }),
                ),
              );
            }

            return Center(
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
                          onPressed: _generateRTL,
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
        // SV output
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Container(
              constraints: BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: ElevatedButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: svTextGen));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Text copied to clipboard')),
                            );
                          },
                          child: const Text('Copy SV'),
                        ),
                      ),
                      SelectableText(
                        svTextGen,
                        style: const TextStyle(
                            fontSize: 12, fontFamily: 'RobotoMono'),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
