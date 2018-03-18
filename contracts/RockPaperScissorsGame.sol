pragma solidity ^0.4.18;

import './CommonState.sol';
import './RockPaperScissorsState.sol';

contract RockPaperScissorsGame {
  using CommonState for bytes;
  using RockPaperScissorsState for bytes;

  // The following transitions are allowed:
  //
  // Start -> RoundProposed
  // RoundProposed -> Start // reject game
  // RoundProposed -> RoundAccepted
  // RoundAccepted -> Reveal
  // Reveal -> Start
  // Start -> Final
  //
  function validTransition(bytes _old, bytes _new) public pure returns (bool) {
    if (_old.stateType() == RockPaperScissorsState.StateType.Start) {
      if (_new.stateType() == RockPaperScissorsState.StateType.RoundProposed) {
        require(_new.stake() > 0);
        require(_old.aBal() >= _new.stake()); // avoid integer overflow attacks
        require(_old.bBal() >= _new.stake()); // avoid integer overflow attacks
        require(_new.aBal() + _new.stake() == _old.aBal()); // stake removed from aBal
        require(_new.bBal() + _new.stake() == _old.bBal()); // stake removed from bBal

        // we should maybe require that aPreCommit isn't empty, but then it will only hurt a later if it is
        return true;
      } else if (_new.stateType() == RockPaperScissorsState.StateType.Final) {
        require(_new.aBal() == _old.aBal());
        require(_new.bBal() == _old.bBal());
        return true;
      }
    } else if (_old.stateType() == RockPaperScissorsState.StateType.RoundProposed) {
      if (_new.stateType() == RockPaperScissorsState.StateType.Start) { // game rejected
        require(_new.aBal() == _old.stake() + _old.aBal()); // stake returned from aBal
        require(_new.bBal() == _old.stake() + _old.bBal()); // stake returned from bBal
        return true;
      } else if (_new.stateType() == RockPaperScissorsState.StateType.RoundAccepted) {
        require(_new.aBal() == _old.aBal());
        require(_new.bBal() == _old.bBal());
        require(_new.stake() == _old.stake());
        require(_new.preCommit() == _old.preCommit());
        return true;
      }
    } else if (_old.stateType() == RockPaperScissorsState.StateType.RoundAccepted) {
      if (_new.stateType() == RockPaperScissorsState.StateType.Reveal) {
        require(_new.aBal() == _old.aBal());
        require(_new.bBal() == _old.bBal());
        require(_new.stake() == _old.stake());
        require(_new.bPlay() == _old.bPlay());

        // need to convert Play -> uint256 to get hash to work
        bytes32 hashed = keccak256(uint256(_new.aPlay()), _new.salt());
        require(hashed == _old.preCommit());

        return true;
      }
    } else if (_old.stateType() == RockPaperScissorsState.StateType.Reveal) {
      if (_new.stateType() == RockPaperScissorsState.StateType.Start) {
        uint256 aWinnings;
        uint256 bWinnings;
        (aWinnings, bWinnings) = winnings(_old.aPlay(), _old.bPlay(), _old.stake());

        assert(_new.aBal() == _old.aBal() + aWinnings);
        assert(_new.bBal() == _old.bBal() + bWinnings);

        return true;
      }
    }

    revert();
  }

  // in this case the resolution function is pure, but it doesn't have to be in general
  function resolve(bytes _state) public pure returns (uint aBal, uint bBal) {

    if (_state.stateType() == RockPaperScissorsState.StateType.Start) {
      aBal = _state.aBal();
      bBal = _state.bBal();
    } else if (_state.stateType() == RockPaperScissorsState.StateType.Final) {
      aBal = _state.aBal();
      bBal = _state.bBal();
    } else if (_state.stateType() == RockPaperScissorsState.StateType.RoundProposed) {
      aBal = _state.aBal() + _state.stake();
      bBal = _state.bBal() + _state.stake();
    } else if (_state.stateType() == RockPaperScissorsState.StateType.RoundAccepted) {
      // if we're stuck here, assume a doesn't want to move
      // TODO: how do we know it's a's move ...
      aBal = _state.aBal();
      bBal = _state.bBal() + 2 * _state.stake();
    } else if (_state.stateType() == RockPaperScissorsState.StateType.Reveal) {
      // in this state we need to know who won
      uint256 aWinnings;
      uint256 bWinnings;
      (aWinnings, bWinnings) = winnings(_state.aPlay(), _state.bPlay(), _state.stake());

      aBal = _state.aBal() + aWinnings;
      bBal = _state.bBal() + bWinnings;
    } else {
      revert();
    }
  }

  function winnings(RockPaperScissorsState.Play firstPlay, RockPaperScissorsState.Play secondPlay, uint256 stake) private pure returns (uint256, uint256) {
      if (firstPlay == secondPlay) { // no-one won
        return (stake, stake);
      } else if ((firstPlay == RockPaperScissorsState.Play.Rock && secondPlay == RockPaperScissorsState.Play.Scissors) ||
                 (firstPlay > secondPlay)) { // first player won
        return (2 * stake, 0);
      } else { // second player won
        return (0, 2 * stake);
      }
  }
}