import 'package:confapp_flutter/testingPage.dart';
import 'package:confapp_flutter/widget/sidebar_widget.dart';
import 'package:flutter/material.dart';
import 'package:confapp_flutter/hcl_components.dart';
import 'package:confapp_flutter/components/config.dart';
import 'package:flutter/services.dart';
import 'package:sidebarx/sidebarx.dart';
import './widget/content_widget.dart';

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
      home: const MainPage(title: 'ROHD-HCL'),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key, required this.title});

  final String title;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _controller = SidebarXController(selectedIndex: 0, extended: true);
  List<Widget> drawerList = [];
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late ConfigGenerator component;
  List<Widget> textFormField = []; // shared variable
  String svTextGen = 'Generated System Verilog here!';

  final ButtonStyle btnStyle =
      ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 20));

  // Change the input form
  void selectComponent(componentGenerator) {
    textFormField = [];
    component = componentGenerator;

    setState(() {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: _scaffoldKey,
      // drawer: ComponentsSidebar(controller: _controller),
      // appBar: AppBar(
      //   backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      //   title: Text(widget.title),
      //   actions: [
      //     Row(
      //       children: [
      //         SizedBox(
      //           width: AppBar().preferredSize.height,
      //         ),
      //         IconButton(
      //           onPressed: () {
      //             Navigator.push(
      //                 context,
      //                 MaterialPageRoute(
      //                     builder: ((context) => SidebarXExampleApp())));
      //           },
      //           icon: const Icon(Icons.home),
      //         ),
      //         IconButton(
      //           onPressed: () {
      //             Navigator.push(
      //                 context,
      //                 MaterialPageRoute(
      //                     builder: ((context) => SidebarXExampleApp())));
      //           },
      //           icon: const Icon(Icons.menu),
      //         ),
      //       ],
      //     )
      //   ],
      // ),
      body: Row(
        children: [
          // Sidebar
          if (!isSmallScreen)
            ComponentsSidebar(
                controller: _controller, updateForm: selectComponent),
          Expanded(
            child: Center(
              child: SVGenerator(
                controller: _controller,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
