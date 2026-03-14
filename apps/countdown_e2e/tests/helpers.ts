import { Page, BrowserContext, Browser, expect } from '@playwright/test';

/**
 * Flutter CanvasKit renders to canvas — no DOM text by default.
 * This enables Flutter's accessibility tree, which injects flt-semantics
 * elements with role/aria-label attributes that Playwright can target.
 */
export async function enableFlutterAccessibility(page: Page): Promise<void> {
  await page.waitForFunction(() => {
    const el = document.querySelector('[aria-label="Enable accessibility"]');
    return el !== null;
  }, undefined, { timeout: 15_000 });

  await page.evaluate(() => {
    const el = document.querySelector('[aria-label="Enable accessibility"]') as HTMLElement;
    el?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
  });

  await page.waitForFunction(() => {
    return document.querySelectorAll('flt-semantics').length > 0;
  }, undefined, { timeout: 5_000 });
}

export interface Player {
  ctx: BrowserContext;
  page: Page;
  name: string;
}

/**
 * Creates a new browser context + page, navigates to home, enables accessibility.
 */
export async function createPlayer(browser: Browser, name: string): Promise<Player> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  await page.goto('/');
  await enableFlutterAccessibility(page);
  await expect(page.getByText('Countdown')).toBeVisible({ timeout: 5_000 });
  return { ctx, page, name };
}

/**
 * Alice creates a room and returns the 4-letter room code.
 */
export async function createRoom(page: Page): Promise<string> {
  await page.getByRole('button', { name: 'Create Room' }).click();

  const roomCode = await page.waitForFunction(() => {
    const text = document.body.innerText;
    const match = text.match(/\b([A-Z]{4})\b/);
    return match ? match[1] : null;
  }, undefined, { timeout: 10_000 }).then(handle => handle.jsonValue() as Promise<string>);

  return roomCode;
}

/**
 * Joins a room by opening the Join Room dialog, entering name + code, and clicking Join.
 */
export async function joinRoom(page: Page, roomCode: string, name: string): Promise<void> {
  await page.getByRole('button', { name: 'Join Room' }).click();

  const nameInput = page.locator('input[aria-label="Your name"]');
  await nameInput.waitFor({ state: 'visible', timeout: 5_000 });
  await nameInput.pressSequentially(name, { delay: 100 });

  const codeInput = page.locator('input[aria-label="Room code"]');
  await codeInput.waitFor({ state: 'visible', timeout: 5_000 });
  await codeInput.pressSequentially(roomCode, { delay: 100 });

  await page.getByRole('button', { name: 'Join', exact: true }).click();

  // Wait for lobby screen — allow extra time under slow-mo or many players
  await expect(page.getByText('Players')).toBeVisible({ timeout: 15_000 });
}

/**
 * Starts the game and has all players vote with the given count, then waits
 * for the game screen to appear on all pages.
 */
export async function startGameAndVote(players: Player[], voteCount: number = 1): Promise<void> {
  // The first player (host) starts the game
  await players[0].page.getByRole('button', { name: 'Start Game' }).click();

  // Wait for vote UI on all players
  for (const p of players) {
    await expect(p.page.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 8_000 });
  }

  // Select vote count if not 1 (1 is selected by default)
  // Flutter ChoiceChips render as generic elements, not radio buttons.
  // Target them by their text label within the chip row.
  for (const p of players) {
    if (voteCount !== 1) {
      await p.page.getByRole('checkbox', { name: String(voteCount) }).click();
    }
    await p.page.getByRole('button', { name: 'Confirm Vote' }).click();
  }

  // Wait for game screen on all players
  for (const p of players) {
    await expect(p.page.getByText(/Round \d+/)).toBeVisible({ timeout: 10_000 });
    await expect(p.page.getByText('Your hand')).toBeVisible({ timeout: 5_000 });
  }
}

/**
 * Votes (between rounds) without starting the game. Used when returning to
 * lobby after a completed round.
 */
export async function voteForRound(players: Player[], voteCount: number = 1): Promise<void> {
  for (const p of players) {
    await expect(p.page.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 8_000 });
  }

  for (const p of players) {
    if (voteCount !== 1) {
      await p.page.getByRole('checkbox', { name: String(voteCount) }).click();
    }
    await p.page.getByRole('button', { name: 'Confirm Vote' }).click();
  }

  for (const p of players) {
    await expect(p.page.getByText(/Round \d+/)).toBeVisible({ timeout: 10_000 });
    await expect(p.page.getByText('Your hand')).toBeVisible({ timeout: 5_000 });
  }
}

/**
 * Returns the card values visible in a player's hand.
 */
export async function getHandCards(page: Page): Promise<number[]> {
  const buttons = page.getByRole('button', { name: /^\d+$/ });
  const count = await buttons.count();
  const cards: number[] = [];
  for (let i = 0; i < count; i++) {
    const label = await buttons.nth(i).getAttribute('aria-label');
    if (label) cards.push(parseInt(label, 10));
  }
  return cards;
}

/**
 * Clicks a specific card tile by its value.
 */
export async function playCard(page: Page, value: number): Promise<void> {
  await page.getByRole('button', { name: String(value), exact: true }).click();
}

/**
 * Reads all players' hands, finds the highest card globally, and plays it.
 * Returns the value that was played.
 */
export async function playHighestFirst(players: Player[]): Promise<number> {
  let highestValue = -1;
  let highestPlayer: Player | null = null;

  for (const p of players) {
    const cards = await getHandCards(p.page);
    for (const c of cards) {
      if (c > highestValue) {
        highestValue = c;
        highestPlayer = p;
      }
    }
  }

  if (!highestPlayer || highestValue < 0) {
    throw new Error('No cards found in any hand');
  }

  await playCard(highestPlayer.page, highestValue);
  return highestValue;
}

/**
 * Plays all cards in the correct descending order across all players' hands.
 * Returns the number of cards played.
 */
export async function playAllCardsCorrectly(players: Player[]): Promise<number> {
  let totalPlayed = 0;

  // Keep playing until all hands are empty
  while (true) {
    let highestValue = -1;
    let highestPlayer: Player | null = null;

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

    await playCard(highestPlayer!.page, highestValue);
    totalPlayed++;

    // Brief wait for state to propagate
    await highestPlayer!.page.waitForTimeout(300);
  }

  return totalPlayed;
}

/**
 * Cleanup all player contexts.
 */
export async function closePlayers(players: Player[]): Promise<void> {
  for (const p of players) {
    await p.ctx.close();
  }
}
