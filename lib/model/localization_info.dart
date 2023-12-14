
import '../gsheet_localization.dart';
import 'language.dart';

class LocalizationInfo{
  List<Language> languages = [];
  Language language;
  int version;
  LocalizationSource source;
  SelectionStatus status;
  LocalizationInfo({required this.languages,required this.language, required this.version,required this.source,required this.status});
}