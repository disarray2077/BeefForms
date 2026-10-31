# WebAssembly browser tests

Build this consuming application with a Wasm-capable Beef toolchain and configured
Emscripten SDK:

```powershell
BeefBuild -workspace=Tests/Wasm -config=Debug -platform=wasm32
```

Run the browser test with Node.js and Playwright installed:

```powershell
node Tests/Wasm/browser-test.cjs
```

The script serves the build locally and uses Chromium with touch emulation. Set
`CHROME_PATH` to use an existing Chrome/Chromium executable. An optional first
argument selects a different build directory.
