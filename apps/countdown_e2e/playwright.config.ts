import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 30_000,
  fullyParallel: false,   // multiplayer tests share server state — run serially
  retries: 0,
  reporter: 'list',
  use: {
    baseURL: 'http://localhost:8081',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  webServer: [
    {
      // WebSocket game server
      command: 'dart run bin/server.dart',
      cwd: '../countdown_server',
      port: 8080,
      reuseExistingServer: true,
    },
    {
      // Flutter web static server
      command: 'python3 -m http.server 8081 --directory ../countdown_flutter/build/web',
      port: 8081,
      reuseExistingServer: true,
    },
  ],
});
