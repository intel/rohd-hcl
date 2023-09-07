import 'package:confapp_flutter/hcl/view/screen/sidebar_widget.dart';
import 'package:flutter/material.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:sidebarx/sidebarx.dart';

import 'screen/content_widget.dart';

class HCLView extends StatelessWidget {
  const HCLView({super.key});

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

  late Configurator component;
  List<Widget> textFormField = []; // shared variable

  final ButtonStyle btnStyle =
      ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 20));

  // Change the input form
  void selectComponent(componentGenerator) {
    textFormField = [];
    component = componentGenerator;

    // setState(() {
    //   for (final knobEntry in component.knobs.entries) {
    //     final knob = knobEntry.value;
    //     final knobLabel = knobEntry.key;

    //     textFormField.add(
    //       const SizedBox(
    //         height: 16,
    //       ),
    //     );

    //     textFormField.add(
    //       SizedBox(
    //         width: 250,
    //         child: TextFormField(
    //             key: Key(knobLabel),
    //             decoration: InputDecoration(
    //               border: const OutlineInputBorder(),
    //               labelText: knobLabel,
    //             ),
    //             validator: (value) {
    //               if (value!.isEmpty) {
    //                 return 'Please enter value';
    //               }
    //               return null;
    //             },
    //             onSaved: (value) {
    //               if (knob is IntConfigKnob) {
    //                 knob.value = int.parse(value.toString());
    //               } else {
    //                 knob.value = value ?? '10';
    //               }
    //             }),
    //       ),
    //     );
    //   }
    // });
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      body: Row(
        children: [
          ComponentsSidebar(
            controller: _controller,
            updateForm: selectComponent,
          ),
          Flexible(
            child: SVGenerator(
              controller: _controller,
            ),
          ),
        ],
      ),
    );
  }
}
