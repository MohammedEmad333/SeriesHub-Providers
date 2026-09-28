import 'package:html/dom.dart';

String cleanText(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

Uri decodeSeriesId(String id) {
  final decoded = Uri.decodeComponent(id);
  final uri = Uri.tryParse(decoded);
  if (uri == null || !uri.hasScheme) {
    throw ArgumentError.value(id, 'seriesId', 'Invalid catalog item id');
  }
  return uri;
}

String encodeSeriesId(Uri uri) => Uri.encodeComponent(uri.toString());

Uri? resolveImage(Element scope, Uri baseUri) {
  for (final selector in const [
    'img[data-src]',
    'img[data-lazy-src]',
    'img[src]',
    'meta[property="og:image"]',
  ]) {
    final element = scope.querySelector(selector);
    final value = element?.attributes['data-src'] ??
        element?.attributes['data-lazy-src'] ??
        element?.attributes['src'] ??
        element?.attributes['content'];
    if (value != null && value.trim().isNotEmpty) {
      return baseUri.resolve(value.trim());
    }
  }
  return null;
}

List<Uri> publicServerCandidates(
  String html,
  Document document,
  Uri pageUri, {
  Iterable<String> preferredHosts = const [],
  int limit = 12,
}) {
  final values = <String>{};
  const attrs = [
    'src',
    'data-src',
    'data-lazy-src',
    'data-url',
    'data-link',
    'data-embed',
    'data-server',
  ];

  for (final element in document.querySelectorAll(
    'iframe, [data-src], [data-url], [data-link], [data-embed], [data-server]',
  )) {
    for (final attr in attrs) {
      final value = element.attributes[attr]?.trim();
      if (value != null && value.isNotEmpty) values.add(value);
    }
  }

  for (final match in RegExp(
    r'''https?:\\?/\\?/[^"'\\s<>]+''',
    caseSensitive: false,
  ).allMatches(html)) {
    final value = match.group(0)?.replaceAll(r'\/', '/');
    if (value != null && value.isNotEmpty) values.add(value);
  }

  final hosts = preferredHosts.map((e) => e.toLowerCase()).toList();
  final uris = values
      .map((value) => pageUri.resolve(value.replaceAll('&amp;', '&')))
      .where((uri) => uri.scheme == 'http' || uri.scheme == 'https')
      .where((uri) => !RegExp(
            r'\.(?:jpg|jpeg|png|gif|webp|css|js)(?:$|\?)',
            caseSensitive: false,
          ).hasMatch(uri.toString()))
      .toList(growable: false);

  uris.sort((a, b) {
    int score(Uri uri) {
      final host = uri.host.toLowerCase();
      final index = hosts.indexWhere(
        (candidate) => host == candidate || host.endsWith('.$candidate'),
      );
      return index < 0 ? hosts.length + 1 : index;
    }
    return score(a).compareTo(score(b));
  });

  final seen = <String>{};
  return [
    for (final uri in uris)
      if (seen.add(uri.toString())) uri,
  ].take(limit).toList(growable: false);
}

int? episodeNumberFrom(String text, Uri uri) {
  final direct = RegExp(
    r'(?:الحلقة|episode|ep)\s*[-:#]?\s*(\d+)',
    caseSensitive: false,
  ).firstMatch(text)?.group(1);
  if (direct != null) return int.tryParse(direct);

  final slug = RegExp(
    r'(?:e|episode|ep)[-_]?(\d+)(?:\D|$)',
    caseSensitive: false,
  ).firstMatch(uri.path)?.group(1);
  return slug == null ? null : int.tryParse(slug);
}

Uri? resolveDocumentImage(Document document, Uri baseUri) {
  for (final selector in const [
    'meta[property="og:image"]',
    'img[data-src]',
    'img[data-lazy-src]',
    'img[src]',
  ]) {
    final element = document.querySelector(selector);
    final value = element?.attributes['content'] ??
        element?.attributes['data-src'] ??
        element?.attributes['data-lazy-src'] ??
        element?.attributes['src'];
    if (value != null && value.trim().isNotEmpty) {
      return baseUri.resolve(value.trim());
    }
  }
  return null;
}
