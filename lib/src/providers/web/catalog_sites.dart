import '../../models/source_models.dart';
import 'simple_public_catalog_provider.dart';

class LarozaProvider extends SimplePublicCatalogProvider {
  LarozaProvider()
      : super(
          id: 'laroza',
          name: 'Laroza',
          baseUri: Uri.parse('https://llaroza.click/'),
          homePath: 'home.24',
        );

  @override
  Future<List<SourcePlayback>> getPlaybackSources(String episodeId) async {
    final itemUri = Uri.tryParse(episodeId);
    if (itemUri == null || !itemUri.hasScheme) return const [];

    final direct = await resolvePublicPlayback(itemUri, maxEmbeds: 8);
    if (direct.isNotEmpty) return direct;

    // Laroza pages may expose a separate public watch/player/server route.
    // Follow same-site candidates only, then use the shared direct-media
    // resolver without bypassing protected player flows.
    final html = await fetchText(itemUri);
    final candidates = <Uri>{};
    for (final match in RegExp(
      r'''href=["']([^"']*(?:watch|player|video|server|play)[^"']*)["']''',
      caseSensitive: false,
    ).allMatches(html)) {
      final value = match.group(1);
      if (value == null || value.isEmpty) continue;
      final uri = itemUri.resolve(value.replaceAll('&amp;', '&'));
      if (uri.host == itemUri.host) candidates.add(uri);
    }

    final candidateResults = await Future.wait(
      candidates.take(4).map((uri) async {
        try {
          return await resolvePublicPlayback(uri, maxEmbeds: 6);
        } on Object {
          return const <SourcePlayback>[];
        }
      }),
    );

    for (final sources in candidateResults) {
      if (sources.isNotEmpty) return sources;
    }
    return const [];
  }
}

class ElCinemaProvider extends SimplePublicCatalogProvider {
  ElCinemaProvider()
      : super(
          id: 'elcinema',
          name: 'elCinema',
          baseUri: Uri.parse('https://elcinema.com/'),
        );

  @override
  Future<List<SourcePlayback>> getPlaybackSources(String episodeId) async {
    // elCinema is primarily a metadata and viewing-guide source. Its work
    // pages point users to external platforms rather than exposing a stable
    // first-party stream, so SeriesHub must not treat those platform links as
    // direct video URLs.
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

    // EgyBest commonly separates item and watch pages. Follow only public
    // same-site watch routes and let the shared resolver inspect public media.
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

    for (final uri in candidates.take(4)) {
      final sources = await resolvePublicPlayback(uri, maxEmbeds: 6);
      if (sources.isNotEmpty) return sources;
    }
    return const [];
  }
}

class Cima4uProvider extends SimplePublicCatalogProvider {
  Cima4uProvider()
      : super(
          id: 'cima4u',
          name: 'Cima4u',
          baseUri: Uri.parse('https://c4u.top/'),
        );

  @override
  Future<List<SourcePlayback>> getPlaybackSources(String episodeId) async {
    final itemUri = Uri.tryParse(episodeId);
    if (itemUri == null || !itemUri.hasScheme) return const [];

    // Cima4u exposes a dedicated public watch page using ?wat=1.
    final watchUri = itemUri.replace(
      queryParameters: {
        ...itemUri.queryParameters,
        'wat': '1',
      },
    );

    final watchSources = await resolvePublicPlayback(watchUri, maxEmbeds: 8);
    if (watchSources.isNotEmpty) return watchSources;

    return resolvePublicPlayback(itemUri, maxEmbeds: 4);
  }
}

class DramaCafeProvider extends SimplePublicCatalogProvider {
  DramaCafeProvider()
      : super(
          id: 'dramacafe',
          name: 'DramaCafe',
          baseUri: Uri.parse('https://www.dramacafe.co/'),
        );

  @override
  Future<List<SourcePlayback>> getPlaybackSources(String episodeId) async {
    final watchUri = Uri.tryParse(episodeId);
    if (watchUri == null || !watchUri.hasScheme) return const [];

    // DramaCafe watch pages expose the player on the /watch/ route. Inspect
    // public embeds and media declarations with a larger server allowance.
    return resolvePublicPlayback(watchUri, maxEmbeds: 8);
  }
}
