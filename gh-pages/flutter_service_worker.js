'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"404.html": "0c5b0f43f26559c0040c70a122ed821d",
"assets/AssetManifest.bin": "02d95c7fe09b39ea9d114338cbd59b86",
"assets/AssetManifest.bin.json": "750823eabee996b64411e2136d215450",
"assets/AssetManifest.json": "4797b78bd86b600d6b8611713e763915",
"assets/assets/images/%25EB%2582%25A820%25EC%259D%25B4%25EB%25A7%2588%25EC%25B0%25B0%25EA%25B3%25BC%25EC%2583%2581_%25EA%25B8%25B4%25EA%25B8%2589%25EC%259D%2591%25EA%25B8%2589.png": "9f2235bc03bb270be1e30ea7a3776df1",
"assets/assets/images/%25EB%2582%25A830%25EA%25B0%2580%25EC%258A%25B4%25EC%25B0%25B0%25EA%25B3%25BC%25EC%2583%2581_%25EA%25B8%25B4%25EA%25B8%2589%25EC%259D%2591%25EA%25B8%2589.png": "1a74efe6aac9084b6681770d3a7486c6",
"assets/assets/images/%25EB%2582%25A830%25EA%25B0%2580%25EC%258A%25B4%25ED%2583%2580%25EB%25B0%2595%25EC%2583%2581_%25EA%25B8%25B4%25EA%25B8%2589%25EC%259D%2591%25EA%25B8%2589%25EC%2582%25AC%25EB%25A7%259D%25202.png": "b0a18b6041be778e81d4ad071d733a55",
"assets/assets/images/%25EB%2582%25A830%25EA%25B0%2580%25EC%258A%25B4%25ED%2583%2580%25EB%25B0%2595%25EC%2583%2581_%25EA%25B8%25B4%25EA%25B8%2589%25EC%259D%2591%25EA%25B8%2589%25EC%2582%25AC%25EB%25A7%259D.png": "b9c181e771b87083aaa66aa3099dd280",
"assets/assets/images/%25EB%2582%25A830%25EC%259D%25B4%25EB%25A7%2588%25EC%2597%25B4%25EC%2583%2581%25ED%258C%2594%25EC%25B0%25B0%25EA%25B3%25BC%25EC%2583%2581%25EB%25AC%25B4%25EB%25A6%258E%25EC%25B0%25B0%25EA%25B3%25BC%25EC%2583%2581_%25EA%25B8%25B4%25EA%25B8%2589%25EC%259D%2591%25EA%25B8%2589.png": "a2fd8fc44d9318ed76e009d134c136f8",
"assets/assets/images/%25EB%2582%25A830%25EC%259D%25B4%25EB%25A7%2588%25EC%25B0%25B0%25EA%25B3%25BC%25EC%2583%2581%25ED%258C%2594%25EC%25B0%25B0%25EA%25B3%25BC%25EC%2583%2581%25EB%25AC%25B4%25EB%25A6%258E%25EC%25B0%25B0%25EA%25B3%25BC%25EC%2583%2581_%25EA%25B8%25B4%25EA%25B8%2589%25EC%259D%2591%25EA%25B8%2589.png": "72f69fc9b57326c05e51f1647a6d4007",
"assets/assets/images/%25EB%2582%25A840%25EA%25B0%2580%25EC%258A%25B4%25EC%2597%25B4%25EC%2583%25811.png": "7bde96ba8890fab68c162a7e7143a7a5",
"assets/assets/images/%25EB%2582%25A840%25EA%25B0%2580%25EC%258A%25B4%25EC%2597%25B4%25EC%2583%25812.png": "88838c4d2634f63baeb036dbdfbd4743",
"assets/assets/images/%25EB%2582%25A840%25EA%25B0%2580%25EC%258A%25B4%25EC%25B0%25B0%25EA%25B3%25BC%25EC%2583%2581.png": "27b8b6cfe048c9a98a43ae1b2973ccb5",
"assets/assets/images/%25EB%2582%25A840%25EA%25B0%2580%25EC%258A%25B4%25ED%2583%2580%25EB%25B0%2595%25EC%2583%2581.png": "58d813603f0ca47a98697f914d88ecc3",
"assets/assets/images/%25EB%2582%25A840%25EA%25B2%25BD%25EB%25B6%2580%25EC%2597%25B4%25EC%2583%2581.png": "a9c907a5a1d8f57e5204bedca72788a6",
"assets/assets/images/%25EB%2582%25A840%25EB%25AC%25B4%25EB%25A6%258E%25EC%2597%25B4%25EC%2583%25812.png": "ec98f9590fea7ce5ef7ca6556b4e6a68",
"assets/assets/images/%25EB%2582%25A840%25EB%25AC%25B4%25EB%25A6%258E%25EC%25B0%25B0%25EA%25B3%25BC%25EC%2583%2581.png": "5f31986dbadecb2daeda1ae8f9b479e2",
"assets/assets/images/%25EB%2582%25A840%25EB%25B3%25B5%25EB%25B6%2580%25EA%25B4%2580%25ED%2586%25B5%25EC%2583%25811.png": "940eab3902955bc04e8426790bea7571",
"assets/assets/images/%25EB%2582%25A840%25EB%25B3%25B5%25EB%25B6%2580%25EC%2597%25B4%25EC%2583%2581.png": "19ad11670bf5eedd0677d58fafd775d5",
"assets/assets/images/%25EB%2582%25A840%25EB%25B3%25B5%25EB%25B6%2580%25ED%2583%2580%25EB%25B0%2595%25EC%2583%2581.png": "736962b56176c25f8a8b9492fec7bf2d",
"assets/assets/images/%25EB%2582%25A840%25EC%2595%2588%25EA%25B5%25AC%25EC%2599%25B8%25EC%2583%2581.png": "db2a0da64c07be474937a2e0c4658c86",
"assets/assets/images/%25EB%2582%25A840%25EC%2595%2588%25EB%25A9%25B4%25EB%25B6%2580%25ED%2583%2580%25EB%25B0%2595%25EC%2583%25811.png": "39649505e7dfc3193f25cb506dff45ea",
"assets/assets/images/%25EB%2582%25A840%25EC%2595%2588%25EB%25A9%25B4%25ED%2583%2580%25EB%25B0%2595%25EC%2583%2581.png": "10878e385b33b54dec372c3b040ef755",
"assets/assets/images/%25EB%2582%25A850%25EB%25AC%25B4%25EB%25A6%258E%25EC%2597%25B4%25EC%2583%25811.png": "be5418222dada32575197d74696b08aa",
"assets/assets/images/%25EB%2582%25A850%25EB%25AC%25B4%25EB%25A6%258E%25EC%25B0%25B0%25EA%25B3%25BC%25EC%2583%2581.png": "0f8f46b39af0baf14d4e40e4bfee033e",
"assets/assets/images/%25EB%2582%25A850%25EB%25B0%259C%25EB%25AA%25A9%25EC%2597%25BC%25EC%25A2%258C1.png": "5f619515bdd9128d877ffd930e99a409",
"assets/assets/images/%25EB%2582%25A850%25EC%2598%25A8%25EB%25AA%25B8%25EC%25B0%25B0%25EA%25B3%25BC%25EC%2583%25811.png": "a1ea9d47a112247b4a14a74185c9c2d6",
"assets/assets/images/%25EB%2582%25A860%25EA%25B0%2580%25EC%258A%25B4%25EC%25B0%25B0%25EA%25B3%25BC%25EC%2583%2581.png": "1712bbfd375b57b9c578d1e8ab2f413f",
"assets/assets/images/%25EB%2582%25A860%25EB%25B0%259C%25EB%25AA%25A9%25EC%2597%25BC%25EC%25A2%258C.png": "fed03202ca89e938357624753e6d743b",
"assets/assets/images/%25EB%2582%25A860%25EB%25B3%25B5%25EB%25B6%2580%25EC%2597%25B4%25EC%2583%25811.png": "9814fc6cc351e53b4dcc59849a1bb345",
"assets/assets/images/%25EB%2582%25A860%25EB%25B3%25B5%25EB%25B6%2580%25ED%2583%2580%25EB%25B0%2595%25EC%2583%2581.png": "d655bc56a789926596e6b2db1ac74f4c",
"assets/assets/images/%25EB%2582%25A870%25EC%2598%25A8%25EB%25AA%25B8%25EC%25B0%25B0%25EA%25B3%25BC%25EC%2583%25811.png": "19eff7c856bedf63dbcca807f5bc828c",
"assets/assets/images/%25EB%2582%25A880%25EA%25B0%2580%25EC%258A%25B4%25EC%2597%25B4%25EC%2583%2581.png": "48fa27ebbd8545be3078fe55e1695184",
"assets/assets/images/%25EB%2582%25A880%25EB%25B3%25B5%25EB%25B6%2580%25EC%2597%25B4%25EC%2583%25811.png": "da6ae5ca104403bc58379675d30986d4",
"assets/assets/images/%25EC%2597%25AC30%25EB%25AC%25B4%25EB%25A6%258E%25EC%2597%25B4%25EC%2583%2581.png": "95945c685da7f325ac07d7f92401dea9",
"assets/assets/images/%25EC%2597%25AC30%25EB%25B3%25B5%25EB%25B6%2580%25EC%25B0%25B0%25EA%25B3%25BC%25EC%2583%25811.png": "b24fa533ff6f2586db261d4f517e5bfc",
"assets/assets/images/%25EC%2597%25AC30%25ED%258C%2594%25EB%258B%25A4%25EB%25A6%25AC%25EC%25B0%25B0%25EA%25B3%25BC%25EC%2583%25811.png": "87221f651d37fa4cbd66fa271dcd56df",
"assets/assets/images/%25EC%2597%25AC60%25EB%25AC%25B4%25EB%25A6%258E%25EC%2597%25B4%25EC%2583%25811.png": "967ef6f9e498263a7d36f5b02fc83552",
"assets/assets/images/%25EC%2597%25AC60%25EB%25B3%25B5%25EB%25B6%2580%25ED%2583%2580%25EB%25B0%2595%25EC%2583%25811.png": "07612a4d73cb0ff345da7b28ca8109a9",
"assets/assets/images/%25EC%2597%25AC60%25ED%258C%2594%25EB%258B%25A4%25EB%25A6%25AC%25EC%25B0%25B0%25EA%25B3%25BC%25EC%2583%25811.png": "477d6298d7be93a799180a807d8ae5a7",
"assets/assets/images/patient1.png": "84f458afd109871e47ab24bab52609fa",
"assets/assets/images/patient10.png": "95ca9dfa65c5de4c4c8750739c7ea05c",
"assets/assets/images/patient11.png": "e7a905daf9a32e98d25169f32dca51a0",
"assets/assets/images/patient12.png": "e7a905daf9a32e98d25169f32dca51a0",
"assets/assets/images/patient13.png": "6aceff53a4a129a4f79bc09c7ad29f72",
"assets/assets/images/patient14.png": "6aceff53a4a129a4f79bc09c7ad29f72",
"assets/assets/images/patient2.png": "f30fdce6099ea0a8c912767e6a6c1ebf",
"assets/assets/images/patient3.png": "0e4f62f3960515f59764cdfbe54f03d7",
"assets/assets/images/patient4.png": "ad12c564f02c7efcb425cdf4806303cd",
"assets/assets/images/patient5.png": "a35b0bebc8b5af1b5e1878aa8cafc24e",
"assets/assets/images/patient6.png": "2312e07b399c56a12c67ba0a87bdfaa8",
"assets/assets/images/patient7.png": "a76435f85eb03df26fe60321f5e7b38b",
"assets/assets/images/patient8.png": "a76435f85eb03df26fe60321f5e7b38b",
"assets/assets/images/patient9.png": "3c8559d22a99192dface2ec421e0a9f5",
"assets/assets/patients/generated_patients.json": "b1ee2b5f76db6e38d6990158ac49c869",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "cf0d1731adb293a8c491c1214c927702",
"assets/NOTICES": "770b2b31bbe73b81d2328a4bddf41f2e",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "86e461cf471c1640fd2b461ece4589df",
"canvaskit/canvaskit.js.symbols": "68eb703b9a609baef8ee0e413b442f33",
"canvaskit/canvaskit.wasm": "efeeba7dcc952dae57870d4df3111fad",
"canvaskit/chromium/canvaskit.js": "34beda9f39eb7d992d46125ca868dc61",
"canvaskit/chromium/canvaskit.js.symbols": "5a23598a2a8efd18ec3b60de5d28af8f",
"canvaskit/chromium/canvaskit.wasm": "64a386c87532ae52ae041d18a32a3635",
"canvaskit/skwasm.js": "f2ad9363618c5f62e813740099a80e63",
"canvaskit/skwasm.js.symbols": "80806576fa1056b43dd6d0b445b4b6f7",
"canvaskit/skwasm.wasm": "f0dfd99007f989368db17c9abeed5a49",
"canvaskit/skwasm_st.js": "d1326ceef381ad382ab492ba5d96f04d",
"canvaskit/skwasm_st.js.symbols": "c7e7aac7cd8b612defd62b43e3050bdd",
"canvaskit/skwasm_st.wasm": "56c3973560dfcbf28ce47cebe40f3206",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "76f08d47ff9f5715220992f993002504",
"flutter_bootstrap.js": "4224d5424d12165b2802e2efd137a0a6",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "0c5b0f43f26559c0040c70a122ed821d",
"/": "0c5b0f43f26559c0040c70a122ed821d",
"main.dart.js": "b4fd0b697d014f7d45ea32225a8f847b",
"manifest.json": "22c4c9ae3dea135ddadd43d9e2c81482",
"version.json": "238bc2a2840d7f33ad508e6c127006ec"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
