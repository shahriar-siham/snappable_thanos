library snappable_thanos;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'dart:async';

enum PngFilter {
  none,
  sub,
  up,
  average,
  paeth,
}

class Snappable extends StatefulWidget {
  /// Widget to be snapped
  final Widget child;

  /// Direction and range of snap effect
  /// (Where and how far will particles go)
  final Offset offset;

  /// Duration of whole snap animation
  final Duration duration;

  /// Number of layers of images,
  /// The more of them the better effect but the heavier it is for the CPU
  final int numberOfBuckets;

  /// The [pixelRatio] affects the number of dust particles generated during the snap effect:
  /// - A value of `1.0` (default) will generate dust particles equivalent to the number of pixels the image occupies on the screen.
  /// - Values less than `1.0` (recommended) will result in fewer dust particles, reducing the visual density and computational load.
  /// - Values greater than `1.0` will result in more dust particles, increasing the visual density and detail of the effect, but may also increase the computational load.
  /// 
  /// Example usage:
  /// ```dart
  /// Snappable(
  ///   child: myWidget,
  ///   pixelRatio: 0.25,
  ///   onSnapped: () {
  ///     // Do something after snap
  ///   },
  /// )
  /// ```
  final double pixelRatio;

  /// Determines the appearance of the dust particles.
  /// If true, the particles will have a pixelated look (default).
  /// If false, the particles will appear smoother and blurry.
  final bool pixelatedDust;

  /// How much can particles be randomized,
  /// For example if [offset] is (100, 100) and [randomDislocationOffset] is (10,10),
  /// Each layer can be moved to a maximum between 90 and 110.
  final Offset randomDislocationOffset;

  /// Specifies the compression level to be used when encoding the PNG image layers.
  /// 
  /// The compression level can range from 0 to 9:
  /// - `0`: No compression (default). This is the fastest option and is suitable when encoding time is a priority.
  /// - `1` to `9`: Increasing levels of compression. Higher values will result in smaller file sizes but take longer to encode.
  /// 
  /// The default value is `0` to minimize encoding time and ensure that the snapping effect performs efficiently.
  /// Adjust this value based on your specific needs for file size and encoding speed.
  /// 
  /// Example usage:
  /// ```dart
  /// Snappable(
  ///   child: myWidget,
  ///   pngLevel: 6,
  ///   onSnapped: () {
  ///     // Do something after snap
  ///   },
  /// )
  /// ```
  /// 
  /// Higher compression levels (closer to 9) provide better compression at the cost of slower performance.
  /// Choose a compression level that balances your requirements for speed and file size.
  final int pngLevel;

  /// Specifies the PNG filter type to be used when encoding the image layers.
  /// 
  /// The available options are:
  /// - [PngFilter.none]: No filtering (default). This is the fastest option and reduces encoding time.
  /// - [PngFilter.sub]: Subtracts the value of the pixel to the left. Slightly increases encoding time compared to no filter.
  /// - [PngFilter.up]: Subtracts the value of the pixel above. Similar in performance to the Sub filter.
  /// - [PngFilter.average]: Uses the average of the pixel to the left and the pixel above. Moderately increases encoding time.
  /// - [PngFilter.paeth]: Uses the Paeth filter, which predicts the value of a pixel based on the neighbouring pixels. This is the most time-consuming option.
  /// 
  /// Example usage:
  /// ```dart
  /// Snappable(
  ///   child: myWidget,
  ///   pngFilter: PngFilter.paeth,
  ///   onSnapped: () {
  ///     // Do something after snap
  ///   },
  /// )
  /// ```
  /// 
  /// Using a filter can affect the compression and quality of the generated PNG.
  /// Choose a filter type based on your specific needs for quality, performance, and encoding time.
  final PngFilter pngFilter;

  /// By adjusting the [skipPixels] value, you can control the density of the dust particles:
  /// - A value of `0` means no pixels are skipped, resulting in the maximum density of dust particles.
  /// - Increasing the value will reduce the number of dust particles by skipping the specified number of pixels, which can improve performance.
  /// For example, if the value is `1`, the dust particles will be generated from every other pixel.
  final int skipPixels;

