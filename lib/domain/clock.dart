/// Abstraksi Clock — boleh dipalsukan dalam test untuk determinisme.
library;

abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now().toUtc();
}

/// UTC helpers — LiveOps & lelongan bekerja dalam UTC.
int minutesSinceEpoch(DateTime t) => t.toUtc().millisecondsSinceEpoch ~/ 60000;
DateTime fromMinutesSinceEpoch(int m) =>
    DateTime.fromMillisecondsSinceEpoch(m * 60000, isUtc: true);
