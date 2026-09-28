import 'package:html/parser.dart' as html_parser;

import '../../models/source_models.dart';
import 'simple_public_catalog_provider.dart';
import 'site_specific_helpers.dart';

/// Dedicated DramaCafe provider.
///
/// DramaCafe exposes episode pages under /watch/. This adapter treats those
/// pages as first-class episodes and discovers playback servers from the watch
/// page before falling back to the shared direct-media parser.
class DramaCafeProvider extends SimplePublicCatalogProvider {
  DramaCafeProvider()
      : super(
          id: 'dramacafe',
          name: 'DramaCafe',
          baseUri: Uri.parse('https://www.dramacafe.co/'),
          homePath: 'moslslat',
        );

  @override
  Future<List<SourceSeries>> browse({int page = 1}) async {
    final uri = page <= 1
        ? baseUri.resolve('moslslat')
        : baseUri.resolve('moslslat?page=$page');
    final html = await fetchText(uri);
    final document = html_parser.parse(html);
    final items = <SourceSeries>[];
    final seen = <String>{};

    for (final anchor in document.querySelectorAll('a[href*="/watch/"]')) {
      final href = anchor.attributes['href'];
      if (href == null || href.isEmpty) continue;
      final target = uri.resolve(href);
      if (target.host != baseUri.host) continue;

      final title = cleanText(
        anchor.attributes['title'] ??
            anchor.querySelector('img')?.attributes['alt'] ??
            anchor.text,
      );
      if (!_looksLikeWatchTitle(title)) continue;

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

    for (final anchor in document.querySelectorAll('a[href*="/watch/"]')) {
      final href = anchor.attributes['href'];
      if (href == null || href.isEmpty) continue;
      final target = uri.resolve(href);
      if (target.host != baseUri.host) continue;

      final text = cleanText(anchor.text);
      final number = episodeNumberFrom(text, target);
      if (number == null) continue;

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
    final watchUri = Uri.tryParse(episodeId);
    if (watchUri == null || !watchUri.hasScheme) return const [];

    final html = await fetchText(watchUri);
    final document = html_parser.parse(html);

    final direct = extractPlayback(html, watchUri);
    if (direct.isNotEmpty) return direct;

    final servers = publicServerCandidates(
      html,
      document,
      watchUri,
      preferredHosts: const [
        'vidtube.one',
        'streamwish.to',
        'filelions.to',
        'dood.li',
        'voe.sx',
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

  static bool _looksLikeWatchTitle(String title) {
    final value = title.toLowerCase();
    return value.contains('مشاهدة') &&
        (value.contains('مسلسل') ||
            value.contains('فيلم') ||
            value.contains('انمي') ||
            value.contains('anime'));
  }
}
