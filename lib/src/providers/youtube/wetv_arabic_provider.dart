import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/source_models.dart';
import '../../provider/source_provider.dart';

class WeTvArabicProvider implements SourceProvider {
  WeTvArabicProvider({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final _series = <String, SourceSeries>{
    'wetv-filter': SourceSeries(
      id: 'wetv-filter',
      title: 'الأفلام',
      overview:
          'مسلسل رومانسي منشور بحلقات كاملة على قناة WeTV Arabic الرسمية.',
      year: 2025,
      genres: ['رومانسي', 'دراما', 'مترجم'],
      webUrl: Uri.parse('https://www.youtube.com/watch?v=0n_mP4qJUgY'),
      posterUrl: Uri.parse(
        'https://i.ytimg.com/vi/0n_mP4qJUgY/hqdefault.jpg',
      ),
    ),
  };

  static final _episodes = <String, List<SourceEpisode>>{
    'wetv-filter': [
      SourceEpisode(
        id: '0n_mP4qJUgY',
        seriesId: 'wetv-filter',
        number: 1,
        title: 'الحلقة 1',
        webUrl: Uri.parse(
          'https://www.youtube.com/watch?v=0n_mP4qJUgY',
        ),
        thumbnailUrl: Uri.parse(
          'https://i.ytimg.com/vi/0n_mP4qJUgY/hqdefault.jpg',
        ),
      ),
      SourceEpisode(
        id: 'jMSwPwhPjV0',
        seriesId: 'wetv-filter',
        number: 2,
        title: 'الحلقة 2',
        webUrl: Uri.parse(
          'https://www.youtube.com/watch?v=jMSwPwhPjV0',
        ),
        thumbnailUrl: Uri.parse(
          'https://i.ytimg.com/vi/jMSwPwhPjV0/hqdefault.jpg',
        ),
      ),
      SourceEpisode(
        id: 'NKwK59tJWR4',
        seriesId: 'wetv-filter',
        number: 3,
        title: 'الحلقة 3',
        webUrl: Uri.parse(
          'https://www.youtube.com/watch?v=NKwK59tJWR4',
        ),
        thumbnailUrl: Uri.parse(
          'https://i.ytimg.com/vi/NKwK59tJWR4/hqdefault.jpg',
        ),
      ),
      SourceEpisode(
        id: 'fwikL_zs8N0',
        seriesId: 'wetv-filter',
        number: 4,
        title: 'الحلقة 4',
        webUrl: Uri.parse(
          'https://www.youtube.com/watch?v=fwikL_zs8N0',
        ),
        thumbnailUrl: Uri.parse(
          'https://i.ytimg.com/vi/fwikL_zs8N0/hqdefault.jpg',
        ),
      ),
    ],
  };

  @override
  String get id => 'wetv-arabic';

  @override
  String get name => 'WeTV Arabic';

  @override
  Uri get baseUri => Uri.parse('https://www.youtube.com/');

  @override
  Future<List<SourceSeries>> browse({int page = 1}) async {
    if (page != 1) return const [];
    return _series.values.toList(growable: false);
  }

  @override
  Future<List<SourceSeries>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return browse();

    return _series.values
        .where(
          (series) =>
              series.title.toLowerCase().contains(normalized) ||
              (series.overview ?? '').toLowerCase().contains(normalized),
        )
        .toList(growable: false);
  }

  @override
  Future<SourceSeries> getSeries(String seriesId) async {
    final series = _series[seriesId];
    if (series == null) {
      throw StateError('Unknown WeTV Arabic series: $seriesId');
    }
    return series;
  }

  @override
  Future<List<SourceEpisode>> getEpisodes(String seriesId) async {
    return _episodes[seriesId] ?? const [];
  }

  @override
  Future<List<SourcePlayback>> getPlaybackSources(String episodeId) async {
    final isKnown = _episodes.values
        .expand((episodes) => episodes)
        .any((episode) => episode.id == episodeId);
    if (!isKnown) return const [];

    final watchUri = Uri.https(
      'www.youtube.com',
      '/watch',
      {'v': episodeId},
    );
    final oEmbedUri = Uri.https(
      'www.youtube.com',
      '/oembed',
      {
        'url': watchUri.toString(),
        'format': 'json',
      },
    );

    final response = await _client.get(oEmbedUri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }

    try {
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) return const [];
      if ((payload['title'] as String?)?.trim().isEmpty ?? true) {
        return const [];
      }
    } on FormatException {
      return const [];
    }

    return [
      SourcePlayback(
        url: watchUri,
        label: 'YouTube',
        mimeType: 'video/youtube',
      ),
    ];
  }
}
