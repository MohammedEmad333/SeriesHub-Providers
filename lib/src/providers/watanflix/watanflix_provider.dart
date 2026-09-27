import 'dart:async';

import 'package:http/http.dart' as http;

import '../../models/source_models.dart';
import '../../provider/source_provider.dart';
import 'watanflix_parser.dart';

class WatanFlixProvider implements SourceProvider {
  WatanFlixProvider({
    http.Client? client,
    WatanFlixParser parser = const WatanFlixParser(),
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _parser = parser,
        _baseUri = baseUri ?? Uri.parse('https://www.watanflix.com/ar/');

  final http.Client _client;
  final WatanFlixParser _parser;
  final Uri _baseUri;

  static const _headers = <String, String>{
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'ar,en;q=0.8',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
  };

  @override
  String get id => 'watanflix';

  @override
  String get name => 'WatanFlix';

  @override
  Uri get baseUri => _baseUri;

  @override
  Future<List<SourceSeries>> browse({int page = 1}) async {
    final uri = page <= 1
        ? _baseUri
        : _baseUri.replace(queryParameters: {'page': '$page'});
    final html = await _getText(uri);
    return _parser.parseSeriesList(html, _baseUri);
  }

  @override
  Future<List<SourceSeries>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return browse();

    // WatanFlix does not currently expose a stable documented search API.
    // Keep the first implementation deterministic by filtering the public
    // catalog page. This can be replaced by an official/public endpoint later.
    final catalog = await browse();
    return catalog
        .where((item) => item.title.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  @override
  Future<SourceSeries> getSeries(String seriesId) async {
    final uri = _seriesUri(seriesId);
    final html = await _getText(uri);
    return _parser.parseSeries(html, uri);
  }

  @override
  Future<List<SourceEpisode>> getEpisodes(String seriesId) async {
    final uri = _seriesUri(seriesId);
    final html = await _getText(uri);
    return _parser.parseEpisodes(html, uri, seriesId);
  }

  @override
  Future<List<SourcePlayback>> getPlaybackSources(String episodeId) async {
    // Intentionally conservative: do not guess private player APIs or scrape
    // protected stream URLs. A playback resolver can be added when a stable,
    // publicly exposed/authorized resource is verified.
    return const [];
  }

  Uri _seriesUri(String seriesId) => _baseUri.resolve(
        'series/${Uri.encodeComponent(seriesId)}',
      );

  Future<String> _getText(Uri uri) async {
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'WatanFlix returned HTTP ${response.statusCode}',
        uri,
      );
    }

    return response.body;
  }
}
