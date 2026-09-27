import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../../models/source_models.dart';
import '../../provider/source_provider.dart';

class YouTubeChannelProvider implements SourceProvider {
  YouTubeChannelProvider({
    required this.id,
    required this.name,
    required this.seedVideoId,
    required this.fallbackTitle,
    required this.fallbackOverview,
    this.fallbackYear,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  final String id;

  @override
  final String name;

  final String seedVideoId;
  final String fallbackTitle;
  final String fallbackOverview;
  final int? fallbackYear;
  final http.Client _client;

  String? _channelId;
  final Map<String, SourceSeries> _seriesById = {};
  final Map<String, List<SourceEpisode>> _episodesBySeries = {};
  DateTime? _lastRefresh;

  @override
  Uri get baseUri => Uri.parse('https://www.youtube.com/');

  @override
  Future<List<SourceSeries>> browse({int page = 1}) async {
    if (page != 1) return const [];
    await _ensureCatalog();
    return _seriesById.values.toList(growable: false);
  }

  @override
  Future<List<SourceSeries>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    final items = await browse();
    if (normalized.isEmpty) return items;
    return items
        .where(
          (series) =>
              series.title.toLowerCase().contains(normalized) ||
              (series.overview ?? '').toLowerCase().contains(normalized),
        )
        .toList(growable: false);
  }

  @override
  Future<SourceSeries> getSeries(String seriesId) async {
    await _ensureCatalog();
    final item = _seriesById[seriesId];
    if (item == null) {
      throw StateError('Unknown YouTube series: $seriesId');
    }
    return item;
  }

  @override
  Future<List<SourceEpisode>> getEpisodes(String seriesId) async {
    await _ensureCatalog();
    return _episodesBySeries[seriesId] ?? const [];
  }

  @override
  Future<List<SourcePlayback>> getPlaybackSources(String episodeId) async {
    if (episodeId.trim().isEmpty) return const [];
    return [
      SourcePlayback(
        url: Uri.https('www.youtube.com', '/watch', {'v': episodeId}),
        label: 'YouTube',
        mimeType: 'video/youtube',
      ),
    ];
  }

  Future<void> _ensureCatalog() async {
    final refreshed = _lastRefresh;
    if (refreshed != null &&
        DateTime.now().difference(refreshed) < const Duration(hours: 1) &&
        _seriesById.isNotEmpty) {
      return;
    }

    try {
      final channelId = _channelId ?? await _discoverChannelId();
      _channelId = channelId;
      final feed = await _get(
        Uri.https(
          'www.youtube.com',
          '/feeds/videos.xml',
          {'channel_id': channelId},
        ),
      );
      _parseFeed(feed);
      _lastRefresh = DateTime.now();
    } on Object {
      if (_seriesById.isEmpty) {
        _installFallback();
      }
    }
  }

  Future<String> _discoverChannelId() async {
    final html = await _get(
      Uri.https('www.youtube.com', '/watch', {'v': seedVideoId}),
    );

    final match = RegExp(
      r'"channelId":"(UC[^"]+)"',
    ).firstMatch(html);

    if (match == null) {
      throw StateError('Unable to discover YouTube channel id');
    }

    return match.group(1)!;
  }

  Future<String> _get(Uri uri) async {
    final response = await _client.get(
      uri,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/124.0 Mobile Safari/537.36',
        'Accept-Language': 'ar,en;q=0.8',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'YouTube returned HTTP ${response.statusCode}',
        uri,
      );
    }

    return response.body;
  }

  void _parseFeed(String xml) {
    final document = XmlDocument.parse(xml);
    final groups = <String, List<_FeedVideo>>{};

    for (final entry in document.descendants.whereType<XmlElement>().where(
          (element) => element.name.local == 'entry',
        )) {
      String? childText(String localName) {
        for (final element in entry.descendants.whereType<XmlElement>()) {
          if (element.name.local == localName) {
            final value = element.innerText.trim();
            if (value.isNotEmpty) return value;
          }
        }
        return null;
      }

      final id = childText('videoId');
      final rawTitle = childText('title');
      if (id == null || rawTitle == null) continue;

      final title = _decodeXml(rawTitle);
      final episodeNumber = _episodeNumber(title);
      final seriesTitle = _seriesTitle(title);
      final key = seriesTitle.toLowerCase();

      groups.putIfAbsent(key, () => []).add(
            _FeedVideo(
              id: id,
              title: title,
              seriesTitle: seriesTitle,
              episodeNumber: episodeNumber,
            ),
          );
    }

    if (groups.isEmpty) {
      throw StateError('YouTube feed did not contain videos');
    }

    _seriesById.clear();
    _episodesBySeries.clear();

    for (final videos in groups.values) {
      final sorted = [...videos]..sort((a, b) {
          final an = a.episodeNumber;
          final bn = b.episodeNumber;
          if (an != null && bn != null) return an.compareTo(bn);
          if (an != null) return -1;
          if (bn != null) return 1;
          return a.title.compareTo(b.title);
        });

      final first = sorted.first;
      final seriesId = '$id:${Uri.encodeComponent(first.seriesTitle)}';

      _seriesById[seriesId] = SourceSeries(
        id: seriesId,
        title: first.seriesTitle,
        overview: 'حلقات حديثة من قناة $name الرسمية على YouTube.',
        webUrl: Uri.https(
          'www.youtube.com',
          '/watch',
          {'v': first.id},
        ),
        posterUrl: Uri.parse(
          'https://i.ytimg.com/vi/${first.id}/hqdefault.jpg',
        ),
        genres: const ['مترجم'],
      );

      _episodesBySeries[seriesId] = [
        for (var index = 0; index < sorted.length; index++)
          SourceEpisode(
            id: sorted[index].id,
            seriesId: seriesId,
            number: sorted[index].episodeNumber ?? index + 1,
            title: sorted[index].episodeNumber == null
                ? sorted[index].title
                : 'الحلقة ${sorted[index].episodeNumber}',
            webUrl: Uri.https(
              'www.youtube.com',
              '/watch',
              {'v': sorted[index].id},
            ),
            thumbnailUrl: Uri.parse(
              'https://i.ytimg.com/vi/${sorted[index].id}/hqdefault.jpg',
            ),
          ),
      ];
    }
  }

  void _installFallback() {
    final seriesId = '$id:fallback';
    _seriesById[seriesId] = SourceSeries(
      id: seriesId,
      title: fallbackTitle,
      overview: fallbackOverview,
      year: fallbackYear,
      genres: const ['مترجم'],
      webUrl: Uri.https('www.youtube.com', '/watch', {'v': seedVideoId}),
      posterUrl: Uri.parse(
        'https://i.ytimg.com/vi/$seedVideoId/hqdefault.jpg',
      ),
    );
    _episodesBySeries[seriesId] = [
      SourceEpisode(
        id: seedVideoId,
        seriesId: seriesId,
        number: 1,
        title: 'الحلقة 1',
        webUrl: Uri.https('www.youtube.com', '/watch', {'v': seedVideoId}),
        thumbnailUrl: Uri.parse(
          'https://i.ytimg.com/vi/$seedVideoId/hqdefault.jpg',
        ),
      ),
    ];
    _lastRefresh = DateTime.now();
  }

  static String? _first(String input, String pattern) {
    return RegExp(pattern, caseSensitive: false).firstMatch(input)?.group(1);
  }

  static int? _episodeNumber(String title) {
    final patterns = [
      RegExp(r'(?:الحلقة|حلقة)\s*[-:#]?\s*(\d+)', caseSensitive: false),
      RegExp(r'\bEP(?:ISODE)?\s*[-:#]?\s*(\d+)\b', caseSensitive: false),
      RegExp(r'[【\[]\s*EP\s*(\d+)\s*[】\]]', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(title);
      if (match != null) return int.tryParse(match.group(1)!);
    }
    return null;
  }

  static String _seriesTitle(String title) {
    var value = title;
    value = value.replaceAll(
      RegExp(
        r'(?:الحلقة|حلقة)\s*[-:#]?\s*\d+',
        caseSensitive: false,
      ),
      '',
    );
    value = value.replaceAll(
      RegExp(
        r'\bEP(?:ISODE)?\s*[-:#]?\s*\d+\b',
        caseSensitive: false,
      ),
      '',
    );
    value = value.replaceAll(
      RegExp(
        r'[【\[]\s*EP\s*\d+\s*[】\]]',
        caseSensitive: false,
      ),
      '',
    );
    value = value.replaceAll(RegExp(r'\s*[|｜]\s*.*$'), '');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();

    return value.isEmpty ? title.trim() : value;
  }

  static String _decodeXml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}

class _FeedVideo {
  const _FeedVideo({
    required this.id,
    required this.title,
    required this.seriesTitle,
    required this.episodeNumber,
  });

  final String id;
  final String title;
  final String seriesTitle;
  final int? episodeNumber;
}
