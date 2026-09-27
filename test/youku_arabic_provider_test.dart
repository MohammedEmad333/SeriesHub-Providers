import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:serieshub_providers/serieshub_providers.dart';
import 'package:test/test.dart';

void main() {
  test('YOUKU Arabic exposes full public episodes', () async {
    final provider = YoukuArabicProvider(
      client: MockClient(
        (_) async => http.Response('{"title":"Episode"}', 200),
      ),
    );

    final catalog = await provider.browse();
    final episodes = await provider.getEpisodes('youku-fall-in-love');
    final sources = await provider.getPlaybackSources('xlDRAZOQZyk');

    expect(catalog, hasLength(1));
    expect(catalog.single.title, 'الحب من أول نظرة');
    expect(episodes.map((episode) => episode.number), [1, 2, 3]);
    expect(sources, hasLength(1));
    expect(sources.single.mimeType, 'video/youtube');
  });

  test('YOUKU Arabic hides unavailable videos', () async {
    final provider = YoukuArabicProvider(
      client: MockClient((_) async => http.Response('not found', 404)),
    );

    expect(
      await provider.getPlaybackSources('xlDRAZOQZyk'),
      isEmpty,
    );
  });
}
