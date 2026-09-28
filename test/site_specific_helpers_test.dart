import 'package:html/parser.dart' as html_parser;
import 'package:serieshub_providers/src/providers/web/site_specific_helpers.dart';
import 'package:test/test.dart';

void main() {
  group('site-specific provider helpers', () {
    test('series ids round-trip absolute URLs', () {
      final uri = Uri.parse(
        'https://example.com/watch/show-1?episode=12&lang=ar',
      );

      expect(decodeSeriesId(encodeSeriesId(uri)), uri);
    });

    test('episode number is parsed from Arabic titles', () {
      final uri = Uri.parse('https://example.com/watch/show');

      expect(episodeNumberFrom('الحلقة 36 مترجمة', uri), 36);
    });

    test('episode number falls back to URL slug', () {
      final uri = Uri.parse('https://example.com/watch/show-e12');

      expect(episodeNumberFrom('مشاهدة الآن', uri), 12);
    });

    test(
      'public server candidates include lazy embeds and prefer known hosts',
      () {
      const html = '''
        <html>
          <body>
            <iframe data-src="https://slow.example/embed/1"></iframe>
            <button data-server="https://preferred.example/embed/2"></button>
            <script>
              const backup = "https://backup.example/embed/3";
            </script>
          </body>
        </html>
      ''';
      final document = html_parser.parse(html);
      final pageUri = Uri.parse('https://catalog.example/watch/episode');

      final result = publicServerCandidates(
        html,
        document,
        pageUri,
        preferredHosts: const ['preferred.example'],
      );

        expect(result.map((uri) => uri.host), contains('slow.example'));
        expect(result.map((uri) => uri.host), contains('backup.example'));
        expect(result.first.host, 'preferred.example');
      },
    );

    test('public server candidates ignore obvious static assets', () {
      const html = '''
        <html>
          <body>
            <iframe src="https://cdn.example/player.js"></iframe>
            <iframe src="https://video.example/embed/1"></iframe>
          </body>
        </html>
      ''';
      final document = html_parser.parse(html);

      final result = publicServerCandidates(
        html,
        document,
        Uri.parse('https://catalog.example/watch/episode'),
      );

      expect(
        result.any((uri) => uri.path.endsWith('.js')),
        isFalse,
      );
      expect(
        result.any((uri) => uri.host == 'video.example'),
        isTrue,
      );
    });

    test('document poster resolver handles og:image', () {
      const html = '''
        <html>
          <head>
            <meta property="og:image" content="/images/poster.jpg">
          </head>
        </html>
      ''';
      final document = html_parser.parse(html);

      expect(
        resolveDocumentImage(
          document,
          Uri.parse('https://catalog.example/show/1'),
        ),
        Uri.parse('https://catalog.example/images/poster.jpg'),
      );
    });
  });
}
