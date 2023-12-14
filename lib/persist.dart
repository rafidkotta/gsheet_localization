import 'package:hive_flutter/adapters.dart';
import 'package:hive_flutter/hive_flutter.dart';

class Persist{
  Box<dynamic>? _box;
  Persist.init(){
    initPersist();
  }
  Future<dynamic> getData(String key)async{
    if(_box != null){
      return _box!.get(key);
    }else{
      await initPersist();
      if(_box!.containsKey(key)){
        return await _box!.get(key);
      }
      return null;
    }
  }
  dynamic setData(String key,dynamic data)async{
    if(_box != null){
      await _box!.put(key, data);
    }
  }
  initPersist()async{
    await Hive.initFlutter();
    _box = await Hive.openBox('nsv_sheet_translation');
  }
}