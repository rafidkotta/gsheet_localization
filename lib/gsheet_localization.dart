library gsheet_localization;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gsheets/gsheets.dart';
import '/model/config.dart';
import 'model/localization_info.dart';
import 'model/translation.dart';
import 'persist.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model/credential.dart';
import 'model/language.dart';

enum LocalizationSource{nil,asset,local,sheet}
enum SelectionStatus{nil,init,persist,manual}

class GSheetLocalization {
  static final Persist _persistStore = Persist.init();
  static final Map<String,Localization> _localizations = {};
  static final Map<String,dynamic> _configs = {};
  static List<String> _base = [];
  static LocalizationSource source = LocalizationSource.nil;
  static SelectionStatus status = SelectionStatus.nil;
  static String _selectedLanguage = "en";
  static Credential? _credential;
  static int version = 0;
  static Config _config = Config.empty();
  static _init({bool? loadFromAssets,String? initialLanguage,Function(LocalizationInfo)? onUpdate,Map<String,dynamic>? asset})async{
    if(loadFromAssets != null){
      if(loadFromAssets){
        await _loadFromAsset(onUpdate: onUpdate,asset: asset);
      }
    }
    if(initialLanguage != null){
      Language language = Language.fromCode(initialLanguage);
      if(language.code != ""){
        _updateSelectedLanguage(language: language,type: SelectionStatus.init);
      }else{
        _updateSelectedLanguage(language: Language.fromCode("en"),type: SelectionStatus.init);
      }
    }
    if(_config.persist){
      await _readLanguage();
      await _loadLocalizationsFromLocal(onUpdate: onUpdate);
    }else{
      await _loadFromSheet(_credential!, _config.sheetId,onUpdate:onUpdate);
      await _loadConfigurations();
    }
  }
  GSheetLocalization.init({required Credential credential,required String sheetId,required String worksheetTitle,required int baseColumn,String? initialLanguage,bool? persist,bool? loadFromAssets,int? languageRow,int? startRow,int? startColumn,bool? printLogs,int? configColumn,Map<String,dynamic>? asset}){
    _config = Config(baseColumn: baseColumn, initialLanguage: initialLanguage ?? "en", persist: persist ?? false, sheetId: sheetId, printLogs: printLogs ?? true, startRow: startRow ?? 2, startColumn: startColumn ?? 2, languageRow: languageRow ?? 1, worksheetTitle: worksheetTitle, configColumn: configColumn ?? 0);
    _credential = credential;
    _config.sheetId = sheetId;
    _init(loadFromAssets: loadFromAssets,initialLanguage: initialLanguage,asset: asset);
  }
  /// Loads data from local only.
  static loadFromLocal({Map<String, dynamic>? asset})async{
    await _loadFromAsset(asset: asset);
    await _loadLocalizationsFromLocal();
    _readLanguage();
  }
  /// Updates [language] with provided [language].
  static set language(Language language){
    if(language.code != ""){
      _updateSelectedLanguage(language: language,type: SelectionStatus.manual);
      if(_config.persist){
        _storeLanguage();
      }
    }
  }
  /// Returns current selected [Language].
  static Language get language{
    return Language.fromCode(_selectedLanguage);
  }
  /// Returns list [Language] available in [_localizations].
  static List<Language> get languages{
    List<Language> languages = [];
    for (var element in _localizations.keys) {
      languages.add(Language.fromCode(element));
    }
    return languages;
  }
  /// Syncs data with [GSheets] also validates with [version] if [latest] is provided in parameter.
  static Future<LocalizationInfo> reload({int? latest}) async {
    if(latest != null){
      if(latest > version){
        await _loadFromSheet(_credential!, _config.sheetId);
        await _loadConfigurations();
      }
    }else{
      await _loadFromSheet(_credential!, _config.sheetId);
      await _loadConfigurations();
    }
    return LocalizationInfo(languages: languages, language: language, version: version, source: source, status: status);
  }

  static Future<LocalizationInfo> asyncInit({required Credential credential,required String sheetId,required String worksheetTitle,required int baseColumn,String? initialLanguage,bool? persist,bool? loadFromAssets,int? languageRow,int? startRow,int? startColumn,bool? printLogs,int? configColumn,Function(LocalizationInfo)? onUpdate,Map<String,dynamic>? asset})async{
    _config = Config(baseColumn: baseColumn, initialLanguage: initialLanguage ?? "en", persist: persist ?? false, sheetId: sheetId, printLogs: printLogs ?? true, startRow: startRow ?? 2, startColumn: startColumn ?? 2, languageRow: languageRow ?? 1, worksheetTitle: worksheetTitle, configColumn: configColumn ?? 0);
    _credential = credential;
    await _init(loadFromAssets: loadFromAssets,initialLanguage: initialLanguage,onUpdate: onUpdate,asset: asset);
    return LocalizationInfo(languages: languages, language: language, version: version, source: source, status: status);
  }


  /// Looks up for key in [_base] if found returns [String] at corresponding position of [Localization.data].
  static String translate(String key,{String? languageCode,String? baseLanguage}){
    int index = _getIndex(key,baseLanguage: baseLanguage);
    if(languageCode != null){
      if(index != -1){
        return _localizations[languageCode]!.data[index];
      }
    }else{
      if(index != -1){
        if(_localizations.containsKey(_selectedLanguage)){
          return _localizations[_selectedLanguage]!.data[index];
        }
      }
    }
    return key;
  }

  /// Loads [_base] and [_localizations] from [GSheets].
  static Future<void> _loadFromSheet(Credential credential,String sheetId, {Function(LocalizationInfo)? onUpdate})async{
    try{
      var newBase = await _loadBase();
      if(newBase != null && newBase.isNotEmpty){
        var Localizations = await _getLanguages();
        if(Localizations != null && Localizations.isNotEmpty){
          final Map<String,Localization> newLocalizations = {};
          Localizations.forEach((langCode, Localization) {
            if(newBase.length == Localization.data.length){
              newLocalizations[langCode] = Localization;
            }else{
              printLog("Localization Error : Localization count mismatch for ${Localization.language.name}  => base count : ${newBase.length} & Localization count : ${Localization.data.length}");
              return;
            }
          });
          _base = newBase;
          printLog("Base loaded from sheets => size : ${_base.length}");
          newLocalizations.forEach((key, value) {
            _localizations[key] = value;
            printLog("${value.language.name} loaded from sheets => size : ${value.data.length}");
          });
          source = LocalizationSource.sheet;
          if(_config.persist){
            await _persistStore.setData("Localizations", _getLocalizationJSON());
          }
          if(onUpdate != null){
            onUpdate(LocalizationInfo(languages: languages, language: language, version: version, source: source, status: status));
          }
        }
      }
    }catch(ex){
      printLog("Localization Error : Load from Sheets => ${ex.toString()}");
    }
  }

  /// Updates [_selectedLanguage] with new [Language] if new [SelectionStatus] if above [status].
  static _updateSelectedLanguage({required SelectionStatus type, required Language language}){
    if(type.index >= status.index){
      _selectedLanguage = language.code;
      status = type;
    }
  }

  /// Returns worksheet from [GSheets] using [_credential], [_config.sheetId] and [_config.worksheetTitle].
  static Future<Worksheet?> _getWorkSheet({String? workSheet})async{
    var sheet = await GSheets(_credential!.toJson()).spreadsheet(_config.sheetId);
    return sheet.worksheetByTitle(workSheet ?? _config.worksheetTitle);
  }
  /// Searches for key in [_base] and and returns position if found.
  /// else looks up in entire [Localization.data] available in [_localizations] and returns position if found.
  /// else returns [-1] if not found in above cases.
  static int _getIndex(String key,{String? baseLanguage}){
    List<String> base = _base;
    if(baseLanguage != null){
      if(_localizations.containsKey(baseLanguage)){
        base = _localizations[baseLanguage]!.data;
      }
    }
    var pos = base.indexOf(key);
    if(pos == -1){
      // If didn't found in base search in all of languages for the string
      _localizations.forEach((k, v) {
        if(pos != -1){
          return;
        }else{
          for (int i = 0 ; i <  v.data.length ; i++) {
            if(v.data[i] == key){
              pos = i;
              return;
            }
          }
        }
      });
    }
    return pos;
  }

  /// Loads list of [Language] from [Worksheet] using [_config.languageRow] and [_config.startColumn].
  static Future<Map<String,Localization>?> _getLanguages()async{
    Map<String,Localization> Localizations = {};
    try{
      var workSheet = await _getWorkSheet();
      final column =  await workSheet!.values.row(_config.languageRow,fromColumn: _config.startColumn);
      for (int i = 0 ; i < column.length ; i++) {
        var lang = Language.fromCode(column[i]);
        if(lang.name != ""){
          var Localization = await _getLocalization(column: i + _config.startColumn,language: lang);
          if(Localization != null){
            Localizations[lang.code] = Localization;
          }
        }
      }
      return Localizations;
    }catch(ex){
      printLog("Localization Error : Load Languages => ${ex.toString()}");
    }
    return null;
  }

  /// Loads [version] from [_configs] file.
  static Future<void> _loadConfigurations()async{
    try{
      if(_config.configColumn != 0){
        var workSheet = await _getWorkSheet();
        final rows = await workSheet!.values.column(_config.configColumn,fromRow: _config.startRow);
        for (int i = 0; i < rows.length ; i++){
          var config = rows[i];
          var configSplit = config.split(":");
          if(configSplit.length == 2){
            _configs[configSplit[0]] = configSplit[1];
          }
        }
        printLog("Configuration loaded from sheets => size : ${_configs.keys.length}");
        _getVersion();
        if(_config.persist){
          _persistStore.setData("config", _configs);
        }
      }
    }catch(ex){
      printLog("Localization Error : Load Configurations => ${ex.toString()}");
    }
  }

  /// Loads [version] from [_configs] file.
  static _getVersion(){
    if(_configs.containsKey('version')){
      version = int.parse(_configs['version']);
      if(_config.persist){
        _persistStore.setData('version', version);
      }
    }
  }

  /// Loads data from [Columns] of [Worksheet] and creates [Localization] file.
  static Future<Localization?> _getLocalization({required int column,required Language language})async{
    try{
      var workSheet = await _getWorkSheet();
      final rows = await workSheet!.values.column(column,fromRow: _config.startRow);
      return Localization(language: language, data: rows);
    }catch(ex){
      debugPrint(ex.toString());
    }
    return null;
  }

  /// Loads [_base] from [Worksheet] using [_config.baseColumn] and [_config.startRow].
  static Future<List<String>?> _loadBase()async{
    try{
      var sheet = await _getWorkSheet();
      final rows = await sheet!.values.column(_config.baseColumn,fromRow: _config.startRow);
      return rows;
    }catch(ex){
      debugPrint(ex.toString());
    }
    return null;
  }

  /// Writes language to [SharedPreferences] from [_selectedLanguage].
  static void _storeLanguage() async {
    final pref = await SharedPreferences.getInstance();
    await pref.setString("lang", _selectedLanguage);
  }

  /// Reads language from [SharedPreferences] and saves to [_selectedLanguage].
  static Future<void> _readLanguage() async {
    final pref = await SharedPreferences.getInstance();
    var lang = pref.getString("lang");
    if(lang != null && lang.length == 2){
      _updateSelectedLanguage(language: Language.fromCode(lang),type: SelectionStatus.persist);
    }
  }

  /// Loads [_base] and [_localizations] from asset file.
  static Future<void> _loadFromAsset({Function(LocalizationInfo)? onUpdate,Map<String,dynamic>? asset})async{
    try{
      if(asset == null){
        String jsonString = await rootBundle.loadString('assets/Localization/Localizations.json');
        Map<String,dynamic> jsonData = {};
        jsonData = json.decode(jsonString);
        _loadFromJSON(jsonData, LocalizationSource.asset);
        if(onUpdate != null){
          onUpdate(LocalizationInfo(languages: languages, language: language, version: version, source: source, status: status));
        }
      }else{
        _loadFromJSON(asset, LocalizationSource.asset);
        if(onUpdate != null){
          onUpdate(LocalizationInfo(languages: languages, language: language, version: version, source: source, status: status));
        }
      }
    }catch(ex){
      printLog("Localization Error : Load from JSON asset => ${ex.toString()}");
    }
  }

