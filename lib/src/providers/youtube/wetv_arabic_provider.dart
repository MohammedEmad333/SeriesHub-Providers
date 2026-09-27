import 'package:http/http.dart' as http;

import 'youtube_channel_provider.dart';

class WeTvArabicProvider extends YouTubeChannelProvider {
  WeTvArabicProvider({http.Client? client})
      : super(
          id: 'wetv-arabic',
          name: 'WeTV Arabic',
          seedVideoId: 'W18HzMRooW8',
          fallbackTitle: 'WeTV Arabic',
          fallbackOverview: 'محتوى درامي مترجم من قناة WeTV Arabic الرسمية.',
          fallbackYear: 2025,
          client: client,
        );
}
