import { test, expect, chromium, Browser, Page } from '@playwright/test';
import {
  enableFlutterAccessibility,
  createRoom,
  joinRoom,
  getHandCards,
  playCard,
  Player,
} from './helpers';

const PAUSE_MS = 500;
const BASE_URL = 'http://localhost:8081';

/**
 * Visual demo: 3 players + 1 table display in a 2×2 grid.
 * Run with: npx playwright test visual-demo --headed
 *
 * Window layout (1920×1080 display):
 *   ┌──────────┬──────────┐
 *   │ Player 1 │ Player 2 │
 *   ├──────────┼──────────┤
 *   │ Player 3 │  Table   │
 *   └──────────┴──────────┘
 */

// 3024×1964 Retina "Default" → 1512×982 logical.
// Dock on left (~70px), menu bar on top (~25px).
// Usable area ≈ 1442×957.
const WINDOW_WIDTH = 721;
const WINDOW_HEIGHT = 478;

const GRID: Array<{ x: number; y: number }> = [
  { x: 70, y: 25 },      // top-left: Player 1
  { x: 791, y: 25 },     // top-right: Player 2
  { x: 70, y: 503 },     // bottom-left: Player 3
  { x: 791, y: 503 },    // bottom-right: Table Display
];

interface DemoPlayer extends Player {
  browser: Browser;
}

/**
 * Launches a separate headed Chromium browser positioned at (x, y).
 */
async function launchPositioned(
  name: string,
  gridIndex: number,
): Promise<DemoPlayer> {
  const pos = GRID[gridIndex];
  const browser = await chromium.launch({
    headless: false,
    args: [
      `--window-position=${pos.x},${pos.y}`,
      `--window-size=${WINDOW_WIDTH},${WINDOW_HEIGHT}`,
      '--disable-infobars',
    ],
  });
  const ctx = await browser.newContext({
    viewport: { width: WINDOW_WIDTH - 2, height: WINDOW_HEIGHT - 56 },
  });
  const page = await ctx.newPage();
  await page.goto(BASE_URL);
  await enableFlutterAccessibility(page);
  await expect(page.getByText('Countdown')).toBeVisible({ timeout: 10_000 });
  return { ctx, page, name, browser };
}

async function spectateRoom(page: Page, roomCode: string): Promise<void> {
  await page.getByRole('button', { name: 'Table Display' }).click();

  const codeInput = page.locator('input[aria-label="Room code"]');
  await codeInput.waitFor({ state: 'visible', timeout: 5_000 });
  await codeInput.pressSequentially(roomCode, { delay: 100 });

  await page.getByRole('button', { name: 'Watch' }).click();
}

async function pause(page: Page, ms: number = PAUSE_MS): Promise<void> {
  await page.waitForTimeout(ms);
}

/**
 * Plays all cards correctly across all players with a visual pause between
 * each play. Returns the number of cards played.
 */
async function playAllCardsWithPause(players: DemoPlayer[]): Promise<number> {
  let totalPlayed = 0;

  while (true) {
    let highestValue = -1;
    let highestPlayer: DemoPlayer | null = null;

    for (const p of players) {
      const cards = await getHandCards(p.page);
      for (const c of cards) {
        if (c > highestValue) {
          highestValue = c;
          highestPlayer = p;
        }
      }
    }

    if (highestValue < 0) break; // All hands empty

    // Pause so viewer can see who is about to play
    await pause(highestPlayer!.page);

    await playCard(highestPlayer!.page, highestValue);
    totalPlayed++;

    // Brief wait for state propagation
    await highestPlayer!.page.waitForTimeout(500);
  }

  return totalPlayed;
}

test('visual demo: 3 players + table display', async () => {
  // This test plays a full game visually — give it plenty of time
  test.setTimeout(600_000);

  // --- Launch 4 separate browser windows in a 2×2 grid ---

  const p1 = await launchPositioned('Alice', 0);
  const p2 = await launchPositioned('Bob', 1);
  const p3 = await launchPositioned('Charlie', 2);
  const table = await launchPositioned('Table', 3);

  const players: DemoPlayer[] = [p1, p2, p3];
  const allBrowsers = [p1, p2, p3, table];

  try {
    // --- Step 1: Player 1 creates a room ---
    await pause(p1.page);
    const roomCode = await createRoom(p1.page);
    console.log(`Room created: ${roomCode}`);
    await pause(p1.page);

    // --- Step 2: Players 2 and 3 join ---
    await joinRoom(p2.page, roomCode, 'Bob');
    await pause(p2.page);

    await joinRoom(p3.page, roomCode, 'Charlie');
    await pause(p3.page);

    // --- Step 3: Table display joins as spectator ---
    await spectateRoom(table.page, roomCode);
    await pause(table.page);

    // --- Step 4: Player 1 starts the game ---
    await expect(p1.page.getByRole('button', { name: 'Start Game' })).toBeEnabled({ timeout: 8_000 });
    await pause(p1.page);
    await p1.page.getByRole('button', { name: 'Start Game' }).click();

    // --- Step 5: All players vote 5 cards each ---
    for (const p of players) {
      await expect(p.page.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 8_000 });
    }
    await pause(p1.page);

    for (const p of players) {
      await p.page.getByRole('checkbox', { name: '5' }).click();
      await p.page.getByRole('button', { name: 'Confirm Vote' }).click();
      await pause(p.page, 500);
    }

    // Wait for round to start — game screen shows "R1", "R2", etc.
    for (const p of players) {
      await expect(p.page.getByText(/^R\d+$/).first()).toBeVisible({ timeout: 10_000 });
    }

    // --- Step 6 & 7: Play rounds until game ends ---
    let totalCardsPlayed = 0;
    const MAX_ROUNDS = 110;

    for (let round = 1; round <= MAX_ROUNDS; round++) {
      console.log(`--- Round ${round} ---`);

      const played = await playAllCardsWithPause(players);
      totalCardsPlayed += played;
      console.log(`  Played ${played} cards (${totalCardsPlayed}/100 total)`);

      // Check for win
      const wonVisible = await p1.page.getByText(/won/i).isVisible().catch(() => false);
      if (wonVisible) {
        console.log('Game won!');
        await pause(p1.page, 3000);
        break;
      }

      // Check for game over
      const gameOverVisible = await p1.page.getByText(/game over/i).isVisible().catch(() => false);
      if (gameOverVisible) {
        console.log('Game over (lost)');
        await pause(p1.page, 3000);
        break;
      }

      if (totalCardsPlayed >= 100) {
        await pause(p1.page, 3000);
        break;
      }

      // Between rounds: RoundTransitionScreen shows "Round N Complete"
      for (const p of players) {
        await expect(p.page.getByText(/Round \d+ Complete/)).toBeVisible({ timeout: 10_000 });
      }
      await pause(p1.page);

      for (const p of players) {
        await p.page.getByRole('button', { name: 'Continue' }).click();
      }

      // Now vote UI appears
      for (const p of players) {
        await expect(p.page.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 10_000 });
      }
      await pause(p1.page);

      for (const p of players) {
        await p.page.getByRole('checkbox', { name: '5' }).click();
        await p.page.getByRole('button', { name: 'Confirm Vote' }).click();
        await pause(p.page, 500);
      }

      for (const p of players) {
        await expect(p.page.getByText(/^R\d+$/).first()).toBeVisible({ timeout: 10_000 });
      }
    }

    // --- Step 8: One player clicks "Play Again" ---
    console.log('--- Clicking Play Again ---');
    await pause(p1.page);

    const playAgainButton = p1.page.getByRole('button', { name: 'Play Again' });
    await expect(playAgainButton).toBeVisible({ timeout: 10_000 });
    await playAgainButton.click();
    await pause(p1.page);

    // --- Step 9: Play one more round (rematch flow) ---
    for (const p of players) {
      await expect(p.page.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 15_000 });
    }
    console.log('--- Rematch: Voting ---');
    await pause(p1.page);

    for (const p of players) {
      await p.page.getByRole('checkbox', { name: '5' }).click();
      await p.page.getByRole('button', { name: 'Confirm Vote' }).click();
      await pause(p.page, 500);
    }

    for (const p of players) {
      await expect(p.page.getByText(/^R\d+$/).first()).toBeVisible({ timeout: 10_000 });
    }

    console.log('--- Rematch: Playing round ---');
    const rematchPlayed = await playAllCardsWithPause(players);
    console.log(`  Rematch round: played ${rematchPlayed} cards`);

    // After the rematch round, wait for either win/loss or round transition
    await pause(p1.page, 3000);

    // If round transition appeared, dismiss it for a clean view
    for (const p of players) {
      const continueBtn = p.page.getByRole('button', { name: 'Continue' });
      if (await continueBtn.isVisible().catch(() => false)) {
        await continueBtn.click();
      }
    }

    await pause(p1.page, 2000);
    console.log('--- Visual demo complete ---');

  } finally {
    for (const b of allBrowsers) {
      await b.browser.close();
    }
  }
});
