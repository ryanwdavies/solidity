pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/SupplyChain.sol";

// NOTES
// ThrowThrowProxy: https://truffleframework.com/tutorials/testing-for-throws-in-solidity-tests
//
// Truffle 3 brings forth Solidity unit testing, which means one can now test contracts in Solidity
// itself. This is a boon to contract developers, as there are several reasons why it's useful to 
// have Solidity tests in addition to Truffle’s Javascript tests. For us at Ujo, one of our biggest 
// concerns is testing how contracts interact with each other, rather than just testing their 
// interaction from a web3 perspective, and Solidity tests allow us to do that.

// Returns false
// bool result = address.call(bytes4(bytes32(sha3(“functionThatThrows()”))));

// Returns true
///bool result = address.call(bytes4(bytes32(sha3(“functionThatDoesNotThrow()”))));
//
// Use in preference: address.call((abi.encodeWithSignature("f(uint)"));
// ...
// https://ethereum.stackexchange.com/questions/54646/bytes4keccak256functionuint-vs-abi-encodewithsignaturebuyuin
//
// Assert.sol: https://github.com/trufflesuite/truffle/blob/develop/packages/truffle-core/lib/testing/Assert.sol
//
// supplychain = new SupplyChain();
//  supplychain = SupplyChain(DeployedAddresses.SupplyChain());
//
// Sol 0.5.0 breaking changes
// https://solidity.readthedocs.io/en/v0.5.0/050-breaking-changes.html?highlight=payable

