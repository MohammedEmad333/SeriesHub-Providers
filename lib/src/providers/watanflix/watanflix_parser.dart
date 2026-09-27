import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../models/source_models.dart';

class WatanFlixParser {
  const WatanFlixParser();

  List<SourceSeries> parseSeriesList(String html, Uri baseUri) {
    final document = html_parser.parse(html);
    final seen = <String>{};
    final result = <SourceSeries>[];

    for (final anchor in document.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href'];
      if (href == null || !href.contains('/series/')) continue;

      final uri = baseUri.resolve(href);
      final id = _seriesIdFromUri(uri);
      if (id.isEmpty || !seen.add(id)) continue;

      final title = _clean(
        anchor.attributes['title'] ??
            anchor.querySelector('img')?.attributes['alt'] ??
            anchor.text,
      );
      if (title.isEmpty) continue;

      final image = anchor.querySelector('img');
      final poster = _resolveOptional(
        baseUri,
        image?.attributes['data-src'] ?? image?.attributes['src'],
      );

      result.add(
        SourceSeries(
          id: id,
          title: title,
          webUrl: uri,
          posterUrl: poster,
        ),
      );
    }

    return result;
  }

  SourceSeries parseSeries(String html, Uri pageUri) {
    final document = html_parser.parse(html);
    final title = _firstText(document, ['h1', '.series-title', '.title']);
    if (title == null || title.isEmpty) {
      throw const FormatException('WatanFlix series title was not found.');
    }

    final overview = _firstText(document, [
      '.description',
      '.series-description',
      '.story',
      '[itemprop="description"]',
    ]);

    final poster = _firstImage(document, pageUri, [
      '.series-poster img',
      '.poster img',
      'main img',
    ]);

    final bodyText = _clean(document.body?.text ?? '');
    final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(bodyText);
    final year = yearMatch == null ? null : int.tryParse(yearMatch.group(0)!);

    final genres = <String>{
      ...document
          .querySelectorAll('a[href*="/type/"]')
          .map((element) => _clean(element.text))
          .where((value) => value.isNotEmpty),
    }.toList(growable: false);

    return SourceSeries(
      id: _seriesIdFromUri(pageUri),
      title: title,
      webUrl: pageUri,
      overview: overview,
      posterUrl: poster,
      year: year,
      genres: genres,
    );
  }

  List<SourceEpisode> parseEpisodes(
    String html,
    Uri seriesUri,
    String seriesId,
  ) {
    final document = html_parser.parse(html);
    final candidates = document.querySelectorAll('a[href]');
    final seen = <String>{};
    final episodes = <SourceEpisode>[];

    for (final anchor in candidates) {
      final text = _clean(anchor.text);
      final href = anchor.attributes['href'];
      if (href == null) continue;

      final looksLikeEpisode =
          href.contains('/episode/') ||
          href.contains('/watch/') ||
          RegExp(r'(الحلقة|episode)\s*\d+', caseSensitive: false)
              .hasMatch(text);
      if (!looksLikeEpisode) continue;

      final uri = seriesUri.resolve(href);
      final numberMatch =
          RegExp(r'(?:الحلقة|episode)\s*(\d+)', caseSensitive: false)
              .firstMatch(text);
      final fallbackMatch = RegExp(r'(\d+)(?:/)?$').firstMatch(uri.path);
      final number = int.tryParse(
        numberMatch?.group(1) ?? fallbackMatch?.group(1) ?? '',
      );
      if (number == null) continue;

      final id = uri.toString();
      if (!seen.add(id)) continue;

      final image = anchor.querySelector('img');
      episodes.add(
        SourceEpisode(
          id: id,
          seriesId: seriesId,
          number: number,
          title: text.isEmpty ? 'الحلقة $number' : text,
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

  static String _seriesIdFromUri(Uri uri) {
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
      final value =
          image?.attributes['data-src'] ?? image?.attributes['src'];
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
