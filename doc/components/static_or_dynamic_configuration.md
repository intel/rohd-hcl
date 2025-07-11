# Static or Dynamic Component Configuration

Features of a hardware component may be selectable either at generation time or controllable by a hardware signal.  In the former case, we can statically configure the generator to generate the logic needed to support that feature set by the parameter. In the latter case we would generate the logic for the feature as well as control logic to enable or disable the feature.

An example use of this is in specifying signed operands in ROHD-HCL multipliers where we pass in a parameter during construction:

```dart
dynamic signedMultiplicand,
...
```

Internally, we can convert this dynamic to either a boolean or a Logic depending on what was passed in, and perform the appropriate logic generation for either statically configurating signed-multiplicand operation, or adding the Logic provided as an input for controlling signed-multiplicand operation as a hardware feature.  This will enforce that the parameter is either not provided (null), a boolean, or a `Logic` control signal for the feature.

Inside a component, we can interpret and check the type of the parameter passed in:

```dart
final signedMultiplicandParameter = StaticOrLogicParameter.ofDynamic(signedMultiplicand);
```

We can check if it is a hardware control signal:

```dart
if (signedMultiplicandParameter.dynamicConfig != null)
```

If not dynamically configurable, we can then grab the static boolean:

```dart
final doSignedMultiplicand = signedMultiplicandParameter.staticConfig;
```

Since this is an input parameter with potentially a control `Logic` signal, the signal would have to be added as an input to a module.  The API for `StaticOrDynamicParameter` adds the input and creates a new copy by cloning with the current module as an argument (taking care of ensuring the internal signal of the Module is used) for passing to submodules:

```dart
class MyModule extends Module {
    MyModule({dynamic hardwareFeatureOne}) {
        // Make sure to pass the signal of the current module's added input and
        // not the signal from outside to the submodule.
        final submodule = MySubModule(hardwareFeature.clone(this));
    }
}

final hardwareFeatureOn = Const(1);
final myModule = MyModule(hardwareFeatureOne: hardwareFeatureOn);
```
