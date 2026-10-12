{{flutter_js}}
{{flutter_build_config}}

// Full-page render; the only customisation is removing the loading logo
// (#loading in index.html) once the engine is up.
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    const loading = document.querySelector('#loading');
    if (loading) loading.remove();
    await appRunner.runApp();
  },
});
