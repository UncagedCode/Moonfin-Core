import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/download_quality.dart';
import 'package:moonfin/data/services/emby_hls_download_fallback.dart';

void main() {
  group('Emby HLS download fallback', () {
    test('requests server-generated MPEG-TS HLS with H264 and AAC', () {
      final request = EmbyHlsDownloadFallback.playbackRequest(
        quality: DownloadQuality.high1080p,
        userId: 'user-123',
      );
      expect(request['UserId'], 'user-123');
      expect(request['EnableDirectPlay'], isFalse);
      expect(request['EnableDirectStream'], isFalse);
      expect(request['EnableTranscoding'], isTrue);
      expect(request['MaxStreamingBitrate'], 4192000);
      final profile = request['DeviceProfile'] as Map<String, dynamic>;
      final transcode = (profile['TranscodingProfiles'] as List).single;
      expect(transcode['Container'], 'ts');
      expect(transcode['Protocol'], 'hls');
      expect(transcode['VideoCodec'], 'h264');
      expect(transcode['AudioCodec'], 'aac');
    });

    test('resolves HLS URL while retaining existing session token', () {
      final url = EmbyHlsDownloadFallback.streamUrl(
        {
          'MediaSources': [
            {
              'TranscodingUrl':
                  '/Videos/359168/master.m3u8?api_key=secret&PlaySessionId=abc',
            },
          ],
        },
        baseUrl: 'https://example.invalid/emby',
        quality: DownloadQuality.high1080p,
      );
      final uri = Uri.parse(url!);
      expect(uri.path, '/emby/Videos/359168/master.m3u8');
      expect(uri.queryParameters['api_key'], 'secret');
      expect(uri.queryParameters['PlaySessionId'], 'abc');
      expect(uri.queryParameters['MaxWidth'], '1920');
      expect(uri.queryParameters['MaxHeight'], '1080');
    });

    test('uses the selected 720p limit and does not replace existing caps', () {
      final url = EmbyHlsDownloadFallback.streamUrl(
        {
          'MediaSources': [
            {
              'TranscodingUrl':
                  'https://example.invalid/Videos/2/master.m3u8?MaxWidth=1024',
            },
          ],
        },
        baseUrl: 'https://example.invalid',
        quality: DownloadQuality.medium720p,
      );
      final uri = Uri.parse(url!);
      expect(uri.queryParameters['MaxWidth'], '1024');
      expect(uri.queryParameters['MaxHeight'], '720');
    });

    test('never invents a URL when Emby gives no HLS offer', () {
      expect(
        EmbyHlsDownloadFallback.streamUrl(
          {
            'MediaSources': [
              {'TranscodingUrl': '/Videos/2/stream.mp4'},
            ],
          },
          baseUrl: 'https://example.invalid',
          quality: DownloadQuality.high1080p,
        ),
        isNull,
      );
      expect(
        EmbyHlsDownloadFallback.streamUrl(
          {'MediaSources': []},
          baseUrl: 'https://example.invalid',
          quality: DownloadQuality.high1080p,
        ),
        isNull,
      );
    });

    test('does not use a transcoding fallback for Original quality', () {
      expect(
        EmbyHlsDownloadFallback.streamUrl(
          {
            'MediaSources': [
              {'TranscodingUrl': '/Videos/2/master.m3u8'},
            ],
          },
          baseUrl: 'https://example.invalid',
          quality: DownloadQuality.original,
        ),
        isNull,
      );
    });
  });
}
