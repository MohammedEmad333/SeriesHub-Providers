import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:serieshub_providers/serieshub_providers.dart';
import 'package:test/test.dart';

void main() {
  test('official YouTube catalog exposes verified MangoTV episodes', () async {
    final provider = OfficialYouTubeProvider(
      client: MockClient((request) async {
        return http.Response('{"title":"Episode 1"}', 200);
      }),
    );

    final catalog = await provider.browse();
    final episodes = await provider.getEpisodes(
      'mangotv-unforgettable-love',
    );
    final sources = await provider.getPlaybackSources('7HID7fAylyg');

    expect(catalog, hasLength(1));
    expect(catalog.single.title, 'حب لا يُنسى');
    expect(episodes, hasLength(3));
    expect(episodes.first.number, 1);
    expect(sources, hasLength(1));
    expect(sources.single.mimeType, 'video/youtube');
  });

  test('private or unavailable YouTube videos are not exposed', () async {
    final provider = OfficialYouTubeProvider(
      client: MockClient((request) async => http.Response('not found', 404)),
    );

    final sources = await provider.getPlaybackSources('7HID7fAylyg');

    expect(sources, isEmpty);
  });

  test('unknown video ids are rejected without a request', () async {
    var requested = false;
    final provider = OfficialYouTubeProvider(
      client: MockClient((request) async {
        requested = true;
        return http.Response('{"title":"Unexpected"}', 200);
      }),
    );

    final sources = await provider.getPlaybackSources('unknown');

    expect(sources, isEmpty);
    expect(requested, isFalse);
  });
}
