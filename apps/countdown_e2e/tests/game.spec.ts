import { test, expect, Page, BrowserContext } from '@playwright/test';

// Flutter CanvasKit renders to canvas — no DOM text by default.
// Calling this function enables Flutter's accessibility tree, which injects
// flt-semantics elements with role/aria-label attributes that Playwright
// can target with getByRole/getByText.
async function enableFlutterAccessibility(page: Page): Promise<void> {
  // Wait for Flutter to finish loading and rendering
  await page.waitForFunction(() => {
    const el = document.querySelector('[aria-label="Enable accessibility"]');
    return el !== null;
  }, undefined, { timeout: 15_000 });

  // The placeholder is intentionally positioned off-screen; use JS to click it
  await page.evaluate(() => {
    const el = document.querySelector('[aria-label="Enable accessibility"]') as HTMLElement;
    el?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
  });

  // Wait for flt-semantics elements to appear in the DOM
  await page.waitForFunction(() => {
    return document.querySelectorAll('flt-semantics').length > 0;
  }, undefined, { timeout: 5_000 });
}

test('two players create a room, start a game, and play the first card', async ({ browser }) => {
  // ── Two independent browser contexts = two players ─────────────────────────
  const aliceCtx: BrowserContext = await browser.newContext();
  const bobCtx: BrowserContext   = await browser.newContext();
  const alice: Page = await aliceCtx.newPage();
  const bob: Page   = await bobCtx.newPage();

  await alice.goto('/');
  await bob.goto('/');

  // Enable Flutter accessibility tree in both windows.
  // Without this, Flutter CanvasKit renders to canvas with no DOM text,
  // making Playwright selectors unreliable.
  await enableFlutterAccessibility(alice);
  await enableFlutterAccessibility(bob);

  // ── Verify home screen loaded ──────────────────────────────────────────────
  await expect(alice.getByText('Countdown')).toBeVisible({ timeout: 5_000 });
  await expect(bob.getByText('Countdown')).toBeVisible({ timeout: 5_000 });

  // ── Alice creates a room ───────────────────────────────────────────────────
  // The room creator is assigned the name "Host" by the server (no name prompt).
  await alice.getByRole('button', { name: 'Create Room' }).click();

  // After creating, Alice lands on LobbyScreen.
  // The room code is displayed large (56px bold): a 4-letter uppercase word.
  // Also appears in the AppBar heading as "Room  XXXX".
  const roomCode: string = await alice.waitForFunction(() => {
    const text = document.body.innerText;
    const match = text.match(/\b([A-Z]{4})\b/);
    return match ? match[1] : null;
  }, undefined, { timeout: 10_000 }).then(handle => handle.jsonValue() as Promise<string>);

  expect(roomCode).toMatch(/^[A-Z]{4}$/);
  console.log(`Room code: ${roomCode}`);

  // ── Bob joins the room ─────────────────────────────────────────────────────
  // Clicking "Join Room" opens an AlertDialog (role="alertdialog") with:
  //   - <input aria-label="Your name">   (Flutter TextField)
  //   - <input aria-label="Room code">   (Flutter TextField)
  //   - role="button" text="Join"        (TextButton in dialog actions)
  //   - role="button" text="Dismiss"     (barrier dismiss)
  await bob.getByRole('button', { name: 'Join Room' }).click();

  // Wait for the dialog inputs to appear (Flutter TextFields render as real <input>)
  const nameInput = bob.locator('input[aria-label="Your name"]');
  await nameInput.waitFor({ state: 'visible', timeout: 5_000 });
  await nameInput.pressSequentially('Bob', { delay: 100 });

  const codeInput = bob.locator('input[aria-label="Room code"]');
  await codeInput.waitFor({ state: 'visible', timeout: 5_000 });
  // Use pressSequentially with a delay so Flutter's TextEditingController can sync
  // each keystroke. Without a delay, keystrokes are sent too fast and some are dropped.
  await codeInput.pressSequentially(roomCode, { delay: 100 });

  // Click the dialog's "Join" button.
  // IMPORTANT: Use exact:true so Playwright doesn't match "Join Room" on the HomeScreen
  // behind the dialog. Without exact:true, substring matching picks up "Join Room" first
  // and clicking it just re-opens the dialog without sending the join message.
  await bob.getByRole('button', { name: 'Join', exact: true }).click();

  // ── Both players are on LobbyScreen ───────────────────────────────────────
  // Alice should see the room code as a large standalone text element.
  // The room code appears in the accessibility tree as both a heading ("Room  XXXX")
  // and a standalone text node ("XXXX"). Use first() to avoid strict mode violation.
  await expect(alice.getByText(roomCode, { exact: true }).first()).toBeVisible({ timeout: 8_000 });

  // Bob should land on the lobby screen — confirmed by the Players heading appearing.
  await expect(bob.getByText('Players')).toBeVisible({ timeout: 10_000 });

  // Alice should see the Start Game button enabled (requires >= 2 players)
  await expect(alice.getByRole('button', { name: 'Start Game' })).toBeEnabled({ timeout: 8_000 });

  // ── Alice starts the game ──────────────────────────────────────────────────
  // "Start Game" FilledButton is enabled when >= 2 players and game not yet started.
  await alice.getByRole('button', { name: 'Start Game' }).click();

  // ── Both players see the vote UI ───────────────────────────────────────────
  // After startGame, LobbyScreen switches to vote mode:
  //   "Vote: cards per player this round" label
  //   ChoiceChips numbered 1-5 (default selection: 1)
  //   "Confirm Vote" FilledButton
  await expect(alice.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 8_000 });
  await expect(bob.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 8_000 });

  // Both vote 1 card (ChoiceChip "1" is selected by default)
  await alice.getByRole('button', { name: 'Confirm Vote' }).click();
  await bob.getByRole('button', { name: 'Confirm Vote' }).click();

  // ── Game screen appears for both players ───────────────────────────────────
  // GameScreen displays:
  //   - "Round 1" (status bar, left)
  //   - Lives count "5" + heart icon (status bar, center)
  //   - "0/100 played" (status bar, right)
  //   - "—" placeholder for last played card
  //   - "Your hand" section label
  //   - Card tiles (tappable numbers) or "No cards" if hand is empty
  await expect(alice.getByText('Round 1')).toBeVisible({ timeout: 10_000 });
  await expect(bob.getByText('Round 1')).toBeVisible({ timeout: 10_000 });

  await expect(alice.getByText('Your hand')).toBeVisible({ timeout: 5_000 });
  await expect(bob.getByText('Your hand')).toBeVisible({ timeout: 5_000 });

  // No cards played yet — discard counter starts at 0
  await expect(alice.getByText('0/100 played')).toBeVisible({ timeout: 5_000 });
  await expect(bob.getByText('0/100 played')).toBeVisible({ timeout: 5_000 });

  // ── Both players see their card ───────────────────────────────────────────
  // GestureDetector with onTap becomes role="button" in Flutter's semantic tree.
  // Each card tile has the card value as its aria-label (a plain number 1–100).
  await expect(alice.getByText('No cards')).not.toBeVisible({ timeout: 3_000 });
  await expect(bob.getByText('No cards')).not.toBeVisible({ timeout: 3_000 });

  // _CardTile now has Semantics(button: true, label: '$value') so it produces
  // role="button" with the card number as aria-label — standard Playwright selectors work.
  const aliceCardGroup = alice.getByRole('button', { name: /^\d+$/ }).first();
  const bobCardGroup   = bob.getByRole('button',   { name: /^\d+$/ }).first();

  await expect(aliceCardGroup).toBeVisible({ timeout: 5_000 });
  await expect(bobCardGroup).toBeVisible({ timeout: 5_000 });

  const aliceCardText = await aliceCardGroup.getAttribute('aria-label');
  const bobCardText   = await bobCardGroup.getAttribute('aria-label');
  const aliceCard = parseInt(aliceCardText ?? '0', 10);
  const bobCard   = parseInt(bobCardText   ?? '0', 10);

  expect(aliceCard).toBeGreaterThan(0);
  expect(bobCard).toBeGreaterThan(0);

  // ── Play the highest card first ────────────────────────────────────────────
  // Semantics(button: true) on _CardTile produces role="button", so .click() works.
  const highCardGroup = aliceCard > bobCard ? aliceCardGroup : bobCardGroup;
  await highCardGroup.click();

  // Discard pile increments on both screens
  await expect(alice.getByText('1/100 played')).toBeVisible({ timeout: 5_000 });
  await expect(bob.getByText('1/100 played')).toBeVisible({ timeout: 5_000 });

  // ── Cleanup ────────────────────────────────────────────────────────────────
  await aliceCtx.close();
  await bobCtx.close();
});
