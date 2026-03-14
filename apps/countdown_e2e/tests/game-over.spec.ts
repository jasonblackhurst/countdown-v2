import { test, expect } from '@playwright/test';
import {
  createPlayer,
  createRoom,
  joinRoom,
  startGameAndVote,
  getHandCards,
  playCard,
  voteForRound,
  closePlayers,
} from './helpers';

test('game ends when all 5 lives are lost', async ({ browser }) => {
  test.setTimeout(60_000);

  const alice = await createPlayer(browser, 'Alice');
  const bob = await createPlayer(browser, 'Bob');

  const roomCode = await createRoom(alice.page);
  await joinRoom(bob.page, roomCode, 'Bob');

  await startGameAndVote([alice, bob], 1);

  let livesLost = 0;
  const MAX_ROUNDS = 10; // Safety limit

  for (let round = 1; round <= MAX_ROUNDS && livesLost < 5; round++) {
    const aliceCards = await getHandCards(alice.page);
    const bobCards = await getHandCards(bob.page);

    if (aliceCards.length === 0 && bobCards.length === 0) break;

    const aliceCard = aliceCards[0] ?? 0;
    const bobCard = bobCards[0] ?? 0;

    // Intentionally play the LOWER card first (wrong order)
    const lowerCard = aliceCard < bobCard ? aliceCard : bobCard;
    const lowerPlayer = aliceCard < bobCard ? alice : bob;
    const higherCard = aliceCard > bobCard ? aliceCard : bobCard;
    const higherPlayer = aliceCard > bobCard ? alice : bob;

    await playCard(lowerPlayer.page, lowerCard);
    livesLost++;

    if (livesLost >= 5) break;

    // Play the remaining card to finish the round
    await higherPlayer.page.waitForTimeout(300);
    await playCard(higherPlayer.page, higherCard);

    // Wait for vote UI for next round
    await expect(alice.page.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 10_000 });
    await voteForRound([alice, bob], 1);
  }

  // Verify game over banner on both screens
  await expect(alice.page.getByText(/game over/i)).toBeVisible({ timeout: 10_000 });
  await expect(bob.page.getByText(/game over/i)).toBeVisible({ timeout: 10_000 });

  await closePlayers([alice, bob]);
});
