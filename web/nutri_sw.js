/* Service worker do Nutri App: rede primeiro (até 5 s), cache como reserva.
 *
 * - Só trata GET do MESMO domínio (arquivos do app).
 * - Chamadas ao Apps Script são POST de outro domínio: nunca passam por aqui,
 *   então dados de pacientes NUNCA são guardados em cache.
 */
const CACHE = 'nutri-v1';
const NETWORK_TIMEOUT_MS = 5000;
const SCOPE = self.registration.scope;

// Arquivos mínimos para abrir o app; o resto entra no cache conforme é usado.
const PRECACHE = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'flutter.js',
  'main.dart.js',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) =>
      // Um arquivo ausente não deve impedir a instalação.
      Promise.all(
        PRECACHE.map((p) =>
          cache.add(new URL(p, SCOPE).href).catch(() => {})
        )
      )
    ).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((k) => k.startsWith('nutri-') && k !== CACHE)
            .map((k) => caches.delete(k))
        )
      )
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  if (new URL(req.url).origin !== self.location.origin) return;
  event.respondWith(networkFirst(req));
});

function timeout(ms) {
  return new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), ms));
}

async function networkFirst(req) {
  const cache = await caches.open(CACHE);

  const network = fetch(req).then((res) => {
    if (res && res.ok) cache.put(req, res.clone()).catch(() => {});
    return res;
  });
  network.catch(() => {}); // evita erro não tratado se a rede falhar depois do timeout

  try {
    return await Promise.race([network, timeout(NETWORK_TIMEOUT_MS)]);
  } catch (e) {
    const cached =
      (await cache.match(req, { ignoreSearch: true })) ||
      (req.mode === 'navigate'
        ? (await cache.match(new URL('index.html', SCOPE).href)) ||
          (await cache.match(new URL('./', SCOPE).href))
        : undefined);
    if (cached) return cached;
    return network; // sem cache: espera a rede
  }
}
