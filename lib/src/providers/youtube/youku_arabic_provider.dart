import 'youtube_channel_provider.dart';

class YoukuArabicProvider extends YouTubeChannelProvider {
  YoukuArabicProvider()
      : super(
          id: 'youku-arabic',
          name: 'YOUKU Arabic',
          seedVideoId: 'FrAj1DNvraE',
          fallbackTitle: 'ذروة شبابنا',
          fallbackOverview:
              'مسلسل رومانسي شبابي منشور على قناة YOUKU Arabic الرسمية.',
          fallbackYear: 2025,
        );
}