  /// Loads and parses from hive DB if available.
  static Future<void> _loadLocalizationsFromLocal({Function(LocalizationInfo)? onUpdate})async{
    var translateData = await _persistStore.getData("Localizations");
    var configData = await _persistStore.getData("config");
    if(translateData != null && configData != null){
      Map<String,dynamic> json = {};
      translateData.forEach((key,value){
        json[key] = value;
      });
      _loadFromJSON(json, LocalizationSource.local);
      configData.forEach((key,value){
        _configs[key] = value;
      });
      _getVersion();
    }else{
      _loadFromSheet(_credential!, _config.sheetId,onUpdate: onUpdate);
      _loadConfigurations();
    }
  }

  /// Parses [_base] and [_localizations] from JSON file and also sets [source] accordingly.
  static _loadFromJSON(Map<String,dynamic> json,LocalizationSource from){
    if(source.index < from.index){
      if(json["base"] != null){
        _base = json["base"].cast<String>();
        if(_base.isNotEmpty){
          printLog("Base loaded from ${from.name} => size : ${_base.length}");
        }
        if(_base.isEmpty){
          printLog("Base loaded from ${from.name} is empty");
        }
      }
      if(json["Localization"] != null){
        json["Localization"].forEach((key, value) {
          Language lang = Language.fromCode(key);
          if(lang.name != ""){
            List<String> data = value.cast<String>();
            _localizations[lang.code] = Localization(language: language, data: data);
            printLog("${lang.name} loaded from ${from.name} => size : ${data.length}");
          }
        });
      }
      if(json['version'] != null){
        version = json['version'];
      }
      source = from;
    }
  }

  /// Pushes generated JSON to [GSheets]
  static Future<Map<String, dynamic>?> generateAndPushJSON({String? sheetId,String? sheetName, int? row})async{
    Map<String,dynamic> uploadData = _getLocalizationJSON();
    if(sheetId == null || sheetName == null){
      return uploadData;
    }
    if(_config.worksheetTitle == sheetName){
      debugPrint("JSON Push failed: upload sheet name can't same as Localization sheet (might overwrite and corrupt data)");
      return null;
    }
    var work = await _getWorkSheet(workSheet: sheetName);
    int pushRow =  row ?? 1;
    try{
      var backupData = json.encode(uploadData);
      if(backupData.length > 49000){
        int startPosition = 0;
        int endPosition = 20000;
        int remaining = backupData.length;
        int times = (backupData.length / endPosition).ceil();
        for(int i = 0; i < times ; i++){
          if(remaining > 0){
            var cellContent = backupData.substring(startPosition,endPosition);
            remaining = remaining - 20000;
            startPosition = endPosition + 1;
            if(remaining >= 20000){
              endPosition = endPosition + 20000;
            }else{
              endPosition = endPosition + remaining;
            }
            if(work != null){
              await work.values.insertValue(cellContent, column: 1, row: pushRow + (i + 1));
            }
          }
        }
        await work!.values.insertValue("Single cell limit exceeded so wrote to multiple rows below. Please append contents of each row and construct JSON from it.", column: 1, row: pushRow);
        printLog("Single cell limit exceeded so wrote to multiple rows. Please append contents of each row and construct JSON from it.");
      }else{
        var stat = await work!.values.insertValue(json.encode(uploadData), column: 1, row: pushRow);
        if(stat){
          printLog("JSON Push successful: ${uploadData.keys.toString()} uploaded");
        }else{
          debugPrint("JSON Push failed: ${uploadData.keys.toString()}");
        }
      }
    }catch(ex){
      debugPrint("JSON Push failed. error : ${ex.toString()}");
    }
    return uploadData;
  }

  /// Generates JSON data from [_base] and [_localizations].
  static Map<String,dynamic> _getLocalizationJSON(){
    Map<String,dynamic> map = {};
    _localizations.forEach((key, value) async {
      Localization? tr = _localizations[key];
      if(tr != null){
        map[key] = tr.data;
      }
    });
    return {"base":_base,"Localization":map,"version":version};
  }

  /// print log
  static void printLog(String message){
    if(_config.printLogs){
      debugPrint(message);
    }
  }
}
