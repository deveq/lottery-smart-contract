const Lottery = artifacts.require("Lottery");
// artifacts.require로 build폴더에 있는 Lottery.json을 불러온다.

module.exports = function (deployer) {
  // 가져온 JSON파일을 배포한다.
  deployer.deploy(Lottery);
};
