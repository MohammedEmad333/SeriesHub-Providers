import 'dart:async';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../../models/source_models.dart';
import '../../provider/source_provider.dart';

class SimplePublicCatalogProvider implements SourceProvider {
  SimplePublicCatalogProvider({
    required this.id,
    required this.name,
    required this.baseUri,
    http.Client? client,
    this.homePath = '/',
  }) : _client = client ?? http.Client();

  @override
  final String id;

  @override
  final String name;

  @override
  final Uri baseUri;

  final String homePath;
  final http.Client _client;

  static const _headers = <String, String>{
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'ar,en;q=0.8',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
  };

  @override
  Future<List<SourceSeries>> browse({int page = 1}) async {
    var uri = baseUri.resolve(homePath);
    if (page > 1) {
      uri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'page': '$page',
      });
    }

    final html = await _getText(uri);
    return _parseCatalog(html, uri);
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
    final uri = _decodeId(seriesId);
    final html = await _getText(uri);
    final document = html_parser.parse(html);

    final title =
        _firstText(document, [
          'h1',
          '[itemprop="name"]',
          '.title',
          '.post-title',
          'title',
        ]) ??
        uri.pathSegments.lastOrNull ??
        name;

    final description =
        _meta(document, 'description') ??
        _firstText(document, [
          '[itemprop="description"]',
          '.description',
          '.story',
          '.plot',
          '.summary',
        ]);

    final poster = _firstImage(document, uri);
    final bodyText = _clean(document.body?.text ?? '');
    final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(bodyText);

    return SourceSeries(
      id: seriesId,
      title: title,
      webUrl: uri,
      overview: description,
      posterUrl: poster,
      year: yearMatch == null ? null : int.tryParse(yearMatch.group(0)!),
    );
  }

  @override
  Future<List<SourceEpisode>> getEpisodes(String seriesId) async {
    final uri = _decodeId(seriesId);
    final html = await _getText(uri);
    final document = html_parser.parse(html);
    final seen = <String>{};
    final episodes = <SourceEpisode>[];

    for (final anchor in document.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href'];
      if (href == null || href.trim().isEmpty) continue;

      final text = _clean(
        anchor.attributes['title'] ??
            anchor.querySelector('img')?.attributes['alt'] ??
            anchor.text,
      );

      final numberMatch = RegExp(
        r'(?:الحلقة|episode)\s*(\d+)',
        caseSensitive: false,
      ).firstMatch(text);

      final hrefLooksLikeEpisode = RegExp(
        r'/(episode|episodes|watch|view)/',
        caseSensitive: false,
      ).hasMatch(href);

      if (numberMatch == null && !hrefLooksLikeEpisode) continue;

      final episodeUri = uri.resolve(href);
      if (episodeUri.host != baseUri.host &&
          !episodeUri.host.endsWith('.${baseUri.host}')) {
        continue;
      }

      final id = episodeUri.toString();
      if (!seen.add(id)) continue;

      final fallbackMatch = RegExp(r'(\d+)(?:/)?$').firstMatch(episodeUri.path);
      final number = int.tryParse(
            numberMatch?.group(1) ?? fallbackMatch?.group(1) ?? '',
          ) ??
          (episodes.length + 1);

      episodes.add(
        SourceEpisode(
          id: id,
          seriesId: seriesId,
          number: number,
          title: text.isEmpty ? 'الحلقة $number' : text,
          webUrl: episodeUri,
          thumbnailUrl: _imageFromAnchor(anchor, uri),
        ),
      );
    }

    episodes.sort((a, b) => a.number.compareTo(b.number));
    return episodes;
  }

  @override
  Future<List<SourcePlayback>> getPlaybackSources(String episodeId) async {
    final pageUri = Uri.tryParse(episodeId);
    if (pageUri == null || !pageUri.hasScheme) return const [];

    final html = await _getText(pageUri);
    final direct = _extractPlayback(html, pageUri);
    if (direct.isNotEmpty) return direct;

    // Follow a small number of publicly exposed embeds and only return direct
    // media URLs found in their HTML. This does not bypass DRM, tokens,
    // authentication, anti-bot challenges, or private player APIs.
    final document = html_parser.parse(html);
    final embeds = document
        .querySelectorAll('iframe[src]')
        .map((element) => element.attributes['src'])
        .whereType<String>()
        .map(pageUri.resolve)
        .where((uri) => uri.scheme == 'http' || uri.scheme == 'https')
        .take(3);

    final result = <SourcePlayback>[];
    final seen = <String>{};

    for (final embedUri in embeds) {
      try {
        final embedHtml = await _getText(
          embedUri,
          extraHeaders: {'Referer': pageUri.toString()},
        );
        for (final source in _extractPlayback(embedHtml, embedUri)) {
          if (seen.add(source.url.toString())) {
            result.add(
              SourcePlayback(
                url: source.url,
                label: source.label,
                mimeType: source.mimeType,
                headers: {
                  ...source.headers,
                  'Referer': embedUri.toString(),
                },
              ),
            );
          }
        }
      } on Object {
        // A blocked/unavailable embed should not break the whole episode.
      }
    }

    return result;
  }

  List<SourceSeries> _parseCatalog(String html, Uri pageUri) {
    final document = html_parser.parse(html);
    final seen = <String>{};
    final items = <SourceSeries>[];

    for (final anchor in document.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href'];
      if (href == null || href.trim().isEmpty) continue;

      final target = pageUri.resolve(href);
      if (target.scheme != 'http' && target.scheme != 'https') continue;
      if (target.host != baseUri.host &&
          !target.host.endsWith('.${baseUri.host}')) {
        continue;
      }

      final title = _clean(
        anchor.attributes['title'] ??
            anchor.querySelector('img')?.attributes['alt'] ??
            anchor.text,
      );
      if (!_looksLikeMedia(title, target.path)) continue;

      final id = _encodeId(target);
      if (!seen.add(id)) continue;

      final image = anchor.querySelector('img');
      final poster = _resolveOptional(
        pageUri,
        image?.attributes['data-src'] ??
            image?.attributes['data-lazy-src'] ??
            image?.attributes['src'],
      );

      items.add(
        SourceSeries(
          id: id,
          title: title,
          webUrl: target,
          posterUrl: poster,
        ),
      );
    }

    return items;
  }

  static bool _looksLikeMedia(String title, String path) {
    if (title.length < 3) return false;
    final value = '$title $path'.toLowerCase();
    return RegExp(
      r'(فيلم|مسلسل|الحلقة|مشاهدة|movie|film|series|episode|season)',
      caseSensitive: false,
    ).hasMatch(value);
  }

  static String _encodeId(Uri uri) => Uri.encodeComponent(uri.toString());

  static Uri _decodeId(String id) {
    final decoded = Uri.decodeComponent(id);
    final uri = Uri.tryParse(decoded);
    if (uri == null || !uri.hasScheme) {
      throw ArgumentError.value(id, 'seriesId', 'Invalid catalog item id');
    }
    return uri;
  }

  Future<String> _getText(
    Uri uri, {
    Map<String, String> extraHeaders = const {},
  }) async {
    final response = await _client
        .get(
          uri,
          headers: {
            ..._headers,
            ...extraHeaders,
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        '$name returned HTTP ${response.statusCode}',
        uri,
      );
    }

    return response.body;
  }

  List<SourcePlayback> _extractPlayback(String html, Uri pageUri) {
    final document = html_parser.parse(html);
    final result = <SourcePlayback>[];
    final seen = <String>{};

    void add(
      String? value, {
      String? mimeType,
      String? label,
    }) {
      final raw = value?.trim();
      if (raw == null || raw.isEmpty) return;

      final decoded = raw
          .replaceAll(r'\\/', '/')
          .replaceAll('&amp;', '&');
      final uri = pageUri.resolve(decoded);
      if (uri.scheme != 'http' && uri.scheme != 'https') return;

      final path = uri.path.toLowerCase();
      final inferredMime = mimeType ??
          (path.endsWith('.m3u8')
              ? 'application/x-mpegURL'
              : path.endsWith('.mpd')
                  ? 'application/dash+xml'
                  : path.endsWith('.mp4')
                      ? 'video/mp4'
                      : path.endsWith('.webm')
                          ? 'video/webm'
                          : null);

      if (inferredMime == null &&
          !RegExp(
            r'\.(m3u8|mpd|mp4|webm)(?:$|\?)',
            caseSensitive: false,
          ).hasMatch(uri.toString())) {
        return;
      }

      if (!seen.add(uri.toString())) return;
      result.add(
        SourcePlayback(
          url: uri,
          label: label ?? _playbackLabel(uri),
          mimeType: inferredMime,
          headers: {'Referer': pageUri.toString()},
        ),
      );
    }

    for (final video in document.querySelectorAll('video[src]')) {
      add(video.attributes['src']);
    }

    for (final source in document.querySelectorAll('video source[src]')) {
      add(
        source.attributes['src'],
        mimeType: source.attributes['type'],
        label: source.attributes['label'] ??
            source.attributes['data-res'],
      );
    }

    for (final selector in const [
      'meta[property="og:video"]',
      'meta[property="og:video:url"]',
      'meta[property="og:video:secure_url"]',
      'meta[itemprop="contentUrl"]',
    ]) {
      add(document.querySelector(selector)?.attributes['content']);
    }

    for (final script in document.querySelectorAll(
      'script[type="application/ld+json"]',
    )) {
      final text = script.text;
      for (final match in RegExp(
        r'"(?:contentUrl|embedUrl)"\s*:\s*"([^"]+)"',
        caseSensitive: false,
      ).allMatches(text)) {
        add(match.group(1));
      }
    }

    for (final match in RegExp(
      r'''https?:\\?/\\?/[^"'\s<>]+?\.(?:m3u8|mpd|mp4|webm)(?:\?[^"'\s<>]*)?''',
      caseSensitive: false,
    ).allMatches(html)) {
      add(match.group(0));
    }

    return result;
  }

  static String _playbackLabel(Uri uri) {
    final text = uri.toString().toLowerCase();
    if (text.contains('.m3u8')) return 'HLS';
    if (text.contains('.mpd')) return 'DASH';
    if (text.contains('.webm')) return 'WebM';
    return 'MP4';
  }

  static String? _firstText(Document document, List<String> selectors) {
    for (final selector in selectors) {
      final value = _clean(document.querySelector(selector)?.text ?? '');
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  static String? _meta(Document document, String name) {
    final value =
        document.querySelector('meta[name="$name"]')?.attributes['content'];
    final cleaned = _clean(value ?? '');
    return cleaned.isEmpty ? null : cleaned;
  }

  static Uri? _firstImage(Document document, Uri baseUri) {
    for (final selector in const [
      'meta[property="og:image"]',
      '[itemprop="image"]',
      '.poster img',
      'main img',
      'article img',
    ]) {
      final element = document.querySelector(selector);
      final value = element?.attributes['content'] ??
          element?.attributes['data-src'] ??
          element?.attributes['src'];
      final resolved = _resolveOptional(baseUri, value);
      if (resolved != null) return resolved;
    }
    return null;
  }

  static Uri? _imageFromAnchor(Element anchor, Uri baseUri) {
    final image = anchor.querySelector('img');
    return _resolveOptional(
      baseUri,
      image?.attributes['data-src'] ??
          image?.attributes['data-lazy-src'] ??
          image?.attributes['src'],
    );
  }

  static Uri? _resolveOptional(Uri baseUri, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return baseUri.resolve(value.trim());
  }

  static String _clean(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

extension _LastOrNullExtension<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
