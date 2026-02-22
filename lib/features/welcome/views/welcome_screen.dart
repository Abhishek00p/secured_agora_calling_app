import 'package:flutter/material.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';
import 'package:secured_calling/utils/app_icon_constants.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    AppFirebaseService.instance.cleanUpServiceSecureFiles();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final padding = responsivePadding(context);
    final isLaptop = context.isLaptop;

    return Scaffold(body: SafeArea(child: isLaptop ? _buildLaptopCentered(context, padding) : _buildMobileScrollable(context, padding)));
  }

  Widget _buildLaptopCentered(BuildContext context, double padding) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight, // 👈 KEY FIX
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(padding: EdgeInsets.all(padding), child: _buildLaptopLayout(context)),
            ),
          ),
        );
      },
    );
  }

  // =========================
  // LAPTOP LAYOUT
  // =========================
  Widget _buildLaptopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // LEFT SIDE → FEATURES
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Features',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 24),
                _buildFeatureItem(context, Icons.groups_rounded, 'High-quality video meetings', 'Connect with up to 45 participants'),
                const SizedBox(height: 20),
                _buildFeatureItem(context, Icons.record_voice_over_rounded, 'Advanced audio controls', 'Speaker focus & selective muting'),
                const SizedBox(height: 20),
                _buildFeatureItem(context, Icons.screen_share_rounded, 'Seamless screen sharing', 'Present your ideas with clarity'),
                const SizedBox(height: 20),
                _buildFeatureItem(context, Icons.chat_rounded, 'Integrated chat system', 'Communicate via text during meetings'),
              ],
            ),
          ),
        ),

        const SizedBox(width: 48),

        // RIGHT SIDE → LOGO TO BUTTON
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLogo(context, size: 100),
              const SizedBox(height: 32),
              Text('SecuredCalling', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Connect. Collaborate. Create.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 32),
              _buildAboutCard(context),
              const SizedBox(height: 40),
              _buildGetStartedButton(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileScrollable(BuildContext context, double padding) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(padding: EdgeInsets.all(padding), child: _buildMobileLayout(context)),
        ),
      ),
    );
  }

  // =========================
  // MOBILE / TABLET LAYOUT
  // =========================
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        _buildLogo(context, size: 80),
        const SizedBox(height: 24),
        Text('SecuredCalling', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text('Connect. Collaborate. Create.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 32),
        _buildAboutCard(context),
        const SizedBox(height: 40),
        _buildGetStartedButton(context),
        const SizedBox(height: 48),
        _buildFeaturesCard(context),
      ],
    );
  }

  // =========================
  // REUSABLE WIDGETS
  // =========================
  Widget _buildLogo(BuildContext context, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(18)),
      child: Icon(Icons.call, size: size * 0.5, color: Colors.white),
    );
  }

  Widget _buildGetStartedButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => Navigator.pushNamed(context, AppRouter.loginRoute),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Get Started', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Icon(forwardArrow, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            'About Our Company',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'We are dedicated to creating innovative communication solutions that help teams collaborate seamlessly across distances and time zones.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          _buildFeatureItem(context, Icons.groups_rounded, 'High-quality video meetings', 'Connect with up to 45 participants'),
          const SizedBox(height: 16),
          _buildFeatureItem(context, Icons.record_voice_over_rounded, 'Advanced audio controls', 'Speaker focus & selective muting'),
          const SizedBox(height: 16),
          _buildFeatureItem(context, Icons.screen_share_rounded, 'Seamless screen sharing', 'Present your ideas with clarity'),
          const SizedBox(height: 16),
          _buildFeatureItem(context, Icons.chat_rounded, 'Integrated chat system', 'Communicate via text during meetings'),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppTheme.primaryColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(description, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
