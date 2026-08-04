/// A progress photo for one day, snapshotting that day's calories-so-far
/// and logged weight at the time it was taken.
class PhotoEntry {
  final DateTime date;
  final String imagePath;
  final double? kcalAtLogging;
  final double? weightKgAtLogging;

  const PhotoEntry({
    required this.date,
    required this.imagePath,
    this.kcalAtLogging,
    this.weightKgAtLogging,
  });

  Map<String, dynamic> toJson() => {
    'date': DateTime(date.year, date.month, date.day).toIso8601String(),
    'imagePath': imagePath,
    'kcalAtLogging': kcalAtLogging,
    'weightKgAtLogging': weightKgAtLogging,
  };

  factory PhotoEntry.fromJson(Map<String, dynamic> json) {
    return PhotoEntry(
      date: DateTime.parse(json['date'] as String),
      imagePath: json['imagePath'] as String,
      kcalAtLogging: (json['kcalAtLogging'] as num?)?.toDouble(),
      weightKgAtLogging: (json['weightKgAtLogging'] as num?)?.toDouble(),
    );
  }
}
