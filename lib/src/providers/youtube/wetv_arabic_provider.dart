import 'youtube_channel_provider.dart';

class WeTvArabicProvider extends YouTubeChannelProvider {
  WeTvArabicProvider()
      : super(
          id: 'wetv-arabic',
          name: 'WeTV Arabic',
          seedVideoId: 'W18HzMRooW8',
          fallbackTitle: 'WeTV Arabic',
          fallbackOverview:
              'محتوى درامي مترجم من قناة WeTV Arabic الرسمية.',
          fallbackYear: 2025,
        );
}
