import 'dart:async';

import 'package:http/http.dart' as http;

import '../../models/source_models.dart';
import '../../provider/source_provider.dart';
import 'roya_parser.dart';

class RoyaProvider implements SourceProvider {
  RoyaProvider({
    http.Client? client,
    RoyaParser parser = const RoyaParser(),
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _parser = parser,
        _baseUri = baseUri ?? Uri.parse('https://en.roya.tv/');

  final http.Client _client;
  final RoyaParser _parser;
  final Uri _baseUri;

  static const _headers = <String, String>{
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'en,ar;q=0.9',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
  };

  @override
  String get id => 'roya';

  @override
  String get name => 'Roya TV';

  @override
  Uri get baseUri => _baseUri;

  @override
  Future<List<SourceSeries>> browse({int page = 1}) async {
    final uri = _baseUri.resolve('series');
    final html = await _getText(uri);
    return _parser.parseSeriesList(html, _baseUri);
  }

  @override
  Future<List<SourceSeries>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return browse();

    final catalog = await browse();
    return catalog
        .where((item) => item.title.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  @override
  Future<SourceSeries> getSeries(String seriesId) async {
    final uri = _baseUri.resolve('program/${Uri.encodeComponent(seriesId)}');
    final html = await _getText(uri);
    return _parser.parseSeries(html, uri);
  }

  @override
  Future<List<SourceEpisode>> getEpisodes(String seriesId) async {
    final uri = _baseUri.resolve('program/${Uri.encodeComponent(seriesId)}');
    final html = await _getText(uri);
    return _parser.parseEpisodes(html, uri, seriesId);
  }

  @override
  Future<List<SourcePlayback>> getPlaybackSources(String episodeId) async {
    return const [];
  }

  Future<String> _getText(Uri uri) async {
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Roya returned HTTP ${response.statusCode}',
        uri,
      );
    }

    return response.body;
  }
}
