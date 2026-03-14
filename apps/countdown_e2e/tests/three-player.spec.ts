import { test, expect } from '@playwright/test';
import {
  createPlayer,
  createRoom,
  joinRoom,
  startGameAndVote,
  getHandCards,
  playAllCardsCorrectly,
  closePlayers,
} from './helpers';

test('three players can join, play a round, and see consistent state', async ({ browser }) => {
  const alice = await createPlayer(browser, 'Alice');
  const bob = await createPlayer(browser, 'Bob');
  const charlie = await createPlayer(browser, 'Charlie');

  const roomCode = await createRoom(alice.page);
  await joinRoom(bob.page, roomCode, 'Bob');
  await joinRoom(charlie.page, roomCode, 'Charlie');

  // Verify all three players appear in the lobby
  // The host sees the Start Game button
  await expect(alice.page.getByRole('button', { name: 'Start Game' })).toBeEnabled({ timeout: 8_000 });

  // Start game and vote 1 card each
  await startGameAndVote([alice, bob, charlie], 1);

  // All three players should see Round 1
  await expect(alice.page.getByText('Round 1')).toBeVisible({ timeout: 5_000 });
  await expect(bob.page.getByText('Round 1')).toBeVisible({ timeout: 5_000 });
  await expect(charlie.page.getByText('Round 1')).toBeVisible({ timeout: 5_000 });

  // Each player has 1 card
  const aliceCards = await getHandCards(alice.page);
  const bobCards = await getHandCards(bob.page);
  const charlieCards = await getHandCards(charlie.page);
  expect(aliceCards.length).toBe(1);
  expect(bobCards.length).toBe(1);
  expect(charlieCards.length).toBe(1);

  // Play all cards in correct order (highest first)
  const played = await playAllCardsCorrectly([alice, bob, charlie]);
  expect(played).toBe(3);

  // After all 3 cards played, round ends → transitions back to lobby for voting
  await expect(alice.page.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 10_000 });
  await expect(bob.page.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 10_000 });
  await expect(charlie.page.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 10_000 });

  await closePlayers([alice, bob, charlie]);
});
