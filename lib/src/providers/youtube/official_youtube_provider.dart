import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/source_models.dart';
import '../../provider/source_provider.dart';

class OfficialYouTubeProvider implements SourceProvider {
  OfficialYouTubeProvider({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static final _series = <String, SourceSeries>{
    'mangotv-unforgettable-love': SourceSeries(
      id: 'mangotv-unforgettable-love',
      title: 'حب لا يُنسى',
      overview:
          'مسلسل اجتماعي رومانسي منشور بحلقات كاملة على قناة MangoTV Arabic الرسمية.',
      year: 2021,
      genres: ['رومانسي', 'اجتماعي', 'مترجم'],
      webUrl: Uri.parse('https://www.youtube.com/watch?v=7HID7fAylyg'),
      posterUrl: Uri.parse(
        'https://i.ytimg.com/vi/7HID7fAylyg/hqdefault.jpg',
      ),
    ),
  };

  static final _episodes = <String, List<SourceEpisode>>{
    'mangotv-unforgettable-love': [
      SourceEpisode(
        id: '7HID7fAylyg',
        seriesId: 'mangotv-unforgettable-love',
        number: 1,
        title: 'الحلقة 1',
        webUrl: Uri.parse(
          'https://www.youtube.com/watch?v=7HID7fAylyg',
        ),
        thumbnailUrl: Uri.parse(
          'https://i.ytimg.com/vi/7HID7fAylyg/hqdefault.jpg',
        ),
      ),
      SourceEpisode(
        id: 'NusHq9pSPeE',
        seriesId: 'mangotv-unforgettable-love',
        number: 2,
        title: 'الحلقة 2',
        webUrl: Uri.parse(
          'https://www.youtube.com/watch?v=NusHq9pSPeE',
        ),
        thumbnailUrl: Uri.parse(
          'https://i.ytimg.com/vi/NusHq9pSPeE/hqdefault.jpg',
        ),
      ),
      SourceEpisode(
        id: 'bagR9APb36Q',
        seriesId: 'mangotv-unforgettable-love',
        number: 3,
        title: 'الحلقة 3',
        webUrl: Uri.parse(
          'https://www.youtube.com/watch?v=bagR9APb36Q',
        ),
        thumbnailUrl: Uri.parse(
          'https://i.ytimg.com/vi/bagR9APb36Q/hqdefault.jpg',
        ),
      ),
    ],
  };

  @override
  String get id => 'official-youtube';

  @override
  String get name => 'YouTube الرسمي';

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
      throw StateError('Unknown official YouTube series: $seriesId');
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
