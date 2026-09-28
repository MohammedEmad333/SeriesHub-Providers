import 'package:html/parser.dart' as html_parser;

import '../../models/source_models.dart';
import 'simple_public_catalog_provider.dart';
import 'site_specific_helpers.dart';

/// Cima4u adapter with site-specific catalog, episode and watch-server parsing.
///
/// The generic public resolver is used only after Cima4u-specific watch/server
/// discovery. It still returns only directly exposed media and never bypasses
/// authentication, DRM, anti-bot challenges, or signed/private APIs.
class Cima4uProvider extends SimplePublicCatalogProvider {
  Cima4uProvider()
      : super(
          id: 'cima4u',
          name: 'Cima4u',
          baseUri: Uri.parse('https://c4u.top/'),
        );

  @override
  Future<List<SourceSeries>> browse({int page = 1}) async {
    final uri = page <= 1
        ? baseUri
        : baseUri.resolve('page/$page/');
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
      if (!_looksLikeCimaItem(title)) continue;

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
      final text = cleanText(anchor.text);
      final target = uri.resolve(href);
      if (target.host != baseUri.host) continue;

      final number = episodeNumberFrom(text, target);
      if (number == null || !text.contains('الحلقة')) continue;
      final key = '$number|${target.toString()}';
      if (!seen.add(key)) continue;

      episodes.add(
        SourceEpisode(
          id: target.toString(),
          seriesId: seriesId,
          number: number,
          title: text.isEmpty ? 'الحلقة $number' : text,
          webUrl: target,
          thumbnailUrl: resolveImage(anchor, uri),
        ),
      );
    }

    episodes.sort((a, b) => b.number.compareTo(a.number));
    if (episodes.isNotEmpty) return episodes;

    final fallbackNumber = episodeNumberFrom(
          cleanText(document.querySelector('h1')?.text ?? ''),
          uri,
        ) ??
        1;
    return [
      SourceEpisode(
        id: uri.toString(),
        seriesId: seriesId,
        number: fallbackNumber,
        title: cleanText(document.querySelector('h1')?.text ?? '') == ''
            ? 'الحلقة $fallbackNumber'
            : cleanText(document.querySelector('h1')!.text),
        webUrl: uri,
        thumbnailUrl: resolveImage(document, uri),
      ),
    ];
  }

  @override
  Future<List<SourcePlayback>> getPlaybackSources(String episodeId) async {
    final itemUri = Uri.tryParse(episodeId);
    if (itemUri == null || !itemUri.hasScheme) return const [];

    final watchUri = itemUri.replace(
      queryParameters: {
        ...itemUri.queryParameters,
        'wat': '1',
      },
    );
    final html = await fetchText(watchUri);
    final document = html_parser.parse(html);

    final direct = extractPlayback(html, watchUri);
    if (direct.isNotEmpty) return direct;

    final servers = publicServerCandidates(
      html,
      document,
      watchUri,
      preferredHosts: const [
        'hglink.to',
        'dood.li',
        'minochinos.com',
        'minochinos',
      ],
      limit: 10,
    );

    final batches = await Future.wait(
      servers.map((server) async {
        try {
          return await resolvePublicPlayback(server, maxEmbeds: 4);
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

  static bool _looksLikeCimaItem(String title) {
    final value = title.toLowerCase();
    if (RegExp(r'الحلقة\s*\d+').hasMatch(value)) return true;
    if (RegExp(r'(?:فيلم|movie|film).*(?:19|20)\d{2}').hasMatch(value)) {
      return true;
    }
    if (RegExp(r'(?:مسلسل|series).*(?:الموسم|الحلقة)').hasMatch(value)) {
      return true;
    }
    return false;
  }
}
