class Config{
  int baseColumn = 1;
  String initialLanguage = "en";
  bool persist = false;
  String worksheetTitle = "";
  int languageRow = 1;
  int startRow = 2;
  int startColumn = 2;
  bool printLogs = true;
  String sheetId = "";
  int configColumn = 0;
  Config({required this.baseColumn,required this.initialLanguage,required this.persist,required this.sheetId,required this.printLogs,required this.startRow,required this.startColumn,required this.languageRow,required this.worksheetTitle,required this.configColumn});
  Config.empty();
}