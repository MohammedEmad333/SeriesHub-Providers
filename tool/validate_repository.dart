import 'dart:convert';
import 'dart:io';

void main() {
  final repo = _readMap('repo.json');
  final index = _readList('index.json');
  final minIndex = _readList('index.min.json');

  final meta = repo['meta'];
  if (meta is! Map) {
    _fail('repo.json must contain meta');
  }

  for (final key in ['name', 'website', 'signingKeyFingerprint']) {
    if (meta[key] is! String || (meta[key] as String).isEmpty) {
      _fail('repo.json meta.$key must be a non-empty string');
    }
  }

  if (jsonEncode(index) != jsonEncode(minIndex)) {
    _fail('index.json and index.min.json differ');
  }

  final ids = <String>{};
  final packages = <String>{};

  for (final value in index) {
    if (value is! Map<String, dynamic>) {
      _fail('Each extension entry must be an object');
    }

    final id = value['id'];
    final pkg = value['pkg'];
    final manifestPath = value['manifest'];
    final sources = value['sources'];

    if (id is! String || id.isEmpty || !ids.add(id)) {
      _fail('Extension ids must be unique non-empty strings');
    }

    if (pkg is! String || pkg.isEmpty || !packages.add(pkg)) {
      _fail('Extension packages must be unique non-empty strings');
    }

    if (value['artifact'] != 'builtin') {
      _fail('Extension $id must use artifact=builtin');
    }

    if (manifestPath is! String || manifestPath.isEmpty) {
      _fail('Extension $id is missing manifest');
    }

    if (sources is! List || sources.isEmpty) {
      _fail('Extension $id must declare at least one source');
    }

    for (final source in sources) {
      if (source is! Map<String, dynamic>) {
        _fail('Extension $id has an invalid source entry');
      }
      for (final key in ['name', 'lang', 'id', 'baseUrl']) {
        if (source[key] is! String || (source[key] as String).isEmpty) {
          _fail('Extension $id source.$key must be a non-empty string');
        }
      }
    }

    final manifest = _readMap(manifestPath);
    if (manifest['id'] != id) {
      _fail('Manifest ID mismatch for $id');
    }

    final entrypoint = manifest['entrypoint'];
    if (entrypoint is! Map || entrypoint['type'] != 'builtin') {
      _fail('Extension $id must use a builtin entrypoint');
    }
  }

  stdout.writeln(
    'Repository metadata valid: ${ids.length} movie/series sources.',
  );
}

Map<String, dynamic> _readMap(String path) {
  final decoded = _readJson(path);
  if (decoded is! Map<String, dynamic>) {
    _fail('$path must contain an object');
  }
  return decoded;
}

List<dynamic> _readList(String path) {
  final decoded = _readJson(path);
  if (decoded is! List) {
    _fail('$path must contain an array');
  }
  return decoded;
}

dynamic _readJson(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('Missing $path');
  return jsonDecode(file.readAsStringSync());
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