contract TestSupplyChain {

  // Initial Ether balance
  uint public initialBalance = 1 ether;

  // ThrowProxy assignments
  SupplyChain public supplyChain;
  ThrowProxy public seller;
  ThrowProxy public buyer;

  enum State { ForSale, Sold, Shipped, Received }

  // Item configs
  string name = "Book: Mastering Ethereum, AA, GW";
  uint   price = 10;
  uint   sku = 0;


  // beforeEach - test setup
  function beforeEach () public {
    // Set up new contract instances for each test; clean room
    supplyChain = new SupplyChain();
    seller = new ThrowProxy(address(supplyChain));
    buyer = new ThrowProxy(address(supplyChain));

    // Fund the buyer with 100 wei
    address(buyer).transfer(100);

    // The seller lists the itme
    seller.addItem(name, price);
  }


  // Test to check if item is for sale
  function testAddItem() public {
    (string memory _name
    ,uint    _sku
    ,uint    _price
    ,uint    _state
    ,address _seller
    ,address _buyer) = supplyChain.fetchItem(sku);

    Assert.equal(_name, name, "Error, testItemForSale: name incorrect.");
    Assert.equal(_sku, sku, "Error, testItemForSale: sku is not specified sku");
    Assert.equal(_price, price, "Error, testItemForSale: price is not list price");
    Assert.equal(_state, uint(State.ForSale), "Error, testItemForSale: state is not ForSale, 0");
    Assert.equal(_buyer, address(0), "Error, testItemForSale: buyer address not address(0)");
    Assert.equal(_seller, address(seller), "Error, testItemForSale: seller address is not the seller");
  }


  // ** buyItem tests **
  // Test to buy item
  function testBuyItem () public {
    (bool result,) = buyer.buyItem(sku, price);
    Assert.isTrue(result, "Error, testBuyItem: unable to buy item.");
  }

  // Test to buy unlisted item
  function testBuyUnlistedItem () public {
    (bool result,) = buyer.buyItem(99, price);
    Assert.isFalse(result, "Error, testBuyUnlistedItem: item 99 was purchased.");
  }

  // Test to buy item not ForSale - modifier forSale
  function testBuyItemNotForSale () public {
    (bool result,) = buyer.buyItem(sku, price);
    Assert.isTrue(result, "Error, testBuyItemNotForSale: unable to buy item");

    uint _state = supplyChain.getState(sku);
    Assert.equal(_state, uint(State.Sold), "Error, testBuyItemNotForSale: item does not have State.Sold");
 
    (bool result2,) = buyer.buyItem(sku, price);
    Assert.isFalse(result2, "Error, testBuyItemNotForSale: able to buy item with State.Sold");
  }

  // Test to buy listed item for lower than listed price - modifier paidEnough
  function testBuyListedItemAtLowPrice () public {
    (bool result,) = buyer.buyItem(sku, price - 1);
    Assert.isFalse(result, "Error, testBuyListedItemAtLowPrice: item was purchased at (price-1)");
  }


  // ** shipItem tests **
  // Test shipItem ships, by seller
  function testShipItemShips () public {
    (bool result,) = buyer.buyItem(sku, price);
    Assert.isTrue(result, "Error, testBuyItemNotForSale: unable to buy item");

    (bool result2,) = seller.shipItem(sku); 
    Assert.isTrue(result2, "Error, testShipItemShips: unable to shipItem");

    uint _state = supplyChain.getState(sku);
    Assert.equal(_state, uint(State.Shipped), "Error, testShipItemShips: item not marked State.Shipped");
  }

  // Test shipItem not in Sold state, modified sold
  function testShipUnsold () public {
    uint _state = supplyChain.getState(sku);
    Assert.equal(_state, uint(State.ForSale), "Error, testShipUnsold: item does not have State.ForSale");

    (bool result,) = seller.shipItem(sku);
    Assert.isFalse(result, "Error, testShipUnsold: able to ship item in state ForSale");
  }

  // Test buyer attempt to shipItem, modifier verifyCaller
  function testBuyerShipAttempt () public {
    buyer.buyItem(sku, price);
    uint _state = supplyChain.getState(sku);
    Assert.equal(_state, uint(State.Sold), "Error, testBuyerShipAttempt: item not marked State.Sold");

    (bool result,) = buyer.shipItem(sku);
    Assert.isFalse(result, "Error, testBuyerShipAttempt: buyer was able to ship item");
  }


  // ** receiveItem tests **
  // Test receiveItem marks as Received, by buyer
  function testReceiveItem () public {
    buyer.buyItem(sku, price);
    seller.shipItem(sku);

    (bool result,) = buyer.receiveItem(sku);
    Assert.isTrue(result, "Error, testReceiveItem: unable to mark item as received");

    uint _state = supplyChain.getState(sku);
    Assert.equal(_state, uint(State.Received), "Error, testReceiveItem: item not marked as State.Received");
  }


  // Test receiveItem not in Shipped state, modified shipped
  function testReceiveItemUnshipped () public {
    buyer.buyItem(sku, price);
    
    uint _state = supplyChain.getState(sku);
    Assert.equal(_state, uint(State.Sold), "Error, testReceiveItemUnshipped: item does not have State.Sold");

    (bool result,) = buyer.receiveItem(sku);
    Assert.isFalse(result,
    "Error, testReceiveItemUnshipped: buyer was able to receive item marked as State.Sold (not Shipped)");
  }


  // Allow this contract to receive ether
  function () external payable {}

}


// ThrowProxy contract
contract ThrowProxy {
  address target;

  constructor (address _target) public {
    target = _target;
  }

  function addItem (string memory _name, uint _price) public {
    SupplyChain(target).addItem(_name, _price);
  }

  function buyItem (uint _sku, uint price) public returns (bool, bytes memory) {
    return address(target).call.value(price)(abi.encodeWithSignature("buyItem(uint256)", _sku));
  }

  function shipItem (uint _sku) public returns (bool, bytes memory) {
    return address(target).call(abi.encodeWithSignature("shipItem(uint256)", _sku));
  }

  function receiveItem (uint _sku) public returns (bool, bytes memory) {
    return address(target).call(abi.encodeWithSignature("receiveItem(uint256)", _sku));
  }

  function getState (uint _sku) public view returns (uint) {
   SupplyChain(target).getState(_sku);
  }

  // Fallback, to allow contract to receive ether
  function () external payable {}

}
