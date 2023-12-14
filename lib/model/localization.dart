import 'package:flutter/material.dart';

import '../gsheet_localization.dart';

class TranslationLocalization {
  final Locale locale;

  TranslationLocalization(this.locale);

  static TranslationLocalization? of(BuildContext context) => Localizations.of<TranslationLocalization>(context, TranslationLocalization);

  static const LocalizationsDelegate<TranslationLocalization> delegate = _AppLocalizationsDelegate();

  String _translate(String key) {
    var trans = GSheetLocalization.translate(key,languageCode: locale.languageCode);
    return trans;
  }

  /// Context is optional but must give if it is available
  /// In-order to update texts without calling setState();
  /// Made it option to use in other places also where context is unavailable.
  static String translate(String key,{BuildContext? context}) {
    if(context != null){
      return TranslationLocalization.of(context)!._translate(key);
    }
    return GSheetLocalization.translate(key);
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<TranslationLocalization> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    bool isSupported = false;
    if(GSheetLocalization.languages.isNotEmpty){
      for (var element in GSheetLocalization.languages) {
        if(element.code == locale.languageCode){
          isSupported = true;
          break;
        }
      }
    }else{
      isSupported = true;
    }
    return isSupported;
  }

  @override
  Future<TranslationLocalization> load(Locale locale) async {
    return TranslationLocalization(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}