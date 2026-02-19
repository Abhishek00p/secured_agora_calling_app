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
    final size = MediaQuery.of(context).size;
    final padding = responsivePadding(context);
    final isWide = context.isTablet || context.isLaptop;
    final logoSize = isWide ? (context.isLaptop ? 100.0 : 96.0) : 80.0;
    final maxContentWidth = isWide ? 560.0 : double.infinity;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Theme.of(context).colorScheme.surface, Theme.of(context).colorScheme.surface],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: size.height * 0.08),
                    // App Logo
                    Container(
                      width: logoSize,
                      height: logoSize,
                      decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(18)),
                      child: Icon(Icons.call, size: logoSize * 0.5, color: Colors.white),
                    ),
                    SizedBox(height: size.height * 0.04),

                    // App Name
                    Text(
                      'SecuredCalling',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // App Description
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: padding),
                      child: Text('Connect. Collaborate. Create.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                    ),
                    SizedBox(height: size.height * 0.04),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: padding),
                  padding: EdgeInsets.all(padding + 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                ),
                SizedBox(height: size.height * 0.05),

                // Get Started Button
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRouter.loginRoute);
                  },
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
                ),
                SizedBox(height: size.height * 0.08),
                // App Features Description
                Container(
                  margin: EdgeInsets.symmetric(horizontal: padding),
                  padding: EdgeInsets.all(padding + 8),
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
                ),

                // Company Description
                SizedBox(height: size.height * 0.05),
                  ],
                ),
              ),
            ),
          ),
        ),
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
