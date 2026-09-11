/* Iron League service worker — offline app shell.
   Bump CACHE when you change any file so phones pick up the new version. */
var CACHE = 'ironleague-v20';
var SHELL = [
  './', './index.html', './styles.css', './app.js',
  './vendor/supabase.js', './vendor/game-icons.js', './manifest.webmanifest',
  './icons/icon-192.png', './icons/icon-512.png', './icons/icon-1024.png',
  './icons/maskable-512.png', './icons/apple-touch-icon.png', './icons/favicon-32.png',
  './fonts/barlow-condensed-latin-600-normal.woff2',
  './fonts/barlow-condensed-latin-700-normal.woff2',
  './fonts/barlow-condensed-latin-800-normal.woff2',
  './fonts/barlow-condensed-latin-800-italic.woff2'
];

self.addEventListener('install', function (e) {
  e.waitUntil(
    caches.open(CACHE)
      .then(function (c) { return c.addAll(SHELL); })
      .then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function (e) {
  e.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(keys.map(function (k) {
        if (k !== CACHE) return caches.delete(k);
      }));
    }).then(function () { return self.clients.claim(); })
  );
});

self.addEventListener('fetch', function (e) {
  var req = e.request;
  if (req.method !== 'GET') return;
  var url = new URL(req.url);
  if (url.origin !== self.location.origin) return;   // Supabase calls: always live

  // config.js must never go stale, or edited keys would be ignored.
  if (url.pathname.endsWith('/config.js')) {
    e.respondWith(
      fetch(req).then(function (res) {
        var copy = res.clone();
        caches.open(CACHE).then(function (c) { c.put(req, copy); });
        return res;
      }).catch(function () { return caches.match(req); })
    );
    return;
  }

  if (req.mode === 'navigate') {
    e.respondWith(
      fetch(req).catch(function () {
        return caches.match('./index.html').then(function (r) { return r || caches.match('./'); });
      })
    );
    return;
  }

  e.respondWith(
    caches.match(req).then(function (hit) {
      return hit || fetch(req).then(function (res) {
        if (res && res.status === 200) {
          var copy = res.clone();
          caches.open(CACHE).then(function (c) { c.put(req, copy); });
        }
        return res;
      });
    })
  );
});
