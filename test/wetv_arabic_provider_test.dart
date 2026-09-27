import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:serieshub_providers/serieshub_providers.dart';
import 'package:test/test.dart';

void main() {
  test('WeTV Arabic exposes four public episodes', () async {
    final provider = WeTvArabicProvider(
      client: MockClient(
        (_) async => http.Response('{"title":"Episode"}', 200),
      ),
    );

    final catalog = await provider.browse();
    final episodes = await provider.getEpisodes('wetv-filter');
    final sources = await provider.getPlaybackSources('0n_mP4qJUgY');

    expect(catalog, hasLength(1));
    expect(catalog.single.title, 'الأفلام');
    expect(episodes.map((episode) => episode.number), [1, 2, 3, 4]);
    expect(sources, hasLength(1));
    expect(sources.single.mimeType, 'video/youtube');
  });

  test('WeTV Arabic hides unavailable videos', () async {
    final provider = WeTvArabicProvider(
      client: MockClient((_) async => http.Response('not found', 404)),
    );

    expect(
      await provider.getPlaybackSources('0n_mP4qJUgY'),
      isEmpty,
    );
  });
}
