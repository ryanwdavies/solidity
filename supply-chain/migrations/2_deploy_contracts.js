var SupplyChain = artifacts.require("./SupplyChain.sol");

module.exports = function(deployer, accounts) {
  deployer.deploy(SupplyChain);
};
