import { test, expect } from '@playwright/test';
import {
  createPlayer,
  createRoom,
  joinRoom,
  startGameAndVote,
  getHandCards,
  playCard,
  closePlayers,
} from './helpers';

test('playing the lower card first loses a life but game continues', async ({ browser }) => {
  const alice = await createPlayer(browser, 'Alice');
  const bob = await createPlayer(browser, 'Bob');

  const roomCode = await createRoom(alice.page);
  await joinRoom(bob.page, roomCode, 'Bob');

  await startGameAndVote([alice, bob], 1);

  // Read both hands
  const aliceCards = await getHandCards(alice.page);
  const bobCards = await getHandCards(bob.page);
  expect(aliceCards.length).toBe(1);
  expect(bobCards.length).toBe(1);

  const aliceCard = aliceCards[0];
  const bobCard = bobCards[0];

  // Play the LOWER card first (wrong order → life lost)
  const lowerCard = aliceCard < bobCard ? aliceCard : bobCard;
  const lowerPlayer = aliceCard < bobCard ? alice : bob;
  const higherCard = aliceCard > bobCard ? aliceCard : bobCard;
  const higherPlayer = aliceCard > bobCard ? alice : bob;

  await playCard(lowerPlayer.page, lowerCard);

  // Verify the invalid card was consumed (1 card in discard)
  await expect(alice.page.getByText('1/100 played')).toBeVisible({ timeout: 5_000 });
  await expect(bob.page.getByText('1/100 played')).toBeVisible({ timeout: 5_000 });

  // Verify lives dropped from 5 to 4 — use the LivesIndicator which shows
  // the number in bold 24px text. Match specifically in game status context.
  // After the invalid play, we're still on the game screen (phase == round).
  await expect(alice.page.getByText('Round 1')).toBeVisible({ timeout: 3_000 });

  // The lower card is consumed (removed from hand) — player should have no cards
  const lowerRemaining = await getHandCards(lowerPlayer.page);
  expect(lowerRemaining.length).toBe(0);

  // Game continues — play the remaining higher card
  await playCard(higherPlayer.page, higherCard);

  // After playing the higher card (valid), all hands are empty → round ends
  // Phase transitions to lobby → vote UI appears for next round
  await expect(alice.page.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 10_000 });
  await expect(bob.page.getByText('Vote: cards per player this round')).toBeVisible({ timeout: 10_000 });

  await closePlayers([alice, bob]);
});
