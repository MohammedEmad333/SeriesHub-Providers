import '../models/source_models.dart';

abstract interface class SourceProvider {
  String get id;
  String get name;
  Uri get baseUri;

  Future<List<SourceSeries>> browse({int page = 1});
  Future<List<SourceSeries>> search(String query);
  Future<SourceSeries> getSeries(String seriesId);
  Future<List<SourceEpisode>> getEpisodes(String seriesId);

  /// Returns only playback resources that are publicly exposed or otherwise
  /// authorized for the current user. Implementations must not bypass DRM,
  /// authentication, paywalls, or other access controls.
  Future<List<SourcePlayback>> getPlaybackSources(String episodeId);
}
