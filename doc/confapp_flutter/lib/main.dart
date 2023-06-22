import 'package:confapp_flutter/testingPage.dart';
import 'package:flutter/material.dart';
import 'package:confapp_flutter/hcl_components.dart';
import 'package:confapp_flutter/components/config.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const ROHDHclConfigApp());
}

class ROHDHclConfigApp extends StatelessWidget {
  const ROHDHclConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ROHD-HCL',
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0x00082E8A)),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0x00BED9FF)),
      home: const SVGeneratorPage(title: 'ROHD-HCL'),
    );
  }
}

class SVGeneratorPage extends StatefulWidget {
  const SVGeneratorPage({super.key, required this.title});

  final String title;

  @override
  State<SVGeneratorPage> createState() => _SVGeneratorPageState();
}

class _SVGeneratorPageState extends State<SVGeneratorPage> {
  String svTextGen = 'Generated System Verilog here!';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<Widget> textFormField = [];
  List<Widget> drawerList = [];
  late dynamic rotateGen;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openDrawer() {
    _scaffoldKey.currentState!.openDrawer();
  }

  void _closeDrawer() {
    Navigator.of(context).pop();
  }

  void _generateRTL() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // for (int i = 0; i < rotateGen.knobs.length; i++) {
      //   print(rotateGen.knobs[i].name);
      //   print(rotateGen.knobs[i].value);
      // }
    }
    final res = await rotateGen.generate();

    setState(() {
      svTextGen = res;
    });
  }

  void _selectComponent(componentGenerator) {
    textFormField = [];
    rotateGen = componentGenerator;

    setState(() {
      for (int i = 0; i < rotateGen.knobs.length; i++) {
        final knob = rotateGen.knobs[i];
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
                    rotateGen.knobs[i].value = int.parse(value.toString());
                  } else {
                    rotateGen.knobs[i].value = value ?? '10';
                  }
                }),
          ),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();

    /// Drawer will shows all components
    final components = WebPageGenerator();
    for (int i = 0; i < components.generators.length; i++) {
      drawerList.add(
        ListTile(
          title: TextButton(
            style: TextButton.styleFrom(
              textStyle: const TextStyle(fontSize: 20),
            ),
            onPressed: () => _selectComponent(components.generators[i]),
            child: Text(components.generators[i].componentName),
          ),
        ),
      );
    }

    rotateGen = WebPageGenerator().generators[0];

    for (int i = 0; i < rotateGen.knobs.length; i++) {
      final knob = rotateGen.knobs[i];
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
                  rotateGen.knobs[i].value = int.parse(value.toString());
                } else {
                  rotateGen.knobs[i].value = value ?? '10';
                }
              }),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ButtonStyle btnStyle =
        ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 20));
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: ListView(
          scrollDirection: Axis.vertical,
          children: ListTile.divideTiles(context: context, tiles: drawerList)
              .toList(),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          Row(
            children: [
              SizedBox(
                width: AppBar().preferredSize.height,
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: ((context) => TestPage())));
                },
                icon: const Icon(Icons.home),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: ((context) => TestPage())));
                },
                icon: const Icon(Icons.menu),
              ),
            ],
          )
        ],
      ),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Form
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
      ),
    );
  }
}
