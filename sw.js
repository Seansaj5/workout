// Service worker for the home program.
//
// Bump CACHE_VERSION when you change the icons, the manifest, the fonts or
// this file. You do NOT need to bump it for edits to index.html: the page is
// fetched network-first, so a fresh copy is picked up on the next open with
// signal.
const CACHE_VERSION = 'v6';
const CACHE_PREFIX = 'home-program-';
const CACHE_NAME = CACHE_PREFIX + CACHE_VERSION;

// Same-origin files needed to open the app with no signal at all.
const PRECACHE = [
  './',
  './index.html',
  './manifest.json',
  './icons/icon-192.png',
  './icons/icon-512.png'
];

// The Google Fonts stylesheet index.html links to. Keep it identical to the
// <link> in index.html. At install, the stylesheet and every font file it
// names are cached too, so the typefaces are there offline from day one.
const FONT_CSS = 'https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,700;12..96,800&family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@600;700&display=swap';
const FONT_HOSTS = ['fonts.googleapis.com', 'fonts.gstatic.com'];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(PRECACHE).then(() => precacheFonts(cache)))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      // Only this app's old caches. Caches belong to the whole origin, and other
      // apps live on it too (seansaj5.github.io/piano keeps its own).
      .then(keys => Promise.all(
        keys.filter(key => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME).map(key => caches.delete(key))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  if (url.origin === self.location.origin) {
    // Cache key without the query string, so ./?anything still hits ./
    const key = url.origin + url.pathname;
    const isPage = request.mode === 'navigate'
      || url.pathname.endsWith('/')
      || url.pathname.endsWith('/index.html');
    event.respondWith(isPage ? networkFirst(key) : cacheFirst(request, key));
    return;
  }

  if (FONT_HOSTS.includes(url.hostname)) {
    event.respondWith(cacheFirst(request, request.url));
    return;
  }

  // Everything else, including the YouTube "watch form" links and anything
  // another origin might serve, is left to the browser: not intercepted and
  // never cached.
});

// Best effort. A font problem must not stop the app from installing; anything
// missed here is picked up by the runtime cache the first time it loads.
function precacheFonts(cache) {
  return fetch(FONT_CSS, { mode: 'cors' })
    .then(response => {
      if (!response.ok) throw new Error('stylesheet returned ' + response.status);
      const copy = response.clone();
      return response.text().then(css => {
        const files = [...new Set(css.match(/https:\/\/fonts\.gstatic\.com\/[^)'"\s]+/g) || [])];
        return Promise.all([cache.put(FONT_CSS, copy), cache.addAll(files)]);
      });
    })
    .catch(err => console.warn('Fonts not precached:', err.message));
}

// The page: always ask the server first (revalidating past the HTTP cache so
// an edit shows up straight away), and only fall back to the cache when that
// fails. Offline in the basement, the last good copy is served.
function networkFirst(key) {
  return fetch(key, { cache: 'no-cache' })
    .then(response => {
      if (!response.ok) throw new Error('HTTP ' + response.status);
      const copy = response.clone();
      caches.open(CACHE_NAME).then(cache => cache.put(key, copy));
      return response;
    })
    .catch(() => caches.match(key)
      .then(cached => cached || caches.match('./index.html'))
      .then(cached => cached || Response.error())
    );
}

// Static assets and fonts: serve from cache, fetch and store on a miss.
function cacheFirst(request, key) {
  return caches.match(key).then(cached => {
    if (cached) return cached;
    return fetch(request).then(response => {
      // Cross-origin requests can come back opaque (status 0); keep those too.
      if (response.ok || response.type === 'opaque') {
        const copy = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(key, copy));
      }
      return response;
    });
  });
}
