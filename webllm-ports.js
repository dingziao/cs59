// webllm-ports.js
// JS glue that connects Elm ports to WebLLM (via CDN).
// This script expects `window.app` to be the Elm app instance (set in index.html).

// Optional: you can set this to a specific model id. If set, the script will
// attempt to load this model id via CreateMLCEngine. Otherwise it will try the
// package's `prebuiltAppConfig` first.
const MODEL_ID = "Qwen2-0.5B-Instruct-q4f16_1-MLC";

function sendToElm(obj) {
  try {
    const payload = typeof obj === 'string' ? obj : JSON.stringify(obj);
    if (window.app && window.app.ports && window.app.ports.fromJs) {
      window.app.ports.fromJs.send(payload);
    } else {
      console.warn('Elm fromJs port not available;', obj);
    }
  } catch (err) {
    console.error('Failed to send to Elm:', err);
  }
}

async function initEngineAndConfig() {
  try {
    // Quick check for WebGPU support before importing heavy runtime.
    if (typeof navigator === 'undefined' || !navigator.gpu) {
      const msg = 'Error: Unable to find a compatible GPU. Your browser or system does not appear to support WebGPU.\n' +
        'Suggestions: 1) Use a browser with WebGPU support (Chrome/Edge Canary or Safari Technology Preview).\n' +
        '2) Enable WebGPU flags (e.g. chrome://flags/#enable-unsafe-webgpu) if available.\n' +
        '3) See https://webgpureport.org/ for compatibility and troubleshooting.\n' +
        'Falling back to simulated responses so UI remains testable.';
      sendToElm({ type: 'error', message: msg });
      console.warn(msg);
      return null;
    }

    const webllm = await import('https://esm.run/@mlc-ai/web-llm');
    console.log('WebLLM module loaded');

    const prebuilt = webllm.prebuiltAppConfig || webllm.prebuilt_app_config || null;
    let selectedModelId = MODEL_ID;
    let appConfig = undefined;

    if (!selectedModelId && prebuilt && Array.isArray(prebuilt.model_list) && prebuilt.model_list.length > 0) {
      const first = prebuilt.model_list[0];
      selectedModelId = first.model_id || first.model || null;
      // pass the model entry as appConfig so engine can find remote URLs
      appConfig = { model_list: [first] };
      console.log('Using prebuilt model from package:', selectedModelId || first);
    }

    if (!selectedModelId) {
      console.warn('No MODEL_ID and no prebuilt model found; skipping engine init. Using simulated fallback.');
      return null;
    }

    const initProgress = (p) => {
      // forward progress to Elm so UI can show loading state
      sendToElm({ type: 'progress', data: p });
    };

    // Create or load the engine. If appConfig is provided, pass it to CreateMLCEngine.
    let engine;
    try {
      engine = await webllm.CreateMLCEngine(selectedModelId, { appConfig, initProgressCallback: initProgress });
    } catch (err) {
      // Some builds expect a bare MLCEngine constructor and reload; try fallback
      console.warn('CreateMLCEngine failed, trying fallback MLCEngine + reload', err);
      try {
        const { MLCEngine } = webllm;
        const inst = new MLCEngine({ initProgressCallback: initProgress });
        await inst.reload(selectedModelId, { appConfig });
        engine = inst;
      } catch (err2) {
        console.error('Fallback engine init failed:', err2);
        throw err2;
      }
    }

    console.log('WebLLM engine ready');
    sendToElm({ type: 'ready', model: selectedModelId });
    return engine;
  } catch (err) {
    // Detect common WebGPU/init errors and give actionable advice
    const text = String(err || 'Unknown error');
    if (text.toLowerCase().includes('gpu') || text.toLowerCase().includes('webgpu') || text.toLowerCase().includes('unable to find a compatible')) {
      const msg = 'Error: Unable to initialize WebGPU/engine. Details: ' + text + '\n' +
        'Possible causes: no compatible GPU, browser lacks WebGPU support, or driver issues.\n' +
        'Recommendations: 1) Check https://webgpureport.org/ to confirm browser support.\n' +
        '2) Try Chrome/Edge Canary or Safari Technology Preview.\n' +
        '3) If you cannot use WebGPU, continue with simulated responses for UI testing.';
      console.error(msg);
      sendToElm({ type: 'error', message: msg });
      return null;
    }

    console.error('Failed to import or initialize WebLLM:', err);
    sendToElm({ type: 'error', message: String(err) });
    return null;
  }
}

(async () => {
  const engine = await initEngineAndConfig();

  if (!window.app) {
    console.warn('Elm app not found on window.app; ensure index.html sets window.app = Elm.Main.init(...)');
    return;
  }

  if (!window.app.ports || !window.app.ports.sendToJs) {
    console.warn('Elm ports not available (sendToJs)');
    return;
  }

  window.app.ports.sendToJs.subscribe(async (msg) => {
    console.log('Received from Elm (user):', msg);

    if (!engine) {
      // Fallback: simulate a model reply so the Elm UI can be tested without a real engine.
      console.warn('Engine not initialized; sending simulated reply.');
      setTimeout(() => {
        const simulated = { type: 'reply', text: '(simulated) Echo: ' + msg };
        sendToElm(simulated);
      }, 300);
      return;
    }

    try {
      const messages = [
        { role: 'system', content: 'You are a helpful assistant.' },
        { role: 'user', content: msg }
      ];

      // non-streaming quick call
      const reply = await engine.chat.completions.create({ messages });
      const content = reply?.choices?.[0]?.message?.content || JSON.stringify(reply);
      // Try to serialize full reply for display; fall back to string conversion.
      let rawStr = '';
      try {
        rawStr = JSON.stringify(reply, null, 2);
      } catch (e) {
        try {
          rawStr = String(reply);
        } catch (e2) {
          rawStr = '<unserializable reply>';
        }
      }
      sendToElm({ type: 'reply', text: content, raw: rawStr });
    } catch (err) {
      console.error('Error calling engine:', err);
      sendToElm({ type: 'error', message: String(err) });
    }
  });
})();
