import { test, expect } from '@playwright/test';
import {
  createPlayer,
  createRoom,
  joinRoom,
  startGameAndVote,
  playAllCardsCorrectly,
  voteForRound,
  closePlayers,
  Player,
} from './helpers';

test('two players play a full game to completion (win)', async ({ browser }) => {
  test.setTimeout(300_000); // 50 rounds — needs extra time with slow-mo

  const alice = await createPlayer(browser, 'Alice');
  const bob = await createPlayer(browser, 'Bob');

  const roomCode = await createRoom(alice.page);
  await joinRoom(bob.page, roomCode, 'Bob');
  await expect(alice.page.getByRole('button', { name: 'Start Game' })).toBeEnabled({ timeout: 8_000 });

  // Start game and vote 1 card each for round 1
  await startGameAndVote([alice, bob], 1);

  let totalCardsPlayed = 0;
  const MAX_ROUNDS = 55; // Safety limit

  for (let round = 1; round <= MAX_ROUNDS; round++) {
    // Play all cards in the correct order this round
    const played = await playAllCardsCorrectly([alice, bob]);
    totalCardsPlayed += played;

    console.log(`Round ${round}: played ${played} cards (${totalCardsPlayed}/100 total)`);

    // Check if we've won
    if (totalCardsPlayed >= 100) {
      // Verify win banner on both screens
      await expect(alice.page.getByText(/won/i)).toBeVisible({ timeout: 10_000 });
      await expect(bob.page.getByText(/won/i)).toBeVisible({ timeout: 10_000 });
      break;
    }

    // Between rounds: lobby returns with vote UI
    // Wait for vote UI to appear (phase transitions back to lobby)
    await expect(alice.page.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 10_000 });

    // Vote 1 card for next round
    await voteForRound([alice, bob], 1);
  }

  expect(totalCardsPlayed).toBe(100);

  await closePlayers([alice, bob]);
});
