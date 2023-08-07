import 'package:flutter/material.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:confapp_flutter/components/config.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:confapp_flutter/hcl/cubit/component_cubit.dart';

const primaryColor = Color.fromARGB(255, 160, 153, 240);
const canvasColor = Color(0xFF2E2E48);
const scaffoldBackgroundColor = Color(0xFF464667);
const accentCanvasColor = Color(0xFF3E3E61);
const white = Colors.white;
final actionColor = const Color(0xFF5F5FA7).withOpacity(0.6);
final divider = Divider(color: white.withOpacity(0.3), height: 1);

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
  Widget build(BuildContext context) {
    final comCubit = context.read<ComponentCubit>();

    for (int i = 0; i < ComponentCubit.generator.components.length; i++) {
      componentsList.add(
        SidebarXItem(
          // iconWidget: const FlutterLogo(size: 20),
          icon: Icons.memory, // The package force to have icon...
          label: ComponentCubit.generator.components[i].componentName,
          onTap: () {
            comCubit
                .setSelectedComponent(ComponentCubit.generator.components[i]);
          },
        ),
      );
    }

    return BlocBuilder<ComponentCubit, ConfigGenerator>(
      builder: (context, state) {
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
            return const SizedBox(
              height: 100,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                    child: Text(
                  'ROHD-HCL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                )),
              ),
            );
          },
          items: componentsList,
        );
      },
    );
  }
}
