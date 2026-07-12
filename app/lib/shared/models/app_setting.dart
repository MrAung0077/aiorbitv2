import 'package:isar_community/isar.dart';

part 'app_setting.g.dart';

@collection
class AppSetting {
  Id id = Isar.autoIncrement;

  String language = 'system';

  String theme = 'system';

  String aiProvider = 'auto';
}
