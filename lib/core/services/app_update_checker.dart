import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateChecker {
  // Google Play Store Package Name or URL
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.pgi.examprep';
  static const String fallbackReleaseUrl = 'https://github.com/unfilteredpodcast011-del/test11-official/releases/tag/v1.0.0';

  static Future<void> checkAppUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;

      // Query latest minimum version / build code from Supabase
      // Table: 'payments' or remote config row with status: 'app_version_control'
      final res = await Supabase.instance.client
          .from('payments')
          .select('amount_paise, razorpay_order_id')
          .eq('status', 'app_version_control')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      int latestRequiredBuildNumber = 1;
      String updateNotes = 'A mandatory update with new mock tests and bug fixes is available on Google Play Store.';
      String targetUrl = playStoreUrl;

      if (res != null) {
        latestRequiredBuildNumber = (res['amount_paise'] as num?)?.toInt() ?? 1;
        final notes = res['razorpay_order_id']?.toString();
        if (notes != null && notes.isNotEmpty) {
          updateNotes = notes;
        }
      }

      if (latestRequiredBuildNumber > currentBuildNumber && context.mounted) {
        _showMandatoryUpdateDialog(context, latestRequiredBuildNumber, updateNotes, targetUrl);
      }
    } catch (e) {
      debugPrint('App update check note: $e');
    }
  }

  static void _showMandatoryUpdateDialog(
    BuildContext context,
    int latestBuild,
    String notes,
    String url,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false, // Cannot dismiss without updating
      builder: (ctx) => PopScope(
        canPop: false, // Block Android back button completely until user updates
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.system_update_rounded, color: Color(0xFF1E3A8A), size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Update Required',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.rocket_launch_rounded, color: Color(0xFF1E3A8A), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'A newer version of ExamPrep is available on Google Play Store!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                notes,
                style: const TextStyle(fontSize: 13.5, height: 1.4, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please update now to continue taking tests and viewing live results.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          actions: [
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(url);
                final fallbackUri = Uri.parse(fallbackReleaseUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.download_rounded, color: Colors.white),
              label: const Text('Update on Play Store'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

