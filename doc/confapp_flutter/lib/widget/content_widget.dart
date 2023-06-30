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
  List<Widget> drawerList = [];
  late ConfigGenerator component;
  final _controller = SidebarXController(selectedIndex: 0, extended: true);
  final ButtonStyle btnStyle =
      ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 20));
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _generateRTL() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
    }
    final res = await component.generate();

    if (mounted) {
      setState(() {
        svTextGen = res;
      });
    }
  }

  void initState() {
    super.initState();

    component = WebPageGenerator().generators[0];
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
                border: OutlineInputBorder(),
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
              }),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // Form
        Center(
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
                          fontSize: 18,
                        ),
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
