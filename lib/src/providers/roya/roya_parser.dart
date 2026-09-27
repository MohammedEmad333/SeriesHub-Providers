import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../models/source_models.dart';

class RoyaParser {
  const RoyaParser();

  List<SourceSeries> parseSeriesList(String html, Uri baseUri) {
    final document = html_parser.parse(html);
    final seen = <String>{};
    final items = <SourceSeries>[];

    for (final anchor in document.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href'];
      if (href == null || !href.contains('/program/')) continue;

      final uri = baseUri.resolve(href);
      final id = _lastSegment(uri);
      if (id.isEmpty || !seen.add(id)) continue;

      final image = anchor.querySelector('img');
      final title = _clean(
        anchor.attributes['title'] ??
            image?.attributes['alt'] ??
            anchor.text,
      );
      if (title.isEmpty) continue;

      items.add(
        SourceSeries(
          id: id,
          title: title,
          webUrl: uri,
          posterUrl: _resolveOptional(
            baseUri,
            image?.attributes['data-src'] ?? image?.attributes['src'],
          ),
        ),
      );
    }

    return items;
  }

  SourceSeries parseSeries(String html, Uri pageUri) {
    final document = html_parser.parse(html);
    final title = _firstText(document, ['h1', '.program-title', '.title']);
    if (title == null || title.isEmpty) {
      throw const FormatException('Roya series title was not found.');
    }

    final overview = _firstText(document, [
      '.description',
      '.program-description',
      '.story',
      '[itemprop="description"]',
      'main p',
    ]);

    final poster = _firstImage(document, pageUri, [
      '.program-poster img',
      '.poster img',
      'main img',
    ]);

    return SourceSeries(
      id: _lastSegment(pageUri),
      title: title,
      webUrl: pageUri,
      overview: overview,
      posterUrl: poster,
    );
  }

  List<SourceEpisode> parseEpisodes(
    String html,
    Uri seriesUri,
    String seriesId,
  ) {
    final document = html_parser.parse(html);
    final seen = <String>{};
    final episodes = <SourceEpisode>[];

    for (final anchor in document.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href'];
      if (href == null || !href.contains('/videos/')) continue;

      final uri = seriesUri.resolve(href);
      final id = _lastSegment(uri);
      if (id.isEmpty || !seen.add(id)) continue;

      final image = anchor.querySelector('img');
      final title = _clean(
        anchor.attributes['title'] ??
            image?.attributes['alt'] ??
            anchor.text,
      );
      final numberMatch = RegExp(
        r'(?:episode|الحلقة)\s*0*(\d+)',
        caseSensitive: false,
      ).firstMatch(title);
      final fallback = int.tryParse(id);
      final number = int.tryParse(numberMatch?.group(1) ?? '') ?? fallback;
      if (number == null) continue;

      episodes.add(
        SourceEpisode(
          id: uri.toString(),
          seriesId: seriesId,
          number: number,
          title: title.isEmpty ? 'الحلقة $number' : title,
          webUrl: uri,
          thumbnailUrl: _resolveOptional(
            seriesUri,
            image?.attributes['data-src'] ?? image?.attributes['src'],
          ),
        ),
      );
    }

    episodes.sort((a, b) => a.number.compareTo(b.number));
    return episodes;
  }

  static String _lastSegment(Uri uri) {
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    return segments.isEmpty ? '' : Uri.decodeComponent(segments.last);
  }

  static String? _firstText(Document document, List<String> selectors) {
    for (final selector in selectors) {
      final value = _clean(document.querySelector(selector)?.text ?? '');
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  static Uri? _firstImage(
    Document document,
    Uri baseUri,
    List<String> selectors,
  ) {
    for (final selector in selectors) {
      final image = document.querySelector(selector);
      final value = image?.attributes['data-src'] ?? image?.attributes['src'];
      final resolved = _resolveOptional(baseUri, value);
      if (resolved != null) return resolved;
    }
    return null;
  }

  static Uri? _resolveOptional(Uri baseUri, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return baseUri.resolve(value.trim());
  }

  static String _clean(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
