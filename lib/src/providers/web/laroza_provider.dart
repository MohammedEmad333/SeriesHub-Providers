import 'package:html/parser.dart' as html_parser;

import '../../models/source_models.dart';
import 'simple_public_catalog_provider.dart';
import 'site_specific_helpers.dart';

/// Dedicated Laroza adapter.
///
/// Laroza currently exposes media and watch routes with site-specific naming.
/// This provider keeps its parsing separate from the generic catalog fallback
/// so changes to Laroza can be fixed without affecting other sources.
class LarozaProvider extends SimplePublicCatalogProvider {
  LarozaProvider()
      : super(
          id: 'laroza',
          name: 'Laroza',
          baseUri: Uri.parse('https://llaroza.click/'),
          homePath: 'home.24',
        );

  @override
  Future<List<SourceSeries>> browse({int page = 1}) async {
    final uri = page <= 1
        ? baseUri.resolve('home.24')
        : baseUri.resolve('home.24?page=$page');
    final html = await fetchText(uri);
    final document = html_parser.parse(html);
    final items = <SourceSeries>[];
    final seen = <String>{};

    for (final anchor in document.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href'];
      if (href == null || href.isEmpty) continue;
      final target = uri.resolve(href);
      if (target.host != baseUri.host) continue;

      final title = cleanText(
        anchor.attributes['title'] ??
            anchor.querySelector('img')?.attributes['alt'] ??
            anchor.text,
      );
      if (!_looksLikeLarozaItem(title, target.path)) continue;

      final id = encodeSeriesId(target);
      if (!seen.add(id)) continue;
      items.add(
        SourceSeries(
          id: id,
          title: title,
          webUrl: target,
          posterUrl: resolveImage(anchor, uri),
        ),
      );
    }

    return items;
  }

  @override
  Future<List<SourceEpisode>> getEpisodes(String seriesId) async {
    final uri = decodeSeriesId(seriesId);
    final html = await fetchText(uri);
    final document = html_parser.parse(html);
    final episodes = <SourceEpisode>[];
    final seen = <String>{};

    for (final anchor in document.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href'];
      if (href == null || href.isEmpty) continue;
      final target = uri.resolve(href);
      if (target.host != baseUri.host) continue;

      final text = cleanText(anchor.text);
      final number = episodeNumberFrom(text, target);
      final episodeLike = number != null ||
          RegExp(
            r'(?:watch|episode|ep|view|play)',
            caseSensitive: false,
          ).hasMatch(target.path);
      if (!episodeLike) continue;

      final resolvedNumber = number ?? episodes.length + 1;
      final key = '$resolvedNumber|${target.toString()}';
      if (!seen.add(key)) continue;

      episodes.add(
        SourceEpisode(
          id: target.toString(),
          seriesId: seriesId,
          number: resolvedNumber,
          title: text.isEmpty ? 'الحلقة $resolvedNumber' : text,
          webUrl: target,
          thumbnailUrl: resolveImage(anchor, uri),
        ),
      );
    }

    episodes.sort((a, b) => a.number.compareTo(b.number));
    if (episodes.isNotEmpty) return episodes;

    final heading = cleanText(document.querySelector('h1')?.text ?? '');
    final number = episodeNumberFrom(heading, uri) ?? 1;
    return [
      SourceEpisode(
        id: uri.toString(),
        seriesId: seriesId,
        number: number,
        title: heading.isEmpty ? 'الحلقة $number' : heading,
        webUrl: uri,
        thumbnailUrl: resolveImage(document, uri),
      ),
    ];
  }

  @override
  Future<List<SourcePlayback>> getPlaybackSources(String episodeId) async {
    final itemUri = Uri.tryParse(episodeId);
    if (itemUri == null || !itemUri.hasScheme) return const [];

    final html = await fetchText(itemUri);
    final document = html_parser.parse(html);

    final direct = extractPlayback(html, itemUri);
    if (direct.isNotEmpty) return direct;

    final candidates = <Uri>{
      ...publicServerCandidates(
        html,
        document,
        itemUri,
        limit: 10,
      ),
    };

    for (final anchor in document.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href'];
      if (href == null || href.isEmpty) continue;
      if (!RegExp(
        r'(?:watch|player|video|server|play)',
        caseSensitive: false,
      ).hasMatch(href)) {
        continue;
      }
      final target = itemUri.resolve(href);
      if (target.host == itemUri.host) candidates.add(target);
    }

    final batches = await Future.wait(
      candidates.take(10).map((candidate) async {
        try {
          return await resolvePublicPlayback(candidate, maxEmbeds: 5);
        } on Object {
          return const <SourcePlayback>[];
        }
      }),
    );

    final seen = <String>{};
    return [
      for (final batch in batches)
        for (final source in batch)
          if (seen.add(source.url.toString())) source,
    ];
  }

  static bool _looksLikeLarozaItem(String title, String path) {
    final value = '$title $path'.toLowerCase();
    if (RegExp(r'(?:الحلقة|episode|ep)\s*\d+').hasMatch(value)) return true;
    if (RegExp(r'(?:فيلم|movie|film)').hasMatch(value) && title.length > 8) {
      return true;
    }
    if (RegExp(r'(?:مسلسل|series)').hasMatch(value) && title.length > 8) {
      return true;
    }
    return false;
  }
}
