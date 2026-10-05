import '../models/config_profissional.dart';
import 'api.dart';

class ConfigService {
  const ConfigService._();

  static Future<ConfigProfissional> obter() async {
    final data = await api.call('getConfig') as Map<String, dynamic>;
    return ConfigProfissional.fromJson(data['config'] as Map<String, dynamic>);
  }

  static Future<ConfigProfissional> salvar(ConfigProfissional c) async {
    final data = await api.call('saveConfig', {'config': c.toJson()})
        as Map<String, dynamic>;
    return ConfigProfissional.fromJson(data['config'] as Map<String, dynamic>);
  }
}
