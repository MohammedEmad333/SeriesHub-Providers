import 'source_provider.dart';

class SourceRegistry {
  SourceRegistry(Iterable<SourceProvider> providers)
      : _providers = {for (final provider in providers) provider.id: provider};

  final Map<String, SourceProvider> _providers;

  List<SourceProvider> get all => List.unmodifiable(_providers.values);

  SourceProvider? byId(String id) => _providers[id];

  bool contains(String id) => _providers.containsKey(id);
}
