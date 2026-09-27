import 'dart:convert';
import 'dart:io';

void main() {
  final repo = _readJson('repo.json');
  final index = _readJson('index.json');
  final minIndex = _readJson('index.min.json');

  final meta = repo['meta'];
  if (meta is! Map || meta['index'] != 'index.min.json') {
    _fail('repo.json meta.index must point to index.min.json');
  }

  if (index['version'] != 1 || minIndex['version'] != 1) {
    _fail('Unsupported repository index version');
  }

  final providers = index['providers'];
  final minProviders = minIndex['providers'];
  if (providers is! List || minProviders is! List) {
    _fail('providers must be a list');
  }

  if (jsonEncode(providers) != jsonEncode(minProviders)) {
    _fail('index.json and index.min.json provider lists differ');
  }

  final ids = <String>{};
  for (final value in providers) {
    if (value is! Map<String, dynamic>) {
      _fail('Each provider must be an object');
    }

    final id = value['id'];
    final manifestPath = value['manifest'];
    if (id is! String || id.isEmpty || !ids.add(id)) {
      _fail('Provider IDs must be unique non-empty strings');
    }
    if (manifestPath is! String || manifestPath.isEmpty) {
      _fail('Provider $id is missing manifest');
    }

    final manifest = _readJson(manifestPath);
    if (manifest['id'] != id) {
      _fail('Manifest ID mismatch for $id');
    }

    final entrypoint = manifest['entrypoint'];
    if (entrypoint is! Map || entrypoint['type'] != 'builtin') {
      _fail('Provider $id must use a builtin entrypoint');
    }
  }

  stdout.writeln('Repository metadata valid: ${ids.length} providers.');
}

Map<String, dynamic> _readJson(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('Missing $path');

  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) _fail('$path must contain an object');
  return decoded;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
