import { test, expect } from '@playwright/test';
import {
  createPlayer,
  createRoom,
  joinRoom,
  startGameAndVote,
  getHandCards,
  playHighestFirst,
  closePlayers,
  Player,
} from './helpers';

test('two players create a room, start a game, and play the first card', async ({ browser }) => {
  const alice = await createPlayer(browser, 'Alice');
  const bob = await createPlayer(browser, 'Bob');

  // ── Alice creates a room ───────────────────────────────────────────────────
  const roomCode = await createRoom(alice.page);
  expect(roomCode).toMatch(/^[A-Z]{4}$/);
  console.log(`Room code: ${roomCode}`);

  // ── Bob joins the room ─────────────────────────────────────────────────────
  await joinRoom(bob.page, roomCode, 'Bob');

  // ── Both players are on LobbyScreen ────────────────────────────────────────
  await expect(alice.page.getByText(roomCode, { exact: true }).first()).toBeVisible({ timeout: 8_000 });
  await expect(alice.page.getByRole('button', { name: 'Start Game' })).toBeEnabled({ timeout: 8_000 });

  // ── Start game and vote 1 card each ────────────────────────────────────────
  await startGameAndVote([alice, bob], 1);

  // ── Verify game screen ────────────────────────────────────────────────────
  await expect(alice.page.getByText('Round 1')).toBeVisible({ timeout: 10_000 });
  await expect(bob.page.getByText('Round 1')).toBeVisible({ timeout: 10_000 });

  await expect(alice.page.getByText('0/100 played')).toBeVisible({ timeout: 5_000 });
  await expect(bob.page.getByText('0/100 played')).toBeVisible({ timeout: 5_000 });

  // ── Both players see their card ────────────────────────────────────────────
  const aliceCards = await getHandCards(alice.page);
  const bobCards = await getHandCards(bob.page);
  expect(aliceCards.length).toBe(1);
  expect(bobCards.length).toBe(1);

  // ── Play the highest card first ────────────────────────────────────────────
  await playHighestFirst([alice, bob]);

  // Discard pile increments on both screens
  await expect(alice.page.getByText('1/100 played')).toBeVisible({ timeout: 5_000 });
  await expect(bob.page.getByText('1/100 played')).toBeVisible({ timeout: 5_000 });

  await closePlayers([alice, bob]);
});
