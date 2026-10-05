// Versão web (com navegador) ou neutra (testes), escolhida na compilação.
export 'update_checker_stub.dart'
    if (dart.library.js_interop) 'update_checker_web.dart';
