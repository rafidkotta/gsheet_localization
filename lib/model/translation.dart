import 'language.dart';

class Localization{
  late Language language;
  late List<String> data;
  Localization({required this.language, required this.data});
  Map<String,dynamic> toJson(){
    Map<String,dynamic> data = {};
    data['language'] = language.code;
    data['data'] = data;
    return data;
  }
}