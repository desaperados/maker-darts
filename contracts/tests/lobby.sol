import 'dapple/test.sol';
import 'lobby.sol';
import 'erc20/base.sol';

contract MakerDartsActor {
  MakerDartsLobby lobby;
  MakerDartsGame game;
  bytes32 public betHash;

  function MakerDartsActor (MakerDartsLobby _lobby)
  {
    lobby = _lobby;
  }

  function setGame (MakerDartsGame _game) {
    game = _game;
  }

  function setBetHash (bytes32 _betHash) {
    betHash = _betHash;
  }

  function createGame (uint bet, ERC20 asset)
      returns (MakerDartsGame) {
    var game = MakerDartsGame(lobby.createGame(bet, asset, true));
    game.setBlockNumber(1);
    return game;
  }

  function createZSGame (uint bet, ERC20 asset)
      returns (MakerDartsGame) {
    var zsGame = MakerDartsGame(lobby.createZeroSumGame(bet, asset, true));
    zsGame.setBlockNumber(1);
    return zsGame;
  }

  function doSetCommitmentBlocks(uint blocks) {
    game.setCommitmentBlocks(blocks);
  }

  function doSetRevealBlocks(uint blocks) {
    game.setRevealBlocks(blocks);
  }

  function doSetCalculationBlocks(uint blocks) {
    game.setCalculationBlocks(blocks);
  }

  function doSetParticipantReward(uint participantReward) {
    game.setParticipantReward(participantReward);
  }

  function doSetHouse(address addr, uint percent) {
    game.setHouse(addr, percent);
  }

  function doStartGame() {
    game.startGame(betHash);
  }

  function doApprove(address spender, uint value, ERC20 token) {
    token.approve(spender, value);
  }

  function doJoinGame(address bettor) {
    game.joinGame(betHash, bettor);
  }

  function doRevealBet(bytes32 target, bytes32 salt) {
    game.revealBet(betHash, target, salt);
  }

  function doCalculateResult() returns (bytes32) {
    return game.calculateResult(betHash);
  }

  function doClaim() {
    game.claim(betHash);
  }

  function doRequestRefund() {
    game.requestRefund(betHash);
  }

  function balanceIn(ERC20 asset) returns (uint) {
    return asset.balanceOf(this);
  }
}

contract MakerLobbyTest is Test {
  MakerDartsLobby lobby;
  MakerDartsActor alice;
  MakerDartsActor albert;
  MakerDartsActor bob;
  MakerDartsActor barb;
  MakerDartsActor izzy;

  ERC20 betAsset;
  uint constant betSize = 1000;

  bytes32 constant aliceSalt = 0xdeadbeef0;
  bytes32 constant aliceTarget = 0x7a26e70;

  bytes32 constant albertSalt = 0xdeadbeef1;
  bytes32 constant albertTarget = 0x7a26e71;

  bytes32 constant bobSalt = 0xdeadbeef2;
  bytes32 constant bobTarget = 0x7a26e72;

  bytes32 constant barbSalt = 0xdeadbeef3;
  bytes32 constant barbTarget = 0x7a26e73;

  bytes32 constant izzySalt = 0xdeadbeef4;
  bytes32 constant izzyTarget = 0x7a26e74;

  function setUp() {
    lobby = new MakerDartsLobby();
    alice = new MakerDartsActor(lobby);
    albert = new MakerDartsActor(lobby);
    bob = new MakerDartsActor(lobby);
    barb = new MakerDartsActor(lobby);
    izzy = new MakerDartsActor(lobby);

    betAsset = new ERC20Base(1000000 * 10**18);
    betAsset.transfer(alice, betSize);
    betAsset.transfer(albert, betSize);
    betAsset.transfer(bob, betSize);
    betAsset.transfer(barb, betSize);
    betAsset.transfer(izzy, betSize);
  }

  function testFailBetWithoutApproval () {
    bytes32 salt = 0xdeadbeef;
    bytes32 target = 0x7a26e7;
    alice.setBetHash(sha3(salt, target));

    alice.setGame(alice.createZSGame(betSize, betAsset));
    alice.doStartGame();
  }

  function testCreateZeroSumMakerGame () logs_gas {
    alice.setBetHash(sha3(aliceSalt, aliceTarget));

    var game = alice.createZSGame(betSize, betAsset);
    assertEq(game.participantReward(), 0);
    assertEq(game.betSize(), betSize);
    assertEq(game.betAsset(), betAsset);
  }

  function testFailAtDoubleBetting () logs_gas {
    alice.setBetHash(sha3(aliceSalt, aliceTarget));

    var game = alice.createZSGame(betSize, betAsset);
    alice.setGame(game);
    alice.doApprove(game, betSize, betAsset);
    alice.doStartGame();

    bob.setGame(game);
    bob.setBetHash(sha3(aliceSalt, aliceTarget));
    bob.doApprove(game, betSize, betAsset);
    bob.doJoinGame(bob);
  }

  function testFailRedundantParticipant () logs_gas {
    alice.setBetHash(sha3(aliceSalt, aliceTarget));

    var game = new MakerDartsGame(betSize, betAsset, true);
    game.setBlockNumber(block.number);
    game.setParticipants(2);
    game.setParticipantReward(10);
    game.setCommitmentBlocks(12);
    game.setRevealBlocks(12);
    game.setCalculationBlocks(12);
    game.setWinnerCut(75);
    game.setWinners(1);
    game.setOwner(alice);

    alice.setGame(game);
    albert.setGame(game);
    bob.setGame(game);

    betAsset.transfer(alice, betSize*2);
    alice.doApprove(game, betSize*2, betAsset);
    alice.doStartGame();

    // Commit
    albert.setBetHash(sha3(albertSalt, albertTarget));
    albert.doApprove(game, betSize, betAsset);
    albert.doJoinGame(albert);

    bob.setBetHash(sha3(bobSalt, bobTarget));
    bob.doApprove(game, betSize, betAsset);
    bob.doJoinGame(bob);

    // Advance the game past the commitment round
    game.setBlockNumber(block.number + game.commitmentBlocks());

    // Reveal
    alice.doRevealBet(aliceTarget, aliceSalt);
    albert.doRevealBet(albertTarget, albertSalt);
    bob.doRevealBet(bobTarget, bobSalt);

    // Advance the game past the reveal round
    game.setBlockNumber(block.number + game.commitmentBlocks() +
                       game.revealBlocks());

    // Calculate
    albert.doCalculateResult();
    albert.doCalculateResult();
    bob.doCalculateResult();

    // Advance the game past the calculation round
    game.setBlockNumber(block.number + game.commitmentBlocks() +
                       game.revealBlocks() + game.calculationBlocks());

    // Claim
    alice.doClaim();
    albert.doClaim();
    bob.doClaim();
  }

  function testFailJoingameWithLessBetsize () logs_gas {
    alice.setBetHash(sha3(aliceSalt, aliceTarget));

    var game = new MakerDartsGame(betSize, betAsset, true);
    game.setBlockNumber(block.number);
    game.setParticipants(2);
    game.setParticipantReward(10);
    game.setCommitmentBlocks(12);
    game.setRevealBlocks(12);
    game.setCalculationBlocks(12);
    game.setWinnerCut(75);
    game.setWinners(1);
    game.setOwner(alice);

    alice.setGame(game);
    albert.setGame(game);

    betAsset.transfer(alice, betSize*2);
    alice.doApprove(game, betSize*2, betAsset);
    alice.doStartGame();

    // Commit
    albert.setBetHash(sha3(albertSalt, albertTarget));
    albert.doApprove(game, betSize - 1, betAsset);
    albert.doJoinGame(albert);
  }

  function testStartGame () logs_gas {
    // Create & first commit
    alice.setBetHash(sha3(aliceSalt, aliceTarget));

    var game = alice.createZSGame(betSize, betAsset);
    alice.setGame(game);
    alice.doApprove(game, betSize, betAsset);
    alice.doStartGame();
  }

  function testFullGoldenPathIncentivizedGame () logs_gas {
    alice.setBetHash(sha3(aliceSalt, aliceTarget));

    var game = new MakerDartsGame(betSize, betAsset, true);
    game.setBlockNumber(block.number);
    game.setParticipants(5);
    game.setParticipantReward(10);
    game.setCommitmentBlocks(12);
    game.setRevealBlocks(12);
    game.setCalculationBlocks(12);
    game.setWinnerCut(75);
    game.setWinners(2);
    game.setOwner(alice);

    alice.setGame(game);
    albert.setGame(game);
    bob.setGame(game);
    barb.setGame(game);
    izzy.setGame(game);

    betAsset.transfer(alice, betSize*2);
    alice.doApprove(game, betSize*2, betAsset);
    alice.doStartGame();

    // Commit
    albert.setBetHash(sha3(albertSalt, albertTarget));
    albert.doApprove(game, betSize, betAsset);
    albert.doJoinGame(albert);

    bob.setBetHash(sha3(bobSalt, bobTarget));
    bob.doApprove(game, betSize, betAsset);
    bob.doJoinGame(bob);

    barb.setBetHash(sha3(barbSalt, barbTarget));
    barb.doApprove(game, betSize, betAsset);
    barb.doJoinGame(barb);

    izzy.setBetHash(sha3(izzySalt, izzyTarget));
    izzy.doApprove(game, betSize, betAsset);
    izzy.doJoinGame(izzy);

    // Advance the game past the commitment round
    game.setBlockNumber(block.number + game.commitmentBlocks());

    // Reveal
    alice.doRevealBet(aliceTarget, aliceSalt);
    albert.doRevealBet(albertTarget, albertSalt);
    bob.doRevealBet(bobTarget, bobSalt);
    barb.doRevealBet(barbTarget, barbSalt);
    izzy.doRevealBet(izzyTarget, izzySalt);

    // Advance the game past the reveal round
    game.setBlockNumber(block.number + game.commitmentBlocks() +
                       game.revealBlocks());

    // Calculate
    alice.doCalculateResult();
    albert.doCalculateResult();
    bob.doCalculateResult();
    barb.doCalculateResult();
    izzy.doCalculateResult();

    // Advance the game past the calculation round
    game.setBlockNumber(block.number + game.commitmentBlocks() +
                       game.revealBlocks() + game.calculationBlocks());

    // Claim
    alice.doClaim();
    albert.doClaim();
    bob.doClaim();
    barb.doClaim();
    izzy.doClaim();

    // Check balances
    assertEq(alice.balanceIn(betAsset), 2210);
    assertEq(albert.balanceIn(betAsset), 260);
    assertEq(bob.balanceIn(betAsset), 2135);
    assertEq(barb.balanceIn(betAsset), 2135);
    assertEq(izzy.balanceIn(betAsset), 260);
  }

  function testFullGoldenPathZeroSumGame () logs_gas {
    // Create & first commit
    alice.setBetHash(sha3(aliceSalt, aliceTarget));

    var game = alice.createZSGame(betSize, betAsset);
    game.setBlockNumber(block.number);

    alice.setGame(game);
    albert.setGame(game);
    bob.setGame(game);
    barb.setGame(game);
    izzy.setGame(game);

    alice.doApprove(game, betSize, betAsset);
    alice.doStartGame();

    // Commit
    albert.setBetHash(sha3(albertSalt, albertTarget));
    albert.doApprove(game, betSize, betAsset);
    albert.doJoinGame(albert);

    bob.setBetHash(sha3(bobSalt, bobTarget));
    bob.doApprove(game, betSize, betAsset);
    bob.doJoinGame(bob);

    barb.setBetHash(sha3(barbSalt, barbTarget));
    barb.doApprove(game, betSize, betAsset);
    barb.doJoinGame(barb);

    izzy.setBetHash(sha3(izzySalt, izzyTarget));
    izzy.doApprove(game, betSize, betAsset);
    izzy.doJoinGame(izzy);

    // Advance the game past the commitment round
    game.setBlockNumber(block.number + game.commitmentBlocks());

    // Reveal
    alice.doRevealBet(aliceTarget, aliceSalt);
    albert.doRevealBet(albertTarget, albertSalt);
    bob.doRevealBet(bobTarget, bobSalt);
    barb.doRevealBet(barbTarget, barbSalt);
    izzy.doRevealBet(izzyTarget, izzySalt);

    // Advance the game past the reveal round
    game.setBlockNumber(block.number + game.commitmentBlocks() +
                       game.revealBlocks());

    // Calculate
    alice.doCalculateResult();
    albert.doCalculateResult();
    bob.doCalculateResult();
    barb.doCalculateResult();
    izzy.doCalculateResult();

    // Advance the game past the calculation round
    game.setBlockNumber(block.number + game.commitmentBlocks() +
                       game.revealBlocks() + game.calculationBlocks());

    // Claim
    alice.doClaim();
    albert.doClaim();
    bob.doClaim();
    barb.doClaim();
    izzy.doClaim();

    // Check balances
    assertEq(alice.balanceIn(betAsset), betSize + (betSize / 3));
    assertEq(albert.balanceIn(betAsset), betSize / 2);
    assertEq(bob.balanceIn(betAsset), betSize + (betSize / 3));
    assertEq(barb.balanceIn(betAsset), betSize + (betSize / 3));
    assertEq(izzy.balanceIn(betAsset), betSize / 2);
  }

  function testFullGoldenPathZeroSumGameWithHouseEdge () logs_gas {
    uint houseEdge = 1;
    // Create & first commit
    alice.setBetHash(sha3(aliceSalt, aliceTarget));

    var game = alice.createZSGame(betSize, betAsset);
    game.setBlockNumber(block.number);

    alice.setGame(game);
    albert.setGame(game);
    bob.setGame(game);
    barb.setGame(game);
    izzy.setGame(game);

    alice.doSetHouse(alice, houseEdge);

    alice.doApprove(game, betSize, betAsset);
    alice.doStartGame();

    // Commit
    albert.setBetHash(sha3(albertSalt, albertTarget));
    albert.doApprove(game, betSize, betAsset);
    albert.doJoinGame(albert);

    bob.setBetHash(sha3(bobSalt, bobTarget));
    bob.doApprove(game, betSize, betAsset);
    bob.doJoinGame(bob);

    barb.setBetHash(sha3(barbSalt, barbTarget));
    barb.doApprove(game, betSize, betAsset);
    barb.doJoinGame(barb);

    izzy.setBetHash(sha3(izzySalt, izzyTarget));
    izzy.doApprove(game, betSize, betAsset);
    izzy.doJoinGame(izzy);

    // Advance the game past the commitment round
    game.setBlockNumber(block.number + game.commitmentBlocks());

    // Reveal
    alice.doRevealBet(aliceTarget, aliceSalt);
    albert.doRevealBet(albertTarget, albertSalt);
    bob.doRevealBet(bobTarget, bobSalt);
    barb.doRevealBet(barbTarget, barbSalt);
    izzy.doRevealBet(izzyTarget, izzySalt);

    // Advance the game past the reveal round
    game.setBlockNumber(block.number + game.commitmentBlocks() +
                       game.revealBlocks());

    // Calculate
    alice.doCalculateResult();
    albert.doCalculateResult();
    bob.doCalculateResult();
    barb.doCalculateResult();
    izzy.doCalculateResult();

    // Advance the game past the calculation round
    game.setBlockNumber(block.number + game.commitmentBlocks() +
                       game.revealBlocks() + game.calculationBlocks());

    // Claim
    alice.doClaim();
    albert.doClaim();
    bob.doClaim();
    barb.doClaim();
    izzy.doClaim();

    // Check balances
    assertEq(alice.balanceIn(betAsset),1330 + (houseEdge * betSize / 100)); // alice has the house edge
    assertEq(betAsset.balanceOf(game.house()), 1340); // alice is the house
    assertEq(albert.balanceIn(betAsset), 500);
    assertEq(bob.balanceIn(betAsset), 1330);
    assertEq(barb.balanceIn(betAsset), 1330);
    assertEq(izzy.balanceIn(betAsset), 500);
  }

  function testFullZeroSumGameWithOneUnrevealingPlayer () logs_gas {
    // Create & first commit
    alice.setBetHash(sha3(aliceSalt, aliceTarget));

    var game = alice.createZSGame(betSize, betAsset);
    game.setBlockNumber(block.number);

    alice.setGame(game);
    albert.setGame(game);
    bob.setGame(game);
    barb.setGame(game);
    izzy.setGame(game);

    alice.doApprove(game, betSize, betAsset);
    alice.doStartGame();

    // Commit
    albert.setBetHash(sha3(albertSalt, albertTarget));
    albert.doApprove(game, betSize, betAsset);
    albert.doJoinGame(albert);

    bob.setBetHash(sha3(bobSalt, bobTarget));
    bob.doApprove(game, betSize, betAsset);
    bob.doJoinGame(bob);

    barb.setBetHash(sha3(barbSalt, barbTarget));
    barb.doApprove(game, betSize, betAsset);
    barb.doJoinGame(barb);

    izzy.setBetHash(sha3(izzySalt, izzyTarget));
    izzy.doApprove(game, betSize, betAsset);
    izzy.doJoinGame(izzy);

    // Advance the game past the commitment round
    game.setBlockNumber(block.number + game.commitmentBlocks());

    // Reveal
    alice.doRevealBet(aliceTarget, aliceSalt);
    albert.doRevealBet(albertTarget, albertSalt);
    bob.doRevealBet(bobTarget, bobSalt);
    barb.doRevealBet(barbTarget, barbSalt);

    // Advance the game past the reveal round
    game.setBlockNumber(block.number + game.commitmentBlocks() +
                       game.revealBlocks());

    // Calculate
    alice.doCalculateResult();
    albert.doCalculateResult();
    bob.doCalculateResult();
    barb.doCalculateResult();

    // Advance the game past the calculation round
    game.setBlockNumber(block.number + game.commitmentBlocks() +
                       game.revealBlocks() + game.calculationBlocks());

    // Claim
    alice.doClaim();
    albert.doClaim();
    bob.doClaim();
    barb.doClaim();

    // Check balances
    assertEq(alice.balanceIn(betAsset), betSize / 2);
    assertEq(albert.balanceIn(betAsset), betSize + (betSize / 3));
    assertEq(bob.balanceIn(betAsset), betSize + (betSize / 3));
    assertEq(barb.balanceIn(betAsset), betSize + (betSize / 3));
    assertEq(izzy.balanceIn(betAsset), 0);
  }

  function testFullZeroSumGameWithOneUncalculatingPlayer () logs_gas {
    // Create & first commit
    alice.setBetHash(sha3(aliceSalt, aliceTarget));

    var game = alice.createZSGame(betSize, betAsset);
    game.setBlockNumber(block.number);

    alice.setGame(game);
    albert.setGame(game);
    bob.setGame(game);
    barb.setGame(game);
    izzy.setGame(game);

    alice.doApprove(game, betSize, betAsset);
    alice.doStartGame();

    // Commit
    albert.setBetHash(sha3(albertSalt, albertTarget));
    albert.doApprove(game, betSize, betAsset);
    albert.doJoinGame(albert);

    bob.setBetHash(sha3(bobSalt, bobTarget));
    bob.doApprove(game, betSize, betAsset);
    bob.doJoinGame(bob);

    barb.setBetHash(sha3(barbSalt, barbTarget));
    barb.doApprove(game, betSize, betAsset);
    barb.doJoinGame(barb);

    izzy.setBetHash(sha3(izzySalt, izzyTarget));
    izzy.doApprove(game, betSize, betAsset);
    izzy.doJoinGame(izzy);

    // Advance the game past the commitment round
    game.setBlockNumber(block.number + game.commitmentBlocks());

    // Reveal
    alice.doRevealBet(aliceTarget, aliceSalt);
    albert.doRevealBet(albertTarget, albertSalt);
    bob.doRevealBet(bobTarget, bobSalt);
    barb.doRevealBet(barbTarget, barbSalt);
    izzy.doRevealBet(izzyTarget, izzySalt);

    // Advance the game past the reveal round
    game.setBlockNumber(block.number + game.commitmentBlocks() +
                       game.revealBlocks());

    // Calculate
    alice.doCalculateResult();
    albert.doCalculateResult();
    bob.doCalculateResult();
    barb.doCalculateResult();

    // Advance the game past the calculation round
    game.setBlockNumber(block.number + game.commitmentBlocks() +
                       game.revealBlocks() + game.calculationBlocks());

    // Claim
    alice.doClaim();
    albert.doClaim();
    bob.doClaim();
    barb.doClaim();

    // Check balances
    assertEq(alice.balanceIn(betAsset), betSize + (betSize / 3));
    assertEq(albert.balanceIn(betAsset), betSize / 2);
    assertEq(bob.balanceIn(betAsset), betSize + (betSize / 3));
    assertEq(barb.balanceIn(betAsset), betSize + (betSize / 3));
    assertEq(izzy.balanceIn(betAsset), 0);
  }

  function testRefundsWithInsufficientPlayers () logs_gas {
    // Create & first commit
    alice.setBetHash(sha3(aliceSalt, aliceTarget));

    var game = alice.createZSGame(betSize, betAsset);
    game.setBlockNumber(block.number);

    alice.setGame(game);
    albert.setGame(game);
    bob.setGame(game);
    barb.setGame(game);

    var participantReward = 10;
    var participantRewardCost = (participantReward * game.participants());
    betAsset.transfer(alice, participantRewardCost);
    alice.doApprove(game, betSize + participantRewardCost, betAsset);
    alice.doSetParticipantReward(participantReward);
    alice.doStartGame();

    // Commit
    albert.setBetHash(sha3(albertSalt, albertTarget));
    albert.doApprove(game, betSize, betAsset);
    albert.doJoinGame(albert);

    bob.setBetHash(sha3(bobSalt, bobTarget));
    bob.doApprove(game, betSize, betAsset);
    bob.doJoinGame(bob);

    barb.setBetHash(sha3(barbSalt, barbTarget));
    barb.doApprove(game, betSize, betAsset);
    barb.doJoinGame(barb);

    // Advance the game past the commitment round
    game.setBlockNumber(block.number + game.commitmentBlocks());

    // Request refunds
    alice.doRequestRefund();
    albert.doRequestRefund();
    bob.doRequestRefund();
    barb.doRequestRefund();

    // Check balances
    assertEq(alice.balanceIn(betAsset), betSize + participantRewardCost);
    assertEq(albert.balanceIn(betAsset), betSize);
    assertEq(bob.balanceIn(betAsset), betSize);
    assertEq(barb.balanceIn(betAsset), betSize);
  }

  function testRefundsWithoutClaims () logs_gas {
    // Create & first commit
    alice.setBetHash(sha3(aliceSalt, aliceTarget));

    var game = alice.createZSGame(betSize, betAsset);
    game.setBlockNumber(block.number);

    alice.setGame(game);
    albert.setGame(game);
    bob.setGame(game);
    barb.setGame(game);
    izzy.setGame(game);

    var participantReward = 10;
    var participantRewardCost = (participantReward * game.participants());
    betAsset.transfer(alice, participantRewardCost);
    alice.doApprove(game, betSize + participantRewardCost, betAsset);
    alice.doSetParticipantReward(participantReward);
    alice.doStartGame();

    // Commit
    albert.setBetHash(sha3(albertSalt, albertTarget));
    albert.doApprove(game, betSize, betAsset);
    albert.doJoinGame(albert);

    bob.setBetHash(sha3(bobSalt, bobTarget));
    bob.doApprove(game, betSize, betAsset);
    bob.doJoinGame(bob);

    barb.setBetHash(sha3(barbSalt, barbTarget));
    barb.doApprove(game, betSize, betAsset);
    barb.doJoinGame(barb);

    izzy.setBetHash(sha3(izzySalt, izzyTarget));
    izzy.doApprove(game, betSize, betAsset);
    izzy.doJoinGame(izzy);

    // Advance the game past the commitment round
    game.setBlockNumber(block.number + game.commitmentBlocks());

    // Reveal
    alice.doRevealBet(aliceTarget, aliceSalt);
    albert.doRevealBet(albertTarget, albertSalt);
    bob.doRevealBet(bobTarget, bobSalt);
    barb.doRevealBet(barbTarget, barbSalt);
    izzy.doRevealBet(izzyTarget, izzySalt);

    // Advance the game past the reveal round
    game.setBlockNumber(block.number + game.commitmentBlocks() +
                       game.revealBlocks());


    // Advance the game past the claims round
    game.setBlockNumber(block.number + (game.commitmentBlocks() +
                       game.revealBlocks() + game.calculationBlocks()) * 2);

    // Request refunds
    alice.doRequestRefund();
    albert.doRequestRefund();
    bob.doRequestRefund();
    barb.doRequestRefund();
    izzy.doRequestRefund();

    // Check balances
    assertEq(alice.balanceIn(betAsset), betSize + participantReward);
    assertEq(albert.balanceIn(betAsset), betSize + participantReward);
    assertEq(bob.balanceIn(betAsset), betSize + participantReward);
    assertEq(barb.balanceIn(betAsset), betSize + participantReward);
    assertEq(izzy.balanceIn(betAsset), betSize + participantReward);
  }

  function testFailRefundsAfterCommitments () logs_gas {
    // Create & first commit
    alice.setBetHash(sha3(aliceSalt, aliceTarget));

    var game = alice.createZSGame(betSize, betAsset);
    game.setBlockNumber(block.number);

    alice.setGame(game);
    albert.setGame(game);
    bob.setGame(game);
    barb.setGame(game);
    izzy.setGame(game);

    alice.doApprove(game, betSize, betAsset);
    alice.doStartGame();

    // Commit
    albert.setBetHash(sha3(albertSalt, albertTarget));
    albert.doApprove(game, betSize, betAsset);
    albert.doJoinGame(albert);

    bob.setBetHash(sha3(bobSalt, bobTarget));
    bob.doApprove(game, betSize, betAsset);
    bob.doJoinGame(bob);

    barb.setBetHash(sha3(barbSalt, barbTarget));
    barb.doApprove(game, betSize, betAsset);
    barb.doJoinGame(barb);

    izzy.setBetHash(sha3(izzySalt, izzyTarget));
    izzy.doApprove(game, betSize, betAsset);
    izzy.doJoinGame(izzy);

    // Advance the game past the commitment round
    game.setBlockNumber(block.number + game.commitmentBlocks());

    // Request refunds
    alice.doRequestRefund();
    albert.doRequestRefund();
    bob.doRequestRefund();
    barb.doRequestRefund();
    izzy.doRequestRefund();
  }

  event GameStarted();
  event Commit(address sender, bytes32 betHash, address bettor);
  event Reveal(bytes32 betHash, bytes32 betTarget, bytes32 betSalt);
  event Result(bytes32 result, uint distance);
  event Claim(bytes32 commitHash, uint payout);

  function testEvents() {
    alice.setBetHash(sha3(aliceSalt, aliceTarget));

    var game = new MakerDartsGame(betSize, betAsset, true);
    game.setBlockNumber(block.number);
    game.setParticipants(2);
    game.setParticipantReward(10);
    game.setCommitmentBlocks(12);
    game.setRevealBlocks(12);
    game.setCalculationBlocks(12);
    game.setWinnerCut(75);
    game.setWinners(1);
    game.setOwner(alice);

    expectEventsExact(game);
    Commit(address(alice), sha3(aliceSalt, aliceTarget), address(alice));
    GameStarted();
    Commit(address(albert), sha3(albertSalt, albertTarget), address(albert));

    Reveal(sha3(aliceSalt, aliceTarget), aliceTarget, aliceSalt);
    Reveal(sha3(albertSalt,albertTarget), albertTarget, albertSalt);

    Result(0x56618c0d54342a2736d1c40f9835b0757670b3dd3cacc100382a0458e4b2ffa5, uint(aliceTarget | 0x56618c0d54342a2736d1c40f9835b0757670b3dd3cacc100382a0458e4b2ffa5));
    Result(0x9198e185db00b0000eda3e729d163e60c594cba3d8b11b1113e7c485363eec66, uint(albertTarget | 0x9198e185db00b0000eda3e729d163e60c594cba3d8b11b1113e7c485363eec66));

    Claim(sha3(aliceSalt, aliceTarget), 1760);
    Claim(sha3(albertSalt, albertTarget), 260);

    alice.setGame(game);
    albert.setGame(game);

    betAsset.transfer(alice, betSize*2);
    alice.doApprove(game, betSize*2, betAsset);
    alice.doStartGame();

    // Commit
    albert.setBetHash(sha3(albertSalt, albertTarget));
    albert.doApprove(game, betSize, betAsset);
    albert.doJoinGame(albert);

    // Advance the game past the commitment round
    game.setBlockNumber(block.number + game.commitmentBlocks());

    // Reveal
    alice.doRevealBet(aliceTarget, aliceSalt);
    albert.doRevealBet(albertTarget, albertSalt);

    // Advance the game past the reveal round
    game.setBlockNumber(block.number + game.commitmentBlocks() +
                       game.revealBlocks());

    // Calculate
    alice.doCalculateResult();
    albert.doCalculateResult();

    // Advance the game past the calculation round
    game.setBlockNumber(block.number + game.commitmentBlocks() +
                       game.revealBlocks() + game.calculationBlocks());

    // Claim
    alice.doClaim();
    albert.doClaim();
  }
}
