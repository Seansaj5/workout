// Service worker for the home program.
//
// Bump CACHE_VERSION when you change the icons, the manifest or this file.
// You do NOT need to bump it for edits to index.html: the page is fetched
// network-first, so a fresh copy is picked up on the next open with signal.
const CACHE_VERSION = 'v1';
const CACHE_NAME = 'home-program-' + CACHE_VERSION;

// Everything needed to open the app with no signal at all.
const PRECACHE = [
  './',
  './index.html',
  './manifest.json',
  './icons/icon-192.png',
  './icons/icon-512.png'
];

const FONT_HOSTS = ['fonts.googleapis.com', 'fonts.gstatic.com'];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(PRECACHE))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  // Cache key without the query string, so ./?anything still hits ./
  const key = url.origin + url.pathname;

  if (url.origin === self.location.origin) {
    const isPage = request.mode === 'navigate'
      || url.pathname.endsWith('/')
      || url.pathname.endsWith('/index.html');
    event.respondWith(isPage ? networkFirst(key) : cacheFirst(request, key));
    return;
  }

  // Google Fonts (the stylesheet and the font files). Cached the first time
  // they load so the typefaces survive offline. Anything else passes through.
  if (FONT_HOSTS.includes(url.hostname)) {
    event.respondWith(cacheFirst(request, key));
  }
});

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

// Static assets: serve from cache, fetch and store on a miss.
function cacheFirst(request, key) {
  return caches.match(key).then(cached => {
    if (cached) return cached;
    return fetch(request).then(response => {
      // Cross-origin font requests can come back opaque (status 0); keep those too.
      if (response.ok || response.type === 'opaque') {
        const copy = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(key, copy));
      }
      return response;
    });
  });
}
