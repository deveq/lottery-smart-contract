const Lottery = artifacts.require("Lottery");
const assertRevert = require("./assertRevert");
const expectEvent = require("./expectEvent");

contract(
    "Lottery",
    ([deployer, user1, user2]) => {
        let lottery;
        const betBlockInterval = 3;
        const betAmount = web3.utils.toWei("0.005", "ether");
        const betAmountBN = new web3.utils.BN("5000000000000000");
        before(async () => {
            console.log('before');
            lottery = await Lottery.new();
        })

        it("getPot should return current pot", async () => {

            let pot = await lottery.getPot();
            assert.equal(pot, 0);
        })

        describe("Bet", () => {
            it("should fail when the bet money is not 0.005 ETH", async () => {
                // fail transaction
                // 두번째인자는 transaction object

                // await assertRevert(lottery.bet("0xab", {from: user1, value:4e15 }));
                // tx obj {chainId, value, to, from, gas(limit), gasPrice}
            });

            it("should put the bet to the bet queue with 1 bet", async () => {
                // bet
                const receipt = await lottery.bet("0xab", {from: user1, value: betAmount});
                // check the balance of contract == 0.005 ETH
                let pot = await lottery.getPot();
                assert.equal(pot, 0);
                const contractBalance = await web3.eth.getBalance(lottery.address);
                assert.equal(contractBalance, betAmount);
                
                // check bet info
                const currentBlockNumber = await web3.eth.getBlockNumber();
                const bet = await lottery.getBetInfo(0);
                // assert.equal(bet.answerBlockNumber.toString(), currentBlockNumber + betBlockInterval);
                assert.equal(bet.answerBlockNumber, currentBlockNumber + betBlockInterval);
                assert.equal(bet.bettor, user1);
                assert.equal(bet.challenges, "0xab");
                

                // check event log
                await expectEvent.inLogs(receipt.logs, "BET");
            });


        })

        describe("isMatch", () => {
            const blockHash = "0xab3734f7f5e87c6aaae24a0d0e7dab6ad1beb939d3a2072b6e9f379bb68a62e9"

            it("should be BettingResult.Win when two characters match", async () => {
                const matchingResult = await lottery.isMatch("0xab", blockHash);
                assert.equal(matchingResult, 1);
            });
            
            it("should be BettingResult.Fail when two characters don't match", async () => {
                const matchingResult = await lottery.isMatch("0xa0", blockHash);
                assert.equal(matchingResult, 2);
            });
            it("should be BettingResult.Draw when one character matches", async () => {
                const matchingResult = await lottery.isMatch("0xcd", blockHash);
                assert.equal(matchingResult, 0);
            });

        })

        describe.only("distribute", () => {

            describe("When the answer is checkable", () => {
                it("should give the user the pot when the answer matches ", async () => {
                    // 다 맞았을 때
                    // betAndDistribute * n
                    const setAnswerResult = await lottery.setAnswerForTest("0xab3734f7f5e87c6aaae24a0d0e7dab6ad1beb939d3a2072b6e9f379bb68a62e9", {from: deployer});

                    await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 1 -> 4
                    await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 2 -> 5
                    await lottery.betAndDistribute("0xab", {from: user1, value: betAmount}); // 3 -> 6
                    await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 4 -> 7
                    await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 5 -> 8
                    await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 6 -> 9

                    const potBefore = await lottery.getPot();
                    let user1BalanceBefore = await web3.eth.getBalance(user1);
                    // 6번째 betAndDistribute가 실행된 시점에서는 5번블록의 hash만 알 수 있으므로 1번과 2번의 amount만 실패로 인해 pot에 들어온 상태임

                    // 7번째 betAndDistribute 실행
                    const receipt7 = await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 7 -> 10 // user1에게 pot money를 전달

                    const potAfter = await lottery.getPot(); // == 0
                    const user1BalanceAfter = await web3.eth.getBalance(user1); // == before + 0.015  (1,2번의 베팅 + 자기 자신의 베팅금액)
                    user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
                    assert.equal(user1BalanceBefore.add(potBefore).add(betAmountBN).toString(), new web3.utils.BN(user1BalanceAfter).toString());

                    // 
                })
                it("should give the user the betting amount when a single character matches", async () => {
                    // 한글자 맞았을 때
                    const setAnswerResult = await lottery.setAnswerForTest("0xab3734f7f5e87c6aaae24a0d0e7dab6ad1beb939d3a2072b6e9f379bb68a62e9", {from: deployer});

                    await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 1 -> 4
                    await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 2 -> 5
                    await lottery.betAndDistribute("0xaf", {from: user1, value: betAmount}); // 3 -> 6
                    await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 4 -> 7
                    await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 5 -> 8
                    await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 6 -> 9

                    const potBefore = await lottery.getPot();
                    let user1BalanceBefore = await web3.eth.getBalance(user1);
                    // 6번째 betAndDistribute가 실행된 시점에서는 5번블록의 hash만 알 수 있으므로 1번과 2번의 amount만 실패로 인해 pot에 들어온 상태임

                    // 7번째 betAndDistribute 실행
                    const receipt7 = await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 7 -> 10 // user1에게 pot money를 전달

                    const potAfter = await lottery.getPot(); // == 0.01
                    const user1BalanceAfter = await web3.eth.getBalance(user1); // == before + 0.015  (1,2번의 베팅 + 자기 자신의 베팅금액)
                    // user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
                    // assert.equal(user1BalanceBefore.add(potBefore).add(betAmountBN).toString(), new web3.utils.BN(user1BalanceAfter).toString());
                    assert.equal(potBefore.toString(), potAfter.toString());

                })
                it.only("should get the ETH of user whene the answer does not match at all", async () => {
                    // 틀렸을 때

                    const setAnswerResult = await lottery.setAnswerForTest("0xab3734f7f5e87c6aaae24a0d0e7dab6ad1beb939d3a2072b6e9f379bb68a62e9", {from: deployer});

                    await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 1 -> 4
                    await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 2 -> 5
                    await lottery.betAndDistribute("0xef", {from: user1, value: betAmount}); // 3 -> 6
                    await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 4 -> 7
                    await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 5 -> 8
                    await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 6 -> 9

                    const potBefore = await lottery.getPot(); // 0.015
                    let user1BalanceBefore = await web3.eth.getBalance(user1);
                    // 6번째 betAndDistribute가 실행된 시점에서는 5번블록의 hash만 알 수 있으므로 1번과 2번의 amount만 실패로 인해 pot에 들어온 상태임

                    // 7번째 betAndDistribute 실행
                    const receipt7 = await lottery.betAndDistribute("0xef", {from: user2, value: betAmount}); // 7 -> 10 // user1에게 pot money를 전달

                    const potAfter = await lottery.getPot(); // == 0.015
                    const user1BalanceAfter = await web3.eth.getBalance(user1); // == before + 0.015  (1,2번의 베팅 + 자기 자신의 베팅금액)
                    // user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
                    // assert.equal(user1BalanceBefore.add(potBefore).add(betAmountBN).toString(), new web3.utils.BN(user1BalanceAfter).toString());
                    // assert.equal(potBefore.toString(), potAfter.toString());
                })
            })

            it("When the answer is not revealed(not mined)", async () => {

            })
            it("When the anwer is not revealed(Block limit is passed)", async () => {

            })
        });


  
    }
)