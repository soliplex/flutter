(() => {
  // src/bridge.js
  var worker = null;
  var nextId = 1;
  var pending = /* @__PURE__ */ new Map();
  async function init() {
    if (worker) return true;
    return new Promise((resolve) => {
      try {
        worker = new Worker(
          new URL("./dart_monty_worker.js", window.location.href),
          { type: "module" }
        );
        worker.onmessage = (e) => {
          const msg = e.data;
          if (msg.type === "ready") {
            console.log("[DartMontyBridge] Worker ready");
            resolve(true);
            return;
          }
          if (msg.type === "error" && !msg.id) {
            console.error("[DartMontyBridge] Worker init error:", msg.message);
            resolve(false);
            return;
          }
          if (msg.id && pending.has(msg.id)) {
            const { resolve: res } = pending.get(msg.id);
            pending.delete(msg.id);
            res(msg);
          }
        };
        worker.onerror = (err) => {
          console.error("[DartMontyBridge] Worker error:", err.message || err);
          for (const [, { reject }] of pending) {
            reject(err);
          }
          pending.clear();
          resolve(false);
        };
      } catch (e) {
        console.error("[DartMontyBridge] Failed to create Worker:", e.message);
        resolve(false);
      }
    });
  }
  function callWorker(msg) {
    return new Promise((resolve, reject) => {
      const id = nextId++;
      pending.set(id, { resolve, reject });
      worker.postMessage({ ...msg, id });
    });
  }
  async function run(code, limitsJson, scriptName) {
    if (!worker) {
      return JSON.stringify({ ok: false, error: "Not initialized", errorType: "InitError" });
    }
    const limits = limitsJson ? JSON.parse(limitsJson) : null;
    const msg = { type: "run", code, limits };
    if (scriptName) msg.scriptName = scriptName;
    const result = await callWorker(msg);
    return JSON.stringify(result);
  }
  async function start(code, extFnsJson, limitsJson, scriptName) {
    if (!worker) {
      return JSON.stringify({ ok: false, error: "Not initialized", errorType: "InitError" });
    }
    const extFns = extFnsJson ? JSON.parse(extFnsJson) : [];
    const limits = limitsJson ? JSON.parse(limitsJson) : null;
    const msg = { type: "start", code, extFns, limits };
    if (scriptName) msg.scriptName = scriptName;
    const result = await callWorker(msg);
    return JSON.stringify(result);
  }
  async function resume(valueJson) {
    if (!worker) {
      return JSON.stringify({ ok: false, error: "Not initialized", errorType: "InitError" });
    }
    const value = JSON.parse(valueJson);
    const result = await callWorker({ type: "resume", value });
    return JSON.stringify(result);
  }
  async function resumeWithError(errorJson) {
    if (!worker) {
      return JSON.stringify({ ok: false, error: "Not initialized", errorType: "InitError" });
    }
    const errorMessage = JSON.parse(errorJson);
    const result = await callWorker({ type: "resumeWithError", errorMessage });
    return JSON.stringify(result);
  }
  async function snapshot() {
    if (!worker) {
      return JSON.stringify({ ok: false, error: "Not initialized", errorType: "InitError" });
    }
    const result = await callWorker({ type: "snapshot" });
    return JSON.stringify(result);
  }
  async function restore(dataBase64) {
    if (!worker) {
      return JSON.stringify({ ok: false, error: "Not initialized", errorType: "InitError" });
    }
    const result = await callWorker({ type: "restore", dataBase64 });
    return JSON.stringify(result);
  }
  function discover() {
    return JSON.stringify({ loaded: worker !== null, architecture: "worker" });
  }
  async function dispose() {
    if (!worker) {
      return JSON.stringify({ ok: true });
    }
    const result = await callWorker({ type: "dispose" });
    return JSON.stringify(result);
  }
  window.DartMontyBridge = {
    init,
    run,
    start,
    resume,
    resumeWithError,
    snapshot,
    restore,
    discover,
    dispose
  };
  console.log("[DartMontyBridge] Registered on window (Worker architecture)");
})();
