import 'package:confapp_flutter/testingPage.dart';
import 'package:flutter/material.dart';
import 'generateRTL.dart';
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
      ),
      home: const SVGeneratorPage(title: 'ROHD-HCL'),
    );
  }
}

// My Widget
class SVGeneratorPage extends StatefulWidget {
  const SVGeneratorPage({super.key, required this.title});

  final String title;

  @override
  State<SVGeneratorPage> createState() => _SVGeneratorPageState();
}

class _SVGeneratorPageState extends State<SVGeneratorPage> {
  String svTextGen = 'Generated System Verilog here!';
  String _rotateAmount = '22';
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  void _generateRTL() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      print(_rotateAmount);
    }
    final res = await RotateGenerator().generate();
    setState(() {
      svTextGen = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ButtonStyle btnStyle =
        ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 20));
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
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
                      children: <Widget>[
                        SizedBox(
                          width: 250,
                          child: TextFormField(
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'rotate amount',
                              ),
                              validator: (value) {
                                if (value!.isEmpty) {
                                  return 'Please enter value';
                                }
                                return null;
                              },
                              onSaved: (value) {
                                _rotateAmount = value ?? '10';
                              }),
                        ),
                        SizedBox(
                          height: 16,
                        ),
                        SizedBox(
                          width: 250,
                          child: TextFormField(
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'rotate amount',
                              ),
                              validator: (value) {
                                if (value!.isEmpty) {
                                  return 'Please enter value';
                                }
                                return null;
                              },
                              onSaved: (value) {
                                _rotateAmount = value ?? '10';
                              }),
                        ),
                        SizedBox(
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
                                SnackBar(
                                    content: Text('Text copied to clipboard')),
                              );
                            },
                            child: Text('Copy Text'),
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
