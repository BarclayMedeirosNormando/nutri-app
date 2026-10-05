/// Versão neutra (testes e plataformas sem navegador): nunca há atualização.
class UpdateChecker {
  Future<bool> hasUpdate() async => false;

  void reload() {}
}
