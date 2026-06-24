/// Supplies device facing-direction updates during navigation.
abstract class HeadingSource {
  /// Stream of heading in degrees `[0, 360)`, or null if momentarily
  /// unavailable.
  Stream<double?> headings();
}
