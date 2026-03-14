import { test, expect } from '@playwright/test';
import {
  createPlayer,
  createRoom,
  joinRoom,
  startGameAndVote,
  getHandCards,
  playAllCardsCorrectly,
  voteForRound,
  closePlayers,
} from './helpers';

test('multi-round voting with different card counts uses minimum vote', async ({ browser }) => {
  test.setTimeout(60_000);

  const alice = await createPlayer(browser, 'Alice');
  const bob = await createPlayer(browser, 'Bob');

  const roomCode = await createRoom(alice.page);
  await joinRoom(bob.page, roomCode, 'Bob');
  await expect(alice.page.getByRole('button', { name: 'Start Game' })).toBeEnabled({ timeout: 8_000 });

  // ── Round 1: Alice votes 2, Bob votes 3 → minimum is 2 ────────────────────
  await alice.page.getByRole('button', { name: 'Start Game' }).click();

  // Wait for vote UI
  await expect(alice.page.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 8_000 });
  await expect(bob.page.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 8_000 });

  // Alice votes 2
  await alice.page.getByRole('checkbox', { name: '2' }).click();
  await alice.page.getByRole('button', { name: 'Confirm Vote' }).click();

  // Bob votes 3
  await bob.page.getByRole('checkbox', { name: '3' }).click();
  await bob.page.getByRole('button', { name: 'Confirm Vote' }).click();

  // Wait for game screen
  await expect(alice.page.getByText('Round 1')).toBeVisible({ timeout: 10_000 });
  await expect(bob.page.getByText('Round 1')).toBeVisible({ timeout: 10_000 });

  // Verify each player has 2 cards (minimum of 2 and 3)
  const aliceCards = await getHandCards(alice.page);
  const bobCards = await getHandCards(bob.page);
  expect(aliceCards.length).toBe(2);
  expect(bobCards.length).toBe(2);

  // Play all cards correctly
  const played = await playAllCardsCorrectly([alice, bob]);
  expect(played).toBe(4); // 2 cards × 2 players

  // ── Between rounds: verify vote UI returns ─────────────────────────────────
  await expect(alice.page.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 10_000 });
  await expect(bob.page.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 10_000 });

  // ── Round 2: both vote 1 → each gets 1 card ───────────────────────────────
  await voteForRound([alice, bob], 1);

  // Verify round number incremented
  await expect(alice.page.getByText('Round 2')).toBeVisible({ timeout: 5_000 });
  await expect(bob.page.getByText('Round 2')).toBeVisible({ timeout: 5_000 });

  // Verify each player has 1 card
  const aliceCards2 = await getHandCards(alice.page);
  const bobCards2 = await getHandCards(bob.page);
  expect(aliceCards2.length).toBe(1);
  expect(bobCards2.length).toBe(1);

  await closePlayers([alice, bob]);
});
