import 'package:serieshub_providers/serieshub_providers.dart';
import 'package:test/test.dart';

void main() {
  const parser = WatanFlixParser();
  final base = Uri.parse('https://www.watanflix.com/ar/');

  test('parses unique series links from a listing', () {
    const html = '''
      <a href="/ar/series/series-one">
        <img src="/img/one.jpg" alt="المسلسل الأول">
      </a>
      <a href="/ar/series/series-one">duplicate</a>
      <a href="/ar/series/series-two" title="المسلسل الثاني"></a>
    ''';

    final items = parser.parseSeriesList(html, base);

    expect(items, hasLength(2));
    expect(items.first.id, 'series-one');
    expect(items.first.title, 'المسلسل الأول');
    expect(
      items.first.posterUrl.toString(),
      'https://www.watanflix.com/img/one.jpg',
    );
  });

  test('parses series metadata and episodes', () {
    const html = '''
      <main>
        <h1>سكان الريح</h1>
        <div class="description">مسلسل درامي</div>
        <div class="series-poster"><img src="/covers/wind.jpg"></div>
        <a href="/ar/type/دراما">دراما</a>
        <span>1992</span>
        <a href="/ar/episode/wind-1">سكان الريح الحلقة 1</a>
        <a href="/ar/episode/wind-2">سكان الريح الحلقة 2</a>
      </main>
    ''';
    final uri = base.resolve('series/wind');

    final series = parser.parseSeries(html, uri);
    final episodes = parser.parseEpisodes(html, uri, 'wind');

    expect(series.title, 'سكان الريح');
    expect(series.year, 1992);
    expect(series.genres, contains('دراما'));
    expect(episodes.map((item) => item.number), [1, 2]);
  });
}
