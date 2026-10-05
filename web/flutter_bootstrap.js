{{flutter_js}}
{{flutter_build_config}}

// Service worker próprio. O flutter_service_worker.js das versões atuais só se
// desregistra, então sem este o app não abre offline. Aqui NÃO passamos
// serviceWorkerSettings ao loader, para os dois não disputarem o mesmo escopo.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', function () {
    navigator.serviceWorker.register('nutri_sw.js').catch(function (e) {
      console.warn('Service worker não registrado', e);
    });
  });
}

_flutter.loader.load();
