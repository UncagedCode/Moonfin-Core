import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/database/offline_database.dart';
import 'package:moonfin/data/providers/offline_providers.dart';

DownloadedItem _row(
  String id, {
  required String name,
  required String type,
  required int status,
  String? error,
}) => DownloadedItem(
  itemId: id,
  serverId: 'test-server',
  type: type,
  name: name,
  metadataJson: '{"Name":"$name","Type":"$type"}',
  downloadStatus: status,
  downloadProgress: 0,
  errorMessage: error,
  fileSizeBytes: 0,
  playbackPositionTicks: 0,
  progressSynced: true,
  qualityPreset: 'high1080p',
  downloadSource: 'manual',
);

void main() {
  test('the failed tab shows only real failed media, not active or completed', () {
    final rows = [
      _row('running', name: 'Downloading', type: 'Movie', status: 1),
      _row('complete', name: 'Saved', type: 'Movie', status: 2),
      _row('fail', name: 'Infinity Pool', type: 'Movie', status: 3,
          error: 'Muxer error'),
      _row('series', name: 'Show artwork', type: 'Series', status: 3),
    ];
    final failed = filterFailedDownloads(rows);
    expect(failed.map((row) => row.itemId), ['fail']);
    expect(failed.single.errorMessage, 'Muxer error');
    expect(failed.single.qualityPreset, 'high1080p');
  });

  test('failed episodes and videos are retained and sorted by title', () {
    final failed = filterFailedDownloads([
      _row('1', name: 'Zulu', type: 'Episode', status: 3),
      _row('2', name: 'alpha', type: 'Video', status: 3),
    ]);
    expect(failed.map((row) => row.itemId), ['2', '1']);
  });
}
