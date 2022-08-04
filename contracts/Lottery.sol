// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.22 <0.9.0;

contract Lottery {

    struct BetInfo {
        // 맞추려는 블록 만약 3번블록에 기록된 tx였다면 answerBlockNumber는 6
        uint256 answerBlockNumber;
        address payable bettor;
        bytes1 challenges;
    }

    mapping(uint256 => BetInfo) private _bets;

    uint256 private _tail;
    uint256 private _head;
    address public owner;
    
    uint256 private _pot;
    uint256 constant internal BET_AMOUNT = 0.005 ether;
    uint256 constant internal BET_BLOCK_INTERVAL = 3;
    uint256 constant internal BLOCK_LIMIT = 256;

    enum BlockStatus {
        Checkable,
        NotRevealed,
        BlockLimitPassed
    }

    enum BettingResult {
        Fail,
        Win,
        Draw
    }

    event BET(uint256 index, address bettor, uint256 amount, bytes1 challenges, uint256 answerBlockNumber);

    constructor() {
        owner = msg.sender;
    }

    function getPot() public view returns (uint256 value) {
        return _pot;
    }

    // Bet
    /**
     * @dev 베팅을 한다. 유저는 0.005 ETH를 보내야하고, 베팅용 1 byte 글자를 보내야한ㄷ.
     * 큐에 저장된 베팅 정보는 이후 distribute 함수에서 해결된다.
     * @param challenges 베팅용 1byte 글자
     * @return result 함수가 잘 수행되었는지 확인하는 bool
     */
    function bet(bytes1 challenges) public payable returns (bool result) {
        // check the value is send properly. 
        require(msg.value == BET_AMOUNT, "Bet amount should be 0.005 ETH");

        // push bet to the queue
        require(pushBet(challenges), "Failed to add a new Bet Info");

        // emit event
        emit BET(_tail - 1, msg.sender, msg.value, challenges, block.number + BET_BLOCK_INTERVAL);        
        return true;
    }

    // Distribute (검증) 함수
    // check the answer
    function distribute() public {
        // queue에 저장된 베팅 정보가 3(head),4,5,6,7,8,9,10(tail)이라 하면
        // 3번 큐에 대한 정답확인, 분배, pop
        // 4번 큐에 대한 정답확인, 분배, pop
        // ... 10번 큐에 대한 정답확인, 분배, Pop
        uint256 cur;
        BetInfo memory b;
        BlockStatus currentBlockStatus;

        for (cur = _head; cur <= _tail; cur++) {

            // 블록의 상태 확인
            b = _bets[cur];
            currentBlockStatus = getBlockStatus(b.answerBlockNumber);
            // 1. checkable : 최근 256번 블록이내이면서, 마이닝이 된 상태
            //    block.number > b.answerBlockNumber -> 같을경우엔 block hash가 아직 없음
            //    && block.number < b.answerBlockNumber + BLOCK_LIMIT
            if (currentBlockStatus == BlockStatus.Checkable) {
                // win - bettor gets pot


                // fail - bettor's money goes to pot

                // draw - bettor's money will be refund
            }

            // 2. not revealed : 아직 마이닝 되지 않은 상태
            //    block.number <= b.answerBlockNumber
            if (currentBlockStatus == BlockStatus.NotRevealed) {
                break;
            }

            // 3. block limit passed
            //    block.number >= b.answerBlockNumber + BLOCK_LIMIT
            if (currentBlockStatus == BlockStatus.BlockLimitPassed) {
                // 환불
                // emit refund
            }

            popBet(cur);

        }
    }

    /**
     * @dev 베팅글자와 정답을 확인한다
     * @param challenges 베팅한 글자
     * @param answer 블록 해시
     * @return BettingResult 정답 확인 결과
     */
    function isMatch(bytes1 challenges, bytes32 answer) public pure returns (BettingResult) {
        // challenges 0xab
        // answer 0xab.....ff 32bytes

        bytes1 c1 = challenges;
        bytes1 c2 = challenges;
        bytes1 a1 = answer[0];
        bytes1 a2 = answer[0];

        // 첫번째 글자 얻기
        c1 = c1 >> 4; // 0xab -> 0x0a
        c1 = c1 << 4; // 0x0a -> 0xa0

        a1 = a1 >> 4;
        a1 = a1 << 4;

        // 두번째 글자 얻기
        c2 = c2 << 4; // 0xab -> 0xb0
        c2 = c2 >> 4; // 0xb0 -> 0x0b

        a2 = a2 << 4;
        a2 = a2 >> 4;

        if (a1 == c1 && a2 == c2) {
            return BettingResult.Win;
        } 
        
        if (a1 == c1 || a2 == c2) {
            return BettingResult.Draw;
        }

        return BettingResult.Fail;
    }

    function getBlockStatus(uint256 answerBlockNumber) internal view returns (BlockStatus) {
        if (block.number > answerBlockNumber && block.number < answerBlockNumber + BLOCK_LIMIT) {
            return BlockStatus.Checkable;
        }
        
        if (block.number <= answerBlockNumber) {
            return BlockStatus.NotRevealed;
        } 
        if (block.number >= answerBlockNumber + BLOCK_LIMIT) {
            return BlockStatus.BlockLimitPassed;
        }

        // 아무것도 안걸렸을땐 환불해주기
        return BlockStatus.BlockLimitPassed;
    }

    function getBetInfo(uint256 index) public view returns(uint256 answerBlockNumber, address bettor, bytes1 challenges) {
        BetInfo memory b = _bets[index];
        answerBlockNumber = b.answerBlockNumber + BET_BLOCK_INTERVAL;
        bettor = b.bettor;
        challenges = b.challenges;
    }

    function pushBet(bytes1 challenges) internal returns (bool) {
        BetInfo memory b;
        b.bettor = payable(msg.sender);
        b.answerBlockNumber = block.number;
        b.challenges = challenges;

        _bets[_tail] = b;
        _tail++;

        return true;
    }

    function popBet(uint256 index) internal returns (bool) {
        delete _bets[index];
        return true;
    }
}