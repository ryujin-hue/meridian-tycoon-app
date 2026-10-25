/// RNG berbenih (mulberry32) — semua rawak game deterministik.
/// Seed disimpan dalam save supaya hasil boleh diulang.
library;

class SeededRng {
  int _s;
  SeededRng(int seed) : _s = seed & 0xFFFFFFFF;

  /// Hash FNV-1a untuk seed daripada string (cth. id syarikat).
  static int hashString(String s) {
    var h = 0x811c9dc5;
    for (var i = 0; i < s.length; i++) {
      h ^= s.codeUnitAt(i);
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  /// [0, 2^32)
  int nextUint32() {
    _s = (_s + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _s;
    t = (t ^ (t >> 16)) & 0xFFFFFFFF;
    t = (t * 0x7FEB352D) & 0xFFFFFFFF;
    t = (t ^ (t >> 15)) & 0xFFFFFFFF;
    t = (t * 0x846CA68B) & 0xFFFFFFFF;
    t = t ^ (t >> 16);
    return t & 0xFFFFFFFF;
  }

  /// [0, 1)
  double nextDouble() => nextUint32() / 4294967296.0;

  /// [min, max)
  double range(double min, double max) => min + nextDouble() * (max - min);

  int intRange(int min, int max) =>
      min + (nextDouble() * (max - min + 1)).floor();

  /// [0, n) untuk n > 0; 0 jika n <= 0.
  int nextIntBounded(int n) => n <= 0 ? 0 : nextUint32() % n;

  bool chance(double p) => nextDouble() < p;

  T pick<T>(List<T> list) => list[nextUint32() % list.length];

  SeededRng fork() => SeededRng(nextUint32());
}
