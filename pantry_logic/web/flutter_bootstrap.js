{{flutter_js}}
{{flutter_build_config}}

// Full-page render (edge to edge, under the iOS status bar). Safe-area
// insets are applied inside the app, see lib/core/web_safe_area.dart.
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
