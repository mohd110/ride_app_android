import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/order_service.dart';
import '../services/phone_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/detail_page_scaffold.dart';

/// Reads supabase/013_rider_profile_and_company_info.sql's `company_info`
/// singleton row. If that migration hasn't been applied yet,
/// fetchCompanyInfo() returns null and this shows a friendly empty state
/// instead of crashing or silently showing blank fields.
class CompanyInfoScreen extends StatefulWidget {
  const CompanyInfoScreen({Key? key}) : super(key: key);

  @override
  State<CompanyInfoScreen> createState() => _CompanyInfoScreenState();
}

class _CompanyInfoScreenState extends State<CompanyInfoScreen> {
  Map<String, dynamic>? _info;
  String _appVersion = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      OrderService().fetchCompanyInfo(),
      PackageInfo.fromPlatform(),
    ]);
    if (!mounted) return;
    setState(() {
      _info = results[0] as Map<String, dynamic>?;
      _appVersion = '${(results[1] as PackageInfo).version}+${(results[1] as PackageInfo).buildNumber}';
      _loading = false;
    });
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const DetailPageScaffold(
        title: 'Company Information',
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      );
    }

    final info = _info;
    if (info == null) {
      return DetailPageScaffold(
        title: 'Company Information',
        children: [
          AppCard(
            dashed: true,
            child: Column(
              children: const [
                Icon(Icons.business_outlined, color: AppColors.textMuted, size: 36),
                SizedBox(height: 12),
                Text(
                  'Company info unavailable',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  'This hasn\'t been set up on the backend yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('App version', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Rider Connect v$_appVersion', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      );
    }

    final companyName = (info['company_name'] as String?)?.trim();
    final logoUrl = info['company_logo_url'] as String?;
    final supportEmail = info['support_email'] as String?;
    final supportPhone = info['support_phone'] as String?;
    final officeAddress = info['office_address'] as String?;
    final workingHours = info['working_hours'] as String?;
    final aboutUs = info['about_us'] as String?;
    final terms = info['terms_and_conditions'] as String?;
    final privacy = info['privacy_policy'] as String?;

    return DetailPageScaffold(
      title: 'Company Information',
      children: [
        AppCard(
          child: Row(
            children: [
              if (logoUrl != null && logoUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(logoUrl, width: 52, height: 52, fit: BoxFit.cover),
                )
              else
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: AppColors.surfaceAccent, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 28),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  companyName?.isNotEmpty == true ? companyName! : 'Company name not set',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        if (supportPhone?.isNotEmpty == true || supportEmail?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (supportPhone?.isNotEmpty == true)
                  ListTile(
                    leading: const Icon(Icons.phone_rounded, color: AppColors.primary),
                    title: const Text('Support Phone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(supportPhone!, style: const TextStyle(fontSize: 12)),
                    onTap: () => PhoneService.call(context, supportPhone),
                  ),
                if (supportPhone?.isNotEmpty == true && supportEmail?.isNotEmpty == true) const Divider(height: 1),
                if (supportEmail?.isNotEmpty == true)
                  ListTile(
                    leading: const Icon(Icons.email_rounded, color: AppColors.primary),
                    title: const Text('Support Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(supportEmail!, style: const TextStyle(fontSize: 12)),
                    onTap: () => _openLink('mailto:$supportEmail'),
                  ),
              ],
            ),
          ),
        ],
        if (officeAddress?.isNotEmpty == true || workingHours?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (officeAddress?.isNotEmpty == true) InfoRow(label: 'Office Address', value: officeAddress!),
                if (workingHours?.isNotEmpty == true) InfoRow(label: 'Working Hours', value: workingHours!),
              ],
            ),
          ),
        ],
        if (aboutUs?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('About Us', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                Text(aboutUs!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
        if (terms?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          _legalTile('Terms & Conditions', terms!),
        ],
        if (privacy?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          _legalTile('Privacy Policy', privacy!),
        ],
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('App version', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Rider Connect v$_appVersion', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  /// terms/privacy can hold either a URL to a hosted page or inline text —
  /// open it in a browser if it looks like one, otherwise show it in a sheet.
  Widget _legalTile(String title, String value) {
    final looksLikeUrl = value.startsWith('http://') || value.startsWith('https://') || value.startsWith('www.');
    return InkWell(
      onTap: looksLikeUrl
          ? () => _openLink(value)
          : () => showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.surface,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Text(value, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
                      ],
                    ),
                  ),
                ),
              ),
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            Icon(looksLikeUrl ? Icons.open_in_new_rounded : Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
