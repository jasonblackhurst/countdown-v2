import { test, expect } from '@playwright/test';
import {
  createPlayer,
  createRoom,
  joinRoom,
  startGameAndVote,
  closePlayers,
} from './helpers';

test('joining with an invalid room code shows an error', async ({ browser }) => {
  const alice = await createPlayer(browser, 'Alice');

  // Try to join with a bogus room code
  await alice.page.getByRole('button', { name: 'Join Room' }).click();

  const nameInput = alice.page.locator('input[aria-label="Your name"]');
  await nameInput.waitFor({ state: 'visible', timeout: 5_000 });
  await nameInput.pressSequentially('Alice', { delay: 100 });

  const codeInput = alice.page.locator('input[aria-label="Room code"]');
  await codeInput.waitFor({ state: 'visible', timeout: 5_000 });
  await codeInput.pressSequentially('ZZZZ', { delay: 100 });

  await alice.page.getByRole('button', { name: 'Join', exact: true }).click();

  // Should see an error — either in the dialog or as a snackbar
  // The server sends an error message for invalid room codes
  await expect(alice.page.getByText(/not found|invalid|does not exist|error/i).first()).toBeVisible({ timeout: 8_000 });

  await closePlayers([alice]);
});

test('joining after game started shows an error', async ({ browser }) => {
  const alice = await createPlayer(browser, 'Alice');
  const bob = await createPlayer(browser, 'Bob');
  const charlie = await createPlayer(browser, 'Charlie');

  const roomCode = await createRoom(alice.page);
  await joinRoom(bob.page, roomCode, 'Bob');

  // Start the game with Alice and Bob
  await startGameAndVote([alice, bob], 1);

  // Charlie tries to join the already-started game
  await charlie.page.getByRole('button', { name: 'Join Room' }).click();

  const nameInput = charlie.page.locator('input[aria-label="Your name"]');
  await nameInput.waitFor({ state: 'visible', timeout: 5_000 });
  await nameInput.pressSequentially('Charlie', { delay: 100 });

  const codeInput = charlie.page.locator('input[aria-label="Room code"]');
  await codeInput.waitFor({ state: 'visible', timeout: 5_000 });
  await codeInput.pressSequentially(roomCode, { delay: 100 });

  await charlie.page.getByRole('button', { name: 'Join', exact: true }).click();

  // Should see an error about game already in progress
  await expect(charlie.page.getByText(/already|in progress|started|cannot join/i).first()).toBeVisible({ timeout: 8_000 });

  await closePlayers([alice, bob, charlie]);
});
