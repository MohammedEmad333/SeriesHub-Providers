class SourceSeries {
  const SourceSeries({
    required this.id,
    required this.title,
    required this.webUrl,
    this.overview,
    this.posterUrl,
    this.year,
    this.genres = const [],
  });

  final String id;
  final String title;
  final Uri webUrl;
  final String? overview;
  final Uri? posterUrl;
  final int? year;
  final List<String> genres;
}

class SourceEpisode {
  const SourceEpisode({
    required this.id,
    required this.seriesId,
    required this.number,
    required this.title,
    required this.webUrl,
    this.thumbnailUrl,
  });

  final String id;
  final String seriesId;
  final int number;
  final String title;
  final Uri webUrl;
  final Uri? thumbnailUrl;
}

class SourcePlayback {
  const SourcePlayback({
    required this.url,
    this.label,
    this.mimeType,
    this.headers = const {},
  });

  final Uri url;
  final String? label;
  final String? mimeType;
  final Map<String, String> headers;
}
