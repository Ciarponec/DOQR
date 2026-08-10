import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguageController extends ChangeNotifier {
  static const _preferenceKey = 'app_language';
  static String currentLanguageCode = 'tr';

  Locale _locale = const Locale('tr');

  Locale get locale => _locale;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final languageCode = preferences.getString(_preferenceKey);
    if (languageCode != 'tr' && languageCode != 'en') return;
    _locale = Locale(languageCode!);
    currentLanguageCode = languageCode;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode != 'tr' && locale.languageCode != 'en') return;
    if (_locale.languageCode == locale.languageCode) return;
    _locale = Locale(locale.languageCode);
    currentLanguageCode = locale.languageCode;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, locale.languageCode);
  }
}

String appText(String turkish, String english) =>
    AppLanguageController.currentLanguageCode == 'en' ? english : turkish;

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope != null, 'AppLanguageScope is missing above this context.');
    return scope!.notifier!;
  }
}

extension DoqrTranslations on BuildContext {
  bool get isEnglish => Localizations.localeOf(this).languageCode == 'en';

  String tr(String turkish, String english) => isEnglish ? english : turkish;
}

class LanguagePickerButton extends StatelessWidget {
  const LanguagePickerButton({super.key, this.foregroundColor});

  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return PopupMenuButton<String>(
      tooltip: context.tr('Dil seç', 'Choose language'),
      icon: Icon(Icons.language_rounded, color: foregroundColor),
      onSelected: (value) =>
          AppLanguageScope.of(context).setLocale(Locale(value)),
      itemBuilder: (context) => [
        _languageItem('tr', 'Türkçe', languageCode),
        _languageItem('en', 'English', languageCode),
      ],
    );
  }

  PopupMenuItem<String> _languageItem(
      String value, String label, String selectedLanguageCode) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: value == selectedLanguageCode
                ? const Icon(Icons.check_rounded, size: 20)
                : null,
          ),
          Text(label),
        ],
      ),
    );
  }
}
