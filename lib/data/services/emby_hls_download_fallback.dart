import '../models/download_quality.dart';

/// Builds the Emby HLS playback offer used only when an Android MP4 transmux
/// fails. This follows the server-generated TranscodingUrl path rather than
/// constructing an unvalidated /Videos/{id}/stream URL.
class EmbyHlsDownloadFallback {
  const EmbyHlsDownloadFallback._();

  static Map<String, dynamic> playbackRequest({
    required DownloadQuality quality,
    required String? userId,
  }) {
    final rate = quality.totalBitRate;
    if (rate == null) {
      throw ArgumentError('An HLS fallback requires a transcoded quality');
    }
    return <String, dynamic>{
      if (userId != null) 'UserId': userId,
      'IsPlayback': true,
      'EnableDirectPlay': false,
      'EnableDirectStream': false,
      'EnableTranscoding': true,
      'MaxStreamingBitrate': rate,
      'DeviceProfile': <String, dynamic>{
        'Name': 'Moonfin Android HLS Download',
        'MaxStaticBitrate': rate,
        'MaxStreamingBitrate': rate,
        'DirectPlayProfiles': <dynamic>[],
        'DirectStreamProfiles': <dynamic>[],
        'TranscodingProfiles': <Map<String, dynamic>>[
          <String, dynamic>{
            'Type': 'Video',
            'Container': 'ts',
            'Protocol': 'hls',
            'VideoCodec': 'h264',
            'AudioCodec': 'aac',
            'MaxAudioChannels': '2',
          },
        ],
        'SubtitleProfiles': <dynamic>[],
        'CodecProfiles': <dynamic>[],
        'ContainerProfiles': <dynamic>[],
        'ResponseProfiles': <dynamic>[],
      },
    };
  }

  /// Resolves only a server-supplied HLS URL; a missing offer must not be
  /// replaced with a guessed URL that may return HTTP 400 or the source file.
  static String? streamUrl(
    Map<String, dynamic> playbackInfo, {
    required String baseUrl,
    required DownloadQuality quality,
  }) {
    if (!quality.isTranscoded) return null;
    final sources = playbackInfo['MediaSources'];
    if (sources is! List) return null;
    String? rawUrl;
    for (final source in sources) {
      if (source is! Map) continue;
      final candidate = source['TranscodingUrl'];
      if (candidate is! String || candidate.isEmpty) continue;
      if (!Uri.parse(candidate).path.toLowerCase().endsWith('.m3u8')) continue;
      rawUrl = candidate;
      break;
    }
    if (rawUrl == null) return null;

    final base = baseUrl.replaceFirst(RegExp(r'/$'), '');
    final resolved = rawUrl.startsWith('https://') ||
            rawUrl.startsWith('http://')
        ? rawUrl
        : rawUrl.startsWith('/')
            ? '$base$rawUrl'
            : '$base/$rawUrl';
    final uri = Uri.tryParse(resolved);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    final params = Map<String, String>.from(uri.queryParameters);
    final maxWidth = quality.maxWidth;
    if (maxWidth != null &&
        !params.keys.any((key) => key.toLowerCase() == 'maxwidth')) {
      params['MaxWidth'] = '$maxWidth';
    }
    final maxHeight = switch (quality) {
      DownloadQuality.high1080p => 1080,
      DownloadQuality.medium720p => 720,
      DownloadQuality.low480p => 480,
      DownloadQuality.mobile360p => 360,
      DownloadQuality.original => null,
    };
    if (maxHeight != null &&
        !params.keys.any((key) => key.toLowerCase() == 'maxheight')) {
      params['MaxHeight'] = '$maxHeight';
    }
    return uri.replace(queryParameters: params).toString();
  }
}
