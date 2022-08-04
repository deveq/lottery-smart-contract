const Lottery = artifacts.require("Lottery");
const assertRevert = require("./assertRevert");
const expectEvent = require("./expectEvent");

contract(
    "Lottery",
    ([deployer, user1]) => {
        let lottery;
        const betBlockInterval = 3;
        const betAmount = web3.utils.toWei("0.005", "ether");
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

        describe.only("isMatch", () => {
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



  
    }
)