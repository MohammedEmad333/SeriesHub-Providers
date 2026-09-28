import '../../models/source_models.dart';
import 'simple_public_catalog_provider.dart';

class ElCinemaProvider extends SimplePublicCatalogProvider {
  ElCinemaProvider()
      : super(
          id: 'elcinema',
          name: 'elCinema',
          baseUri: Uri.parse('https://elcinema.com/'),
        );

  @override
  Future<List<SourcePlayback>> getPlaybackSources(String episodeId) async {
    return const [];
  }
}

class EgyBestProvider extends SimplePublicCatalogProvider {
  EgyBestProvider()
      : super(
          id: 'egibest',
          name: 'EgyBest',
          baseUri: Uri.parse('https://egibest.com/'),
        );

  @override
  Future<List<SourcePlayback>> getPlaybackSources(String episodeId) async {
    final pageUri = Uri.tryParse(episodeId);
    if (pageUri == null || !pageUri.hasScheme) return const [];

    final direct = await resolvePublicPlayback(pageUri, maxEmbeds: 6);
    if (direct.isNotEmpty) return direct;

    final html = await fetchText(pageUri);
    final candidates = <Uri>{};
    for (final match in RegExp(
      r'''href=["']([^"']*(?:watch|view|play)[^"']*)["']''',
      caseSensitive: false,
    ).allMatches(html)) {
      final value = match.group(1);
      if (value == null || value.isEmpty) continue;
      final uri = pageUri.resolve(value.replaceAll('&amp;', '&'));
      if (uri.host == pageUri.host) candidates.add(uri);
    }

    final results = await Future.wait(
      candidates.take(4).map((uri) async {
        try {
          return await resolvePublicPlayback(uri, maxEmbeds: 6);
        } on Object {
          return const <SourcePlayback>[];
        }
      }),
    );

    for (final sources in results) {
      if (sources.isNotEmpty) return sources;
    }
    return const [];
  }
}
