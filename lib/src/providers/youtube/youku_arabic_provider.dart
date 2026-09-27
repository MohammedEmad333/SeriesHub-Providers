import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/source_models.dart';
import '../../provider/source_provider.dart';

class YoukuArabicProvider implements SourceProvider {
  YoukuArabicProvider({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static final _series = <String, SourceSeries>{
    'youku-fall-in-love': SourceSeries(
      id: 'youku-fall-in-love',
      title: 'الحب من أول نظرة',
      overview:
          'مسلسل رومانسي منشور بحلقات كاملة على قناة YOUKU Arabic الرسمية.',
      year: 2021,
      genres: ['رومانسي', 'دراما', 'مترجم'],
      webUrl: Uri.parse('https://www.youtube.com/watch?v=xlDRAZOQZyk'),
      posterUrl: Uri.parse(
        'https://i.ytimg.com/vi/xlDRAZOQZyk/hqdefault.jpg',
      ),
    ),
  };

  static final _episodes = <String, List<SourceEpisode>>{
    'youku-fall-in-love': [
      SourceEpisode(
        id: 'xlDRAZOQZyk',
        seriesId: 'youku-fall-in-love',
        number: 1,
        title: 'الحلقة 1',
        webUrl: Uri.parse(
          'https://www.youtube.com/watch?v=xlDRAZOQZyk',
        ),
        thumbnailUrl: Uri.parse(
          'https://i.ytimg.com/vi/xlDRAZOQZyk/hqdefault.jpg',
        ),
      ),
      SourceEpisode(
        id: 'QVRH872sXaA',
        seriesId: 'youku-fall-in-love',
        number: 2,
        title: 'الحلقة 2',
        webUrl: Uri.parse(
          'https://www.youtube.com/watch?v=QVRH872sXaA',
        ),
        thumbnailUrl: Uri.parse(
          'https://i.ytimg.com/vi/QVRH872sXaA/hqdefault.jpg',
        ),
      ),
      SourceEpisode(
        id: 'dkV9xwyTCeU',
        seriesId: 'youku-fall-in-love',
        number: 3,
        title: 'الحلقة 3',
        webUrl: Uri.parse(
          'https://www.youtube.com/watch?v=dkV9xwyTCeU',
        ),
        thumbnailUrl: Uri.parse(
          'https://i.ytimg.com/vi/dkV9xwyTCeU/hqdefault.jpg',
        ),
      ),
    ],
  };

  @override
  String get id => 'youku-arabic';

  @override
  String get name => 'YOUKU Arabic';

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
      throw StateError('Unknown YOUKU Arabic series: $seriesId');
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
