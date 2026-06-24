import 'package:flutter_compass/flutter_compass.dart';
import 'heading_source.dart';

/// Wraps [FlutterCompass.events] as a [HeadingSource].
class CompassHeadingSource implements HeadingSource {
  @override
  Stream<double?> headings() {
    return FlutterCompass.events?.map((event) => event.heading) ??
        Stream<double?>.value(null);
  }
}
