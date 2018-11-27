pragma experimental ABIEncoderV2;

contract StateV2 {
    enum StateType { PreFundSetup, PostFundSetup, Game, Conclude }

    struct StateStruct {
        address channelType;
        uint256 channelNonce;
        uint256 numberOfParticipants;
        address[] participants;
        StateType stateType;
        uint256 turnNum;
        uint256 stateCount;
        uint256[] resolution;
        bytes gameAttributes;
    }

    function channelId(StateStruct memory _state) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(_state.channelType, _state.channelNonce, _state.participants)
        );
    }

    function mover(StateStruct memory _state) public pure returns (address) {
        return _state.participants[_state.turnNum % _state.numberOfParticipants];
    }

    function requireSignature(StateStruct memory _state, uint8 _v, bytes32 _r, bytes32 _s) public pure {
        require(
            mover(_state) == recoverSigner(abi.encode(_state), _v, _r, _s),
            "mover must have signed state"
        );
    }

    function requireFullySigned(StateStruct memory _state, uint8[] memory _v, bytes32[] memory _r, bytes32[] memory _s) public pure {
        for(uint i = 0; i < _state.numberOfParticipants; i++) {
            require(
                _state.participants[i] == recoverSigner(abi.encode(_state), _v[i], _r[i], _s[i]),
                "all movers must have signed state"
            );
        }
    }

    function gameAttributesEqual(StateStruct memory _state, StateStruct memory _otherState) public pure returns (bool) {
        require(
            keccak256(_state.gameAttributes) == keccak256(_otherState.gameAttributes),
            "game attributes not equal"
        );

        return true;
    }

    function resolutionsEqual(StateStruct memory _state, StateStruct memory _otherState) public pure returns (bool) {
        require(
            keccak256(abi.encodePacked(_state.resolution)) == keccak256(abi.encodePacked(_otherState.resolution)),
            "resolutions not equal"
        );
        return true;
    }

    // utilities
    // =========

    function recoverSigner(bytes memory _d, uint8 _v, bytes32 _r, bytes32 _s) internal pure returns(address) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 h = keccak256(_d);

        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, h));

        address a = ecrecover(prefixedHash, _v, _r, _s);

        return(a);
    }
}