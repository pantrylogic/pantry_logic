{{flutter_js}}
{{flutter_build_config}}

// Render into #app (inset by the device safe areas, see index.html) rather
// than the full page, so nothing is drawn under the iOS status bar.
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async function (engineInitializer) {
    const host = document.querySelector('#app');
    const appRunner = await engineInitializer.initializeEngine({
      hostElement: host,
    });
    const loading = document.querySelector('#loading');
    if (loading) loading.remove();
    await appRunner.runApp();
  },
});
