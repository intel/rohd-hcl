import 'package:confapp_flutter/testingPage.dart';
import 'package:flutter/material.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:confapp_flutter/hcl_components.dart';
import 'package:confapp_flutter/components/config.dart';

class ComponentsSidebar extends StatefulWidget {
  final Function(void) updateForm;

  const ComponentsSidebar({
    Key? key,
    required SidebarXController controller,
    required this.updateForm,
  })  : _controller = controller,
        super(key: key);

  final SidebarXController _controller;

  @override
  State<ComponentsSidebar> createState() => _ComponentsSidebarState();
}

class _ComponentsSidebarState extends State<ComponentsSidebar> {
  List<SidebarXItem> componentsList = [];

  late ConfigGenerator component;

  @override
  void initState() {
    super.initState();

    final components = WebPageGenerator();
    for (int i = 0; i < components.generators.length; i++) {
      componentsList.add(
        SidebarXItem(
          iconWidget: const FlutterLogo(size: 20),
          label: components.generators[i].componentName,
          onTap: () => widget.updateForm(components.generators[i]),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> drawerList = [];

    final components = WebPageGenerator();
    for (int i = 0; i < components.generators.length; i++) {
      drawerList.add(
        ListTile(
          title: TextButton(
            style: TextButton.styleFrom(
              textStyle: const TextStyle(fontSize: 20),
            ),
            onPressed: () => widget.updateForm(components.generators[i]),
            child: Text(components.generators[i].componentName),
          ),
        ),
      );
    }

    return SidebarX(
      controller: widget._controller,
      theme: SidebarXTheme(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: canvasColor,
          borderRadius: BorderRadius.circular(20),
        ),
        hoverColor: scaffoldBackgroundColor,
        textStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        selectedTextStyle: const TextStyle(color: Colors.white),
        itemTextPadding: const EdgeInsets.only(left: 30),
        selectedItemTextPadding: const EdgeInsets.only(left: 30),
        itemDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: canvasColor),
        ),
        selectedItemDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: actionColor.withOpacity(0.37),
          ),
          gradient: const LinearGradient(
            colors: [accentCanvasColor, canvasColor],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 30,
            )
          ],
        ),
        iconTheme: IconThemeData(
          color: Colors.white.withOpacity(0.7),
          size: 20,
        ),
        selectedIconTheme: const IconThemeData(
          color: Colors.white,
          size: 20,
        ),
      ),
      extendedTheme: const SidebarXTheme(
        width: 200,
        decoration: BoxDecoration(
          color: canvasColor,
        ),
      ),
      footerDivider: divider,
      headerBuilder: (context, extended) {
        return SizedBox(
          height: 100,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Image.asset('assets/images/avatar.png'),
          ),
        );
      },
      items: componentsList,
    );
  }
}
