pragma solidity ^0.5.0;

contract SupplyChain {

  address public owner;
  uint public skuCount;

  mapping (uint => Item) public items;
  
  enum State {ForSale, Sold, Shipped, Received} 
    State current_state;

  struct Item {
    string name;
    uint sku;
    uint price;
    State state;
    address payable seller; 
    address payable buyer;
  }

  event ForSale (uint indexed sku);
  event Sold (uint indexed sku);
  event Shipped (uint indexed sku);
  event Received (uint indexed sku);
  
  modifier isOwner () { require (msg.sender == owner, "msg.sender not owner"); _;}
  modifier verifyCaller (address _address) { require (msg.sender == _address, "msg.sender not owner"); _;}
  modifier paidEnough(uint _price) { require(msg.value >= _price, "msg.value less than price"); _;}
  modifier checkValue(uint _sku) {
    _;
    uint _price = items[_sku].price;
    uint amountToRefund = msg.value - _price;
    items[_sku].buyer.transfer(amountToRefund);
  }

  modifier forSale (uint _sku) { 
    // Added to verify that the requested SKU item exists, since all items have a seller
    require (items[_sku].seller != address(0), "Seller address is 0x0; item does not exist"); 
    require (items[_sku].state == State.ForSale, "State is not ForSale"); 
    _;
    }
  modifier sold (uint _sku) { require (items[_sku].state == State.Sold, "State is not Sold"); _;}
  modifier shipped (uint _sku) { require (items[_sku].state == State.Shipped, "State is not Shipped"); _;}
  modifier received (uint _sku) { require (items[_sku].state == State.Received, "State is not Received"); _;}
  
  constructor() public payable {
    owner = msg.sender;
    skuCount = 0;
  }

  function addItem(string memory _name, uint _price) 
    public 
    returns(bool)
  {
    emit ForSale(skuCount);
    items[skuCount] = Item({name: _name, sku: skuCount, price: _price, state: State.ForSale, seller: msg.sender, buyer: address(0)});
    skuCount = skuCount + 1;
    return true;
  }

  /* Add a keyword so the function can be paid. This function should transfer money 
    to the seller, set the buyer as the person who called this transaction, and set the state
    to Sold. Be careful, this function should use 3 modifiers to check if the item is for sale,
    if the buyer paid enough, and check the value after the function is called to make sure the buyer is
    refunded any excess ether sent. Remember to call the event associated with this function!*/
  function buyItem(uint sku)
    forSale(sku) 
    paidEnough(items[sku].price) 
    checkValue(sku)
    payable
    public 
  {
    items[sku].seller.transfer(items[sku].price);
    items[sku].buyer = msg.sender;
    items[sku].state = State.Sold;
    emit Sold(sku);
  }

  function shipItem(uint sku)
    sold(sku) 
    verifyCaller(items[sku].seller)
    public
  {
    items[sku].state = State.Shipped;
    emit Shipped(sku);  
  }

  function receiveItem(uint sku)
    shipped(sku) 
    verifyCaller(items[sku].buyer)
    public
  {
    items[sku].state = State.Received;
    emit Received(sku);  
  }


  /* We have these functions completed so we can run tests, just ignore it :) */
  function fetchItem(uint _sku) public view 
    returns (string memory name, uint sku, uint price, uint state, address seller, address buyer) 
  {
    name = items[_sku].name;
    sku = items[_sku].sku;
    price = items[_sku].price;
    state = uint(items[_sku].state);
    seller = items[_sku].seller;
    buyer = items[_sku].buyer;
    return (name, sku, price, state, seller, buyer);
  }

  function getState(uint sku) 
    view  
    public 
    returns (uint)
  { 
    return uint(items[sku].state); 
  }

   // Fallback function
   function () external {
    revert();
  }

}

