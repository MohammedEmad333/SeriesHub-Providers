import 'package:http/http.dart' as http;

import 'youtube_channel_provider.dart';

class OfficialYouTubeProvider extends YouTubeChannelProvider {
  OfficialYouTubeProvider({http.Client? client})
      : super(
          id: 'official-youtube',
          name: 'YouTube الرسمي',
          seedVideoId: '7HID7fAylyg',
          fallbackTitle: 'حب لا يُنسى',
          fallbackOverview:
              'مسلسل اجتماعي رومانسي منشور على قناة MangoTV Arabic الرسمية.',
          fallbackYear: 2021,
          client: client,
        );
}
