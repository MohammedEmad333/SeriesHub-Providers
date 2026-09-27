import 'package:serieshub_providers/serieshub_providers.dart';
import 'package:test/test.dart';

void main() {
  group('WatanFlixProvider playback', () {
    final provider = WatanFlixProvider();

    test('exposes public YouTube episode URLs', () async {
      final sources = await provider.getPlaybackSources(
        'https://www.youtube.com/watch?v=46qq_acRd5g',
      );

      expect(sources, hasLength(1));
      expect(sources.single.label, 'YouTube');
      expect(sources.single.mimeType, 'video/youtube');
      expect(
        sources.single.url.toString(),
        'https://www.youtube.com/watch?v=46qq_acRd5g',
      );
    });

    test('does not expose unknown playback hosts', () async {
      final sources = await provider.getPlaybackSources(
        'https://example.com/private-player/123',
      );

      expect(sources, isEmpty);
    });
  });
}
