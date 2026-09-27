import 'simple_public_catalog_provider.dart';

class LarozaProvider extends SimplePublicCatalogProvider {
  LarozaProvider()
      : super(
          id: 'laroza',
          name: 'Laroza',
          baseUri: Uri.parse('https://llaroza.click/'),
          homePath: 'home.24',
        );
}

class ElCinemaProvider extends SimplePublicCatalogProvider {
  ElCinemaProvider()
      : super(
          id: 'elcinema',
          name: 'elCinema',
          baseUri: Uri.parse('https://elcinema.com/'),
        );
}

class EgyBestProvider extends SimplePublicCatalogProvider {
  EgyBestProvider()
      : super(
          id: 'egibest',
          name: 'EgyBest',
          baseUri: Uri.parse('https://egibest.com/'),
        );
}

class Cima4uProvider extends SimplePublicCatalogProvider {
  Cima4uProvider()
      : super(
          id: 'cima4u',
          name: 'Cima4u',
          baseUri: Uri.parse('https://c4u.top/'),
        );
}

class DramaCafeProvider extends SimplePublicCatalogProvider {
  DramaCafeProvider()
      : super(
          id: 'dramacafe',
          name: 'DramaCafe',
          baseUri: Uri.parse('https://www.dramacafe.co/'),
        );
}