  /// Quick helper to snap widgets when touched
  /// If true, wraps the widget in [GestureDetector] and starts [snap] when tapped
  /// Defaults to false
  final bool snapOnTap;

  /// Function that gets called when snap ends
  final VoidCallback? onSnapped;

  const Snappable({
    Key? key,
    required this.child,
    this.offset = const Offset(64, -32),
    this.duration = const Duration(milliseconds: 5000),    
    this.numberOfBuckets = 16,
    this.pixelRatio = 1.0,
    this.pixelatedDust = true,
    this.randomDislocationOffset = const Offset(64, 32),
    this.pngLevel = 0,
    this.pngFilter = PngFilter.none,
    this.skipPixels = 0,
    this.snapOnTap = false,
    this.onSnapped,
  }) : super(key: key);

  @override
  SnappableState createState() => SnappableState();
}

class SnappableState extends State<Snappable> with SingleTickerProviderStateMixin {
  static const double _singleLayerAnimationLength = 0.6;
  static const double _lastLayerAnimationStart = 1 - _singleLayerAnimationLength;

  bool get isGone => _animationController.isCompleted;
  bool get isInProgress => _animationController.isAnimating;

  /// Main snap effect controller
  late AnimationController _animationController;

  /// Key to get image of a [widget.child]
  final GlobalKey _globalKey = GlobalKey();

  /// Layers of image
  List<Uint8List> _layers = [];

  /// Values from -1 to 1 to dislocate the layers a bit
  late List<double> _randoms;

  /// Size of child widget
  late Size size;

  /// Completer to track the preparation status
  Completer<void>? _preparationCompleter;
  
