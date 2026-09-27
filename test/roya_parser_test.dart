import 'package:serieshub_providers/serieshub_providers.dart';
import 'package:test/test.dart';

void main() {
  const parser = RoyaParser();
  final base = Uri.parse('https://en.roya.tv/');

  test('parses Roya programs from listing links', () {
    const html = '''
      <a href="/program/2088"><img alt="Watan 3 Watar" src="/w.jpg"></a>
      <a href="/program/2088">Duplicate</a>
      <a href="/program/2124" title="Roya Mundial"></a>
    ''';

    final items = parser.parseSeriesList(html, base);

    expect(items, hasLength(2));
    expect(items.first.id, '2088');
    expect(items.first.title, 'Watan 3 Watar');
  });

  test('parses Roya video episode links', () {
    const html = '''
      <a href="/videos/100927">Episode 01</a>
      <a href="/videos/100928">Episode 02</a>
    ''';

    final episodes = parser.parseEpisodes(
      html,
      base.resolve('program/2088'),
      '2088',
    );

    expect(episodes, hasLength(2));
    expect(episodes.first.number, 1);
    expect(
      episodes.first.webUrl.toString(),
      'https://en.roya.tv/videos/100927',
    );
  });
}
