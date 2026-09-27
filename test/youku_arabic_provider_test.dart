import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:serieshub_providers/serieshub_providers.dart';
import 'package:test/test.dart';

void main() {
  test('YOUKU Arabic builds multiple series from the official YouTube feed',
      () async {
    final provider = YoukuArabicProvider(
      client: MockClient((request) async {
        if (request.url.path == '/watch') {
          return http.Response(
            '<html><script>{"channelId":"UC_TEST_CHANNEL"}</script></html>',
            200,
          );
        }

        if (request.url.path == '/feeds/videos.xml') {
          return http.Response(
            '''<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015">
  <entry>
    <yt:videoId>videoA1</yt:videoId>
    <title>الحب العظيم الحلقة 1 | Official</title>
  </entry>
  <entry>
    <yt:videoId>videoA2</yt:videoId>
    <title>الحب العظيم الحلقة 2 | Official</title>
  </entry>
  <entry>
    <yt:videoId>videoB1</yt:videoId>
    <title>سر المدينة الحلقة 1 | Official</title>
  </entry>
</feed>''',
            200,
          );
        }

        return http.Response('not found', 404);
      }),
    );

    final catalog = await provider.browse();

    expect(catalog, hasLength(2));
    expect(catalog.map((item) => item.title), contains('الحب العظيم'));
    expect(catalog.map((item) => item.title), contains('سر المدينة'));

    final firstSeries = catalog.firstWhere(
      (item) => item.title == 'الحب العظيم',
    );
    final episodes = await provider.getEpisodes(firstSeries.id);
    expect(episodes, hasLength(2));
    expect(episodes.map((episode) => episode.number), [1, 2]);

    final sources = await provider.getPlaybackSources(episodes.first.id);
    expect(sources, hasLength(1));
    expect(sources.single.mimeType, 'video/youtube');
    expect(sources.single.url.queryParameters['v'], 'videoA1');
  });

  test('YOUKU Arabic falls back to the seed title when the feed is unavailable',
      () async {
    final provider = YoukuArabicProvider(
      client: MockClient((_) async => http.Response('not found', 404)),
    );

    final catalog = await provider.browse();

    expect(catalog, hasLength(1));
    final episodes = await provider.getEpisodes(catalog.single.id);
    expect(episodes, hasLength(1));
    expect(
      (await provider.getPlaybackSources(episodes.single.id)).single.mimeType,
      'video/youtube',
    );
  });
}
