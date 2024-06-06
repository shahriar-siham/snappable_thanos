<img src="https://em-content.zobj.net/source/microsoft-teams/363/hand-with-index-finger-and-thumb-crossed_1faf0.png" alt="Logo" width="100" height="100">

# <img src="https://storage.googleapis.com/cms-storage-bucket/0dbfcc7a59cd1cf16282.png" alt="Flutter Logo" height="24"> snappable_thanos

A Flutter library that allows you to add the iconic "snap" effect from Thanos to any widget in your Flutter app. With simple integration and various customization options, you can animate widgets disappearing and reappearing with ease.

 #### <img src="https://em-content.zobj.net/source/microsoft-teams/363/star_2b50.png" alt="New" style="height: 1em;"> What's New

- **Updated for `image 4.2.0`**
- Achieved faster performance by replacing the previous slow PNG encoding algorithm.
- Introduced `prepareSnap()` method to perform calculations beforehand for instant snapping.
- Added `pixelRatio` and `skipPixel` parameters to further enhance performance and offer stylistic options (see details below).<br><br><br>

![Example 1](https://user-images.githubusercontent.com/16286046/62490322-51313680-b7c9-11e9-91f2-1363c292f544.gif)
![Example 2](https://user-images.githubusercontent.com/16286046/62490326-52626380-b7c9-11e9-9ed3-5545e3175cb6.gif)
![Example 3](https://user-images.githubusercontent.com/16286046/62490340-5bebcb80-b7c9-11e9-8bcf-e94c18f25f1b.gif)

<br><br><br>
# Installing

1. Add this to your `pubspec.yaml`

```yaml
dependencies:
  snappable_thanos:
    git:
      url: https://github.com/shahriar-siham/snappable_thanos.git
      ref: main
```
2. Now in your Dart code, you can use the following to import:

```dart
import 'package:snappable_thanos/snappable_thanos.dart';
```

<br><br><br>
# Syntax

First, wrap any widget with `Snappable`.

```dart
@override
Widget build(BuildContext context) {
  return Snappable(
    child: Text('This will be snapped'),
  );
}
```

Then give it a `GlobalKey` of the type `SnappableState`. 

```dart

class MyWidget extends StatelessWidget {
  final key = GlobalKey<SnappableState>();

  @override
  Widget build(BuildContext context) {
    return Snappable(
      key: key,
      child: Text('This will be snapped'),
    );
  }
}
```

To snap this widget, simply use:

```dart
key.currentState!.snap();
```

To undo the snap, use the following:

```dart
key.currentState!.reset();
```

<br><br><br>
# Additional Syntax

## Preloading 

Sometimes, you may want to preload the snapping algorithm before the snapping animation begins. This is useful, for example, when showing a dialog to the user to confirm the snap. Preloading reduces the waiting period significantly. To do this, use:

```dart
key.currentState!.prepareSnap();
```

> **NOTE:** Using `prepareSnap()` is optional. You can skip the preparation and use `snap()` directly.

<br><br>
## Snap on Tap

You may want to snap a widget by just tapping on it. For this, set the `snapOntap` to `true`.

```dart

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Snappable(
      snapOntap: true,
      child: Text('This will be snapped'),
    );
  }
}
```
 Undo by tapping again.

 <br><br>
 ## Optional Callback For When The Snap Ends
 
 ```dart
 
 class MyWidget extends StatelessWidget {
   @override
   Widget build(BuildContext context) {
     return Snappable(
       onSnapped: () => print("Snapped!"),
       child: Text('This will be snapped'),
     );
   }
 }
 ```

<br><br><br>
# Customization

## Number of Layers

The algorithm works by converting any widget into an image, randomly selecting pixels, and assigning them to different layers, called buckets. These buckets are then animated in random directions. The effect looks impressive when there are more buckets, but be sure to balance visual quality with performance.

<br><br>
## Number of Particles

You can customize the number of dust particles with the `pixelRatio` parameter. Fewer particles result in larger sizes and faster rendering. **The default value is `1.0`, but using a value less than that is recommended.**

You may want to reduce the number of particles while keeping their size the same. For this, the `skipPixels` parameter is introduced. Setting it to `1` will skip every other pixel, effectively reducing the pixel count by half.

<br><br>
## Appearance of Particles

The `pixelatedDust` parameter determines the appearance of the dust particles. If `true`, the particles will have a pixelated look (default). If `false`, the particles will appear smoother and blurry. The effect is more noticeable when the `pixelRatio` is less than `1.0`.

