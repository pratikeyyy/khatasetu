import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../core/storage/local_storage.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      "icon": Icons.storefront_rounded,
      "title": "Welcome to KhataSetu",
      "subtitle": "From Paper Khata to Smart Digital Khata",
      "description": "Digitize your Kirana store books in seconds. Replace heavy registers with a fast, modern digital khata.",
    },
    {
      "icon": Icons.camera_enhance_rounded,
      "title": "Scan Register Pages",
      "subtitle": "AI Vision Pipeline",
      "description": "Photograph any handwritten paper khata page. Gemini AI extracts customer names, amounts, dates, and udhar/jama automatically.",
    },
    {
      "icon": Icons.verified_user_rounded,
      "title": "Intelligent Verification",
      "subtitle": "Confidence Scoring",
      "description": "High-confidence items auto-sync with 1-click batch confirm. Medium and low-confidence items are flagged for human review.",
    },
    {
      "icon": Icons.chat_rounded,
      "title": "Direct WhatsApp Reminders",
      "subtitle": "Zero Added Cost",
      "description": "Send polite, personalized payment reminders in Hindi, Hinglish, or English via wa.me direct links without third-party fees.",
    },
  ];

  Future<void> _completeOnboarding() async {
    await LocalStorage.setOnboardingSeen();
    if (mounted) {
      context.go("/login");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: const Text("Skip", style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(page["icon"] as IconData, size: 54, color: AppColors.primary),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page["title"] as String,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          page["subtitle"] as String,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.saffron),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page["description"] as String,
                          style: const TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? AppColors.primary : AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ElevatedButton(
                onPressed: () {
                  if (isLastPage) {
                    _completeOnboarding();
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Text(isLastPage ? "Get Started" : "Next"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
