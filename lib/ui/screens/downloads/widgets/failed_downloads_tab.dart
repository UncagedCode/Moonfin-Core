import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../../data/database/offline_database.dart';
import '../../../../data/models/download_quality.dart';
import '../../../../data/providers/offline_providers.dart';
import '../../../../data/services/download_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../util/accent_folding.dart';

/// Failures are read from the offline database rather than the ephemeral
/// activeDownloads map, so a failed transcode remains visible after restart.
/// The row's original quality is used when the user explicitly retries it.
class FailedDownloadsTab extends ConsumerWidget {
  const FailedDownloadsTab({super.key, this.query = ''});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final failures = ref.watch(failedDownloadsProvider);
    return failures.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Unable to load failed downloads: $error',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColorScheme.statusRequested),
          ),
        ),
      ),
      data: (rows) {
        final needle = foldForSearch(query.trim());
        final visible = needle.isEmpty
            ? rows
            : rows.where((row) {
                return foldForSearch(row.name).contains(needle) ||
                    foldForSearch(row.seriesName ?? '').contains(needle) ||
                    foldForSearch(row.errorMessage ?? '').contains(needle);
              }).toList();

        if (visible.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                rows.isEmpty
                    ? 'No failed downloads. Any downloads that fail will appear here, with a reason and an option to retry.'
                    : l10n.savedMediaNoResults,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: visible.length,
          itemBuilder: (context, index) =>
              _failedCard(context, visible[index], l10n),
        );
      },
    );
  }

  Widget _failedCard(
    BuildContext context,
    DownloadedItem row,
    AppLocalizations l10n,
  ) {
    final quality = DownloadQuality.fromName(row.qualityPreset);
    final explanation = row.errorMessage?.trim();
    final reason = explanation == null || explanation.isEmpty
        ? 'No detailed error was recorded.'
        : explanation;
    final service = GetIt.instance.isRegistered<DownloadService>()
        ? GetIt.instance<DownloadService>()
        : null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: AppColorScheme.statusRequested),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Quality: ${quality.label}',
              style: TextStyle(
                color: AppColorScheme.onSurface.withValues(alpha: 0.65),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              'Reason: $reason',
              style: TextStyle(
                color: AppColorScheme.onSurface.withValues(alpha: 0.85),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                FilledButton.tonalIcon(
                  onPressed: service == null
                      ? null
                      : () => _retry(context, service, row),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry),
                ),
                TextButton.icon(
                  onPressed: service == null
                      ? null
                      : () => _remove(context, service, row),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.remove),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _retry(
    BuildContext context,
    DownloadService service,
    DownloadedItem row,
  ) async {
    try {
      await service.retryFailedDownload(row);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not retry download: $error')),
      );
    }
  }

  Future<void> _remove(
    BuildContext context,
    DownloadService service,
    DownloadedItem row,
  ) async {
    try {
      await service.removeFailedDownload(row);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove failed download: $error')),
      );
    }
  }
}