  bool _isPrepared = false;
  bool _hasSnapStarted = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onSnapped?.call();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.snapOnTap ? () => isGone ? reset() : snap() : null,
      child: Stack(
        children: <Widget>[
          if (_hasSnapStarted &&_layers.isNotEmpty) ..._layers.map(_imageToWidget),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return _animationController.isDismissed ? child! : Container();
            },
            child: RepaintBoundary(
              key: _globalKey,
              child: widget.child,
            ),
          )
        ],
      ),
    );
  }

  // Function to map PngFilter to img.PngFilter
  img.PngFilter _mapPngFilter(PngFilter filter) {
    switch (filter) {
      case PngFilter.sub:
        return img.PngFilter.sub;
      case PngFilter.up:
        return img.PngFilter.up;
      case PngFilter.average:
        return img.PngFilter.average;
      case PngFilter.paeth:
        return img.PngFilter.paeth;
      case PngFilter.none:
      default:
        return img.PngFilter.none;
    }
  }

  /// I am... INEVITABLE      ~Thanos
  Future<void> prepareSnap() async {
    if (_preparationCompleter != null) {
      // If preparation is already in progress, wait for it to complete
      await _preparationCompleter!.future;
      return;
    }

    _preparationCompleter = Completer<void>();

    try {
      // Get image from child
      final fullImage = await _getImageFromWidget();

      // Create an image for every bucket
      List<img.Image> images = List<img.Image>.generate(
        widget.numberOfBuckets,
        (i) => img.Image(width: fullImage.width, height: fullImage.height, numChannels: 4),
      );

      // For every line of pixels, skipping defined number of pixels (lines)
      for (int y = 0; y < fullImage.height; y += widget.skipPixels + 1) {
        // Generate weight list of probabilities determining
        // to which bucket should given pixels go
        List<int> weights = List.generate(
          widget.numberOfBuckets,
          (bucket) => _gauss(
            y / fullImage.height,
            bucket / widget.numberOfBuckets,
          ),
        );
        int sumOfWeights = weights.fold(0, (sum, el) => sum + el);

        // For every pixel in a line, skipping defined number of pixels
        for (int x = 0; x < fullImage.width; x += widget.skipPixels + 1) {
          // Get the pixel from fullImage
          var pixel = fullImage.getPixel(x, y);
          // Choose a bucket for a pixel
          int imageIndex = _pickABucket(weights, sumOfWeights);
          // Set the pixel from chosen bucket
          images[imageIndex].setPixel(x, y, pixel);
        }
      }

      // Compute allows us to run _encodeImages in separate isolate
      // as it's too slow to work on the main thread
      _layers = await compute(_encodeImages, [images, widget.pngLevel, _mapPngFilter(widget.pngFilter)]);

      // Prepare random dislocations and set state
      setState(() {
        _randoms = List.generate(
          widget.numberOfBuckets,
          (i) => (math.Random().nextDouble() - 0.5) * 2,
        );
        _isPrepared = true;
      });

      // Give a short delay to draw images
      await Future.delayed(const Duration(milliseconds: 10));
    } finally {
      _preparationCompleter?.complete();
      _preparationCompleter = null;
    }
  }

  Future<void> snap() async {
    if (!_isPrepared) {
      await prepareSnap();
    }
    setState(() {
      _hasSnapStarted = true;
    });

    // Add a 10-millisecond delay before the snap animation starts
    await Future.delayed(const Duration(milliseconds: 10));
    
    // Start the snap animation
    _animationController.forward();
  }

  /// I am... IRON MAN   ~Tony Stark
  void reset() {
    setState(() {
      _layers = [];
      _animationController.reset();
      _isPrepared = false;
      _hasSnapStarted = false;
    });
  }

  Widget _imageToWidget(Uint8List layer) {
    // Get layer's index in the list
    int index = _layers.indexOf(layer);

    // Based on index, calculate when this layer should start and end
    double animationStart = (index / _layers.length) * _lastLayerAnimationStart;
    double animationEnd = animationStart + _singleLayerAnimationLength;

    // Create interval animation using only part of whole animation
    CurvedAnimation animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        animationStart,
        animationEnd,
        curve: Curves.easeOut,
      ),
    );

    Offset randomOffset = widget.randomDislocationOffset.scale(
      _randoms[index],
      _randoms[index],
    );

    Animation<Offset> offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: widget.offset + randomOffset,
    ).animate(animation);

    return AnimatedBuilder(
    animation: _animationController,
    child: Image.memory(
      layer,
      scale: widget.pixelRatio,
      filterQuality: widget.pixelatedDust ? FilterQuality.none : FilterQuality.low,
    ),
    builder: (context, child) {
      return Transform.translate(
        offset: offsetAnimation.value,
        child: Opacity(
          opacity: math.cos(animation.value * math.pi / 2),
          child: child,
          ),
        );
      },
    );
  }

  /// Returns index of a randomly chosen bucket
  int _pickABucket(List<int> weights, int sumOfWeights) {
    int rnd = math.Random().nextInt(sumOfWeights);
    for (int i = 0; i < weights.length; i++) {
      if (rnd < weights[i]) {
        return i;
      }
      rnd -= weights[i];
    }
    return 0; // default bucket
  }

  /// Gets an Image from a [child] and caches [size] for later us
  Future<img.Image> _getImageFromWidget() async {
    RenderRepaintBoundary? boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return img.Image(width: 0, height: 0);
    // Cache image for later
    size = boundary.size;
    var uiImage = await boundary.toImage(pixelRatio: widget.pixelRatio);
    ByteData? byteData = await uiImage.toByteData(format: ImageByteFormat.png);
    var pngBytes = byteData?.buffer.asUint8List();

    return img.decodePng(pngBytes!)!;
  }

  int _gauss(double center, double value) => (1000 * math.exp(-(math.pow((value - center), 2) / 0.14))).round();
}

/// This is slow! Run it in separate isolate
List<Uint8List> _encodeImages(List<dynamic> params) {
  List<img.Image> images = params[0];
  int level = params[1];
  img.PngFilter filter = params[2];
  
  return images.map((image) => Uint8List.fromList(img.encodePng(image, level: level, filter: filter))).toList();
}
