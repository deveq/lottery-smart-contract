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
    address payable public owner;
    
    uint256 private _pot;
    uint256 constant internal BET_AMOUNT = 0.005 ether;
    uint256 constant internal BET_BLOCK_INTERVAL = 3;
    uint256 constant internal BLOCK_LIMIT = 256;
    bytes32 public answerForTest;
    bool private mode = false; // false: test, true: real mode(real blockhash)

    function setAnswerForTest(bytes32 _answer) public returns (bool result) {
        require(msg.sender == owner, "Only onwer can set the answer for test mode");
        answerForTest = _answer;
        return true;
    }


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
    event WIN(uint256 index, address bettor, uint256 amount, bytes1 challenges, bytes1 answer, uint256 answerBlockNumber);
    event FAIL(uint256 index, address bettor, uint256 amount, bytes1 challenges, bytes1 answer, uint256 answerBlockNumber);
    event DRAW(uint256 index, address bettor, uint256 amount, bytes1 challenges, bytes1 answer, uint256 answerBlockNumber);
    event REFUND(uint256 index, address bettor, uint256 amount, bytes1 challenges, uint256 answerBlockNumber);

    constructor() {
        owner = payable(msg.sender);
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
    /**
     * @dev 베팅 결과값을 확인하고 팟머니를 분배한다.
     * 실패: 팟머니 축적, 정답: 팟머니 획득, 한글자 or 확인불가 : 환불
     */
    function distribute() public {
        // queue에 저장된 베팅 정보가 3(head),4,5,6,7,8,9,10(tail)이라 하면
        // 3번 큐에 대한 정답확인, 분배, pop
        // 4번 큐에 대한 정답확인, 분배, pop
        // ... 10번 큐에 대한 정답확인, 분배, Pop
        uint256 cur;
        uint256 transferAmount;
        BetInfo memory b;
        BlockStatus currentBlockStatus;
        BettingResult currentBettingResult;

        for (cur = _head; cur <= _tail; cur++) {

            // 블록의 상태 확인
            b = _bets[cur];
            bytes32 answerBlockHash = getAnswerBlockHash(b.answerBlockNumber);
            currentBlockStatus = getBlockStatus(b.answerBlockNumber);
            // 1. checkable : 최근 256번 블록이내이면서, 마이닝이 된 상태
            //    block.number > b.answerBlockNumber -> 같을경우엔 block hash가 아직 없음
            //    && block.number < b.answerBlockNumber + BLOCK_LIMIT
            if (currentBlockStatus == BlockStatus.Checkable) {
                currentBettingResult = isMatch(b.challenges, answerBlockHash);
                // win - bettor gets pot
                if (currentBettingResult == BettingResult.Win) {
                    // transfer pot;
                    transferAmount = transferAfterPayingFee(b.bettor, _pot + BET_AMOUNT);
                    // pot = 0;
                    _pot = 0;
                    // emit event Win
                    emit WIN(cur, b.bettor, transferAmount, b.challenges, answerBlockHash[0], b.answerBlockNumber);
                }
                // fail - bettor's money goes to pot
                if (currentBettingResult == BettingResult.Fail) {
                    // pot += betAmount;
                    _pot += BET_AMOUNT;
                    
                    // emit event Fail
                    emit FAIL(cur, b.bettor, 0, b.challenges, answerBlockHash[0], b.answerBlockNumber);
                }

                // draw - bettor's money will be refund
                if (currentBettingResult == BettingResult.Draw) {
                    // transfer only betAmount
                    transferAmount = transferAfterPayingFee(b.bettor, BET_AMOUNT);
                    // emit event Draw
                    emit FAIL(cur, b.bettor, transferAmount, b.challenges, answerBlockHash[0], b.answerBlockNumber);
                }
            } else if (currentBlockStatus == BlockStatus.NotRevealed) {
            // 2. not revealed : 아직 마이닝 되지 않은 상태
            //    block.number <= b.answerBlockNumber
                break;
            } else if (currentBlockStatus == BlockStatus.BlockLimitPassed) {
            // 3. block limit passed
            //    block.number >= b.answerBlockNumber + BLOCK_LIMIT
                // 환불
                // emit refund
                transferAmount = transferAfterPayingFee(b.bettor, BET_AMOUNT);
                emit REFUND(cur, b.bettor, transferAmount, b.challenges, b.answerBlockNumber);
            }

           

            
            popBet(cur);
        }

        _head = cur;
    }
    
    /**
     * @dev 베팅과 정ㅏ체크를 한다.
     * @param challenge 유저가 베팅하는 글자
     * @return result 함수 살행 결과
     */
    function betAndDistribute(bytes1 challenge) public payable returns (bool result) {
        bet(challenge);

        distribute();

        return true;
    }

    function getAnswerBlockHash(uint256 answerBlockNumber) internal view returns (bytes32 answer) {
        return mode ? blockhash(answerBlockNumber) : answerForTest;
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
        b.answerBlockNumber = block.number + BET_BLOCK_INTERVAL;
        b.challenges = challenges;

        _bets[_tail] = b;
        _tail++;

        return true;
    }

    function popBet(uint256 index) internal returns (bool) {
        delete _bets[index];
        return true;
    }

    function transferAfterPayingFee(address payable addr, uint256 amount) internal returns (uint256) {
        // uint256 fee = amount / 100;
        uint256 fee = 0;
        uint256 amountWithoutFee = amount - fee;

        // transfer to address
        addr.transfer(amountWithoutFee);
        // transfer to owner
        owner.transfer(fee);

        return amountWithoutFee;
    }
}