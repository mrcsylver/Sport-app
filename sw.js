/* Iron League service worker — offline app shell.
   GENERATED VERSION: run tools/bump_version.py, never edit the two lines below.

   A release used to reach phones only sometimes, and this is why. Bumping
   CACHE alone is not enough: install fetches the shell through the browser's
   OWN http cache, and GitHub Pages serves assets with ten minutes of
   freshness, so a worker could delete the old bucket and refill the new one
   with exactly the same stale bytes. Two things fix it — every shell request
   is made with cache:'reload' so the http cache cannot answer, and the assets
   carry ?v= so a new release is a different URL that nothing has cached. */
var VERSION = '2.14.0';
var CACHE = 'ironleague-v2.14.0';
var SHELL = [
  './', './index.html',
  './styles.css?v=' + VERSION, './app.js?v=' + VERSION,
  './vendor/supabase.js?v=' + VERSION, './vendor/game-icons.js?v=' + VERSION,
  './manifest.webmanifest',
  './icons/icon-192.png', './icons/icon-512.png', './icons/icon-1024.png',
  './icons/maskable-512.png', './icons/apple-touch-icon.png', './icons/favicon-32.png',
  './fonts/barlow-condensed-latin-600-normal.woff2',
  './fonts/barlow-condensed-latin-700-normal.woff2',
  './fonts/barlow-condensed-latin-800-normal.woff2',
  './fonts/barlow-condensed-latin-800-italic.woff2'
];

self.addEventListener('install', function (e) {
  e.waitUntil(
    caches.open(CACHE).then(function (c) {
      // cache:'reload' on every one of them: the http cache must not be
      // allowed to hand back the release we are trying to replace.
      return Promise.all(SHELL.map(function (u) {
        return fetch(new Request(u, { cache: 'reload' })).then(function (res) {
          if (res && (res.ok || res.type === 'opaque')) return c.put(u, res);
        }).catch(function () {});
      }));
    }).then(function () { return self.skipWaiting(); })
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
