// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Token.sol";

contract Market is ReentrancyGuard, AccessControl {
    MyTokenMarket private _token;

    uint256 private duringTimeRound;
    uint256 private multPriceSale; // Увеличение стоимости с каждым раундом = 100/103 + 4/1_000_000

    uint256 public refBonusLevel1 = 5; // Бонус реферала первого уровня
    uint256 public refBonusLevel2 = 3; // Бонус реферала второго уровня
    uint256 private priceNextRoundSale; // Цена токена следующего раунда сейла
    enum RoundType {
        Sale,
        Trade
    }
    struct CurrentRound {
        uint256 volumeTradeETH; // Объем ETH в трейд раунде
        uint256 priceTokenSale; // Текущая стоимость токена
        uint256 finishTime; // Время завершения раунда
        uint256 numOrder; // Количество ордеров в раунде ТРЕЙД
        RoundType round; // Если сейл раунд то true
    }
    CurrentRound public currentRound;

    struct Order {
        uint256 mount; // Количество
        uint256 price; // Стоисмость в eth
        address owner; // Владелец
    }
    mapping(uint256 => Order) public ordersTrade;
    mapping(address => address) public referer;

    //первый раунд !!!!сейла!!!, но якобы уже был трейд раунд и натороговали на 1eth
    constructor(
        MyTokenMarket _token_,
        uint256 duringTime,
        uint256 _priceTokenSale,
        uint256 _volumeTradeETH
    ) {
        _token = _token_;
        duringTimeRound = duringTime;
        priceNextRoundSale = _priceTokenSale; // recommended 1 ether = 1000000000000000000 Wei
        currentRound.volumeTradeETH = _volumeTradeETH; // recommended 0.00001 ether = 10000000000000 Wei
        currentRound.finishTime = block.timestamp;
        currentRound.round = RoundType.Trade;
        // регистрируем первого реферала чтобы пользователи дальше могли регистрироваться и указывать в качестве рефера создателя контракт
        referer[msg.sender] = msg.sender;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function registration(address _referer) external {
        require(_referer != address(0x0), "ERROR: Referer is not valid");
        require(
            referer[_referer] != address(0x0),
            "ERROR: Referer hasn't been registered before"
        );
        require(_referer != msg.sender, "ERROR: you can't enter your address");

        referer[msg.sender] = _referer;
    }

    function startSaleRound() external {
        require(
            currentRound.round == RoundType.Trade,
            "Sale round has already started"
        );

        // Возвращаем все ордера
        for (uint256 i = 0; i < currentRound.numOrder; i++) {
            if (ordersTrade[i].mount > 0) {
                _token.transfer(ordersTrade[i].owner, ordersTrade[i].mount);
            }
        }
        currentRound.numOrder = 0;

        currentRound.round = RoundType.Sale;
        // 0,000004 eth = 4000 gwei
        // Price ETH = lastPrice*1,03+0,000004 = (lastPrice*103 + 0,000004*100)/100
        currentRound.priceTokenSale = priceNextRoundSale;
        priceNextRoundSale =
            (currentRound.priceTokenSale * 103) /
            100 +
            4000 gwei;
        currentRound.finishTime = block.timestamp + duringTimeRound;

        _token.mint(
            address(this),
            currentRound.volumeTradeETH / currentRound.priceTokenSale
        );
    }

    // Покупка токенов в период сейла
    function buyTokenSale() external payable nonReentrant {
        require(
            currentRound.round == RoundType.Sale,
            "Sale round hasn't started yet"
        );
        require(currentRound.finishTime > block.timestamp, "Sale round closed");

        // Рассчитываем количество купленных токенов
        uint256 mountBuyToken = msg.value / currentRound.priceTokenSale;
        // Переводим токуены
        _token.transfer(msg.sender, mountBuyToken);

        // Проверяем наличие реферала первого уровня
        // если есть то выплачиваем
        address payable ref = payable(referer[msg.sender]);
        if (address(0x0) != ref) {
            _sendCall(ref, (msg.value * refBonusLevel1) / 100);
            // У рефера всегда есть рефер
            _sendCall(
                payable(referer[ref]),
                (msg.value * refBonusLevel2) / 100
            );
        }
    }

    function startTradeRound() external payable {
        require(
            currentRound.round == RoundType.Sale,
            "Trade round has already started"
        );
        uint256 tokenBalance = _token.balanceOf(address(this));

        if (tokenBalance > 0) {
            if (currentRound.finishTime > block.timestamp)
                revert("Sale round hasn't finished");
            // Время раунда сейла закончилось и поэтому сжигаем нераспроданные токены
            _token.burn(address(this), tokenBalance);
        }

        currentRound.round = RoundType.Trade;
        currentRound.volumeTradeETH = 0;
        currentRound.finishTime = block.timestamp + duringTimeRound;
    }

    // выкуп токенов
    function redeemOrder(uint256 _idOrder) external payable nonReentrant {
        require(
            currentRound.round == RoundType.Trade,
            "Redeem order is available only in the trade round"
        );
        require(
            currentRound.finishTime > block.timestamp,
            "Trade round closed"
        );
        require(
            _idOrder < currentRound.numOrder,
            "Such order id does not exist"
        );

        Order storage _order = ordersTrade[_idOrder];

        uint256 _mountTokenForEth = msg.value / _order.price;
        require(
            _order.mount >= _mountTokenForEth,
            "You can not buy more than the order"
        );

        _token.transfer(msg.sender, _mountTokenForEth);
        _order.mount -= _mountTokenForEth;
        currentRound.volumeTradeETH += msg.value;

        // Выплачиваем продавцу, но вычитаем mountEthBonus
        uint256 mountEthBonus = (_mountTokenForEth * _order.price * 5) / 100; // 5%
        _sendCall(
            payable(_order.owner),
            _mountTokenForEth * _order.price - mountEthBonus
        );

        // Выплачиваем рефералам по 2,5%
        address payable ref = payable(referer[_order.owner]);
        if (address(0x0) != ref) {
            mountEthBonus /= 2; // 2.5%
            _sendCall(ref, mountEthBonus);

            ref = payable(referer[ref]);
            _sendCall(ref, mountEthBonus);
        }
    }

    // Отмена ордера
    function removeOrder(uint256 _idOrder) external {
        require(
            currentRound.round == RoundType.Trade,
            "Remove order is available only in the trade round"
        );
        require(
            currentRound.finishTime > block.timestamp,
            "Trade round closed"
        );

        Order storage _order = ordersTrade[_idOrder];
        require(
            _idOrder < currentRound.numOrder,
            "Such order id does not exist"
        );
        require(_order.owner == msg.sender, "Only owner can remove order");

        if (_order.mount > 0) {
            _token.transfer(_order.owner, _order.mount);
            _order.mount = 0;
        }
    }

    function addOrder(uint256 _mount, uint256 _price) external {
        require(
            currentRound.round == RoundType.Trade,
            "Add Order is available only in the trade round"
        );
        require(
            currentRound.finishTime > block.timestamp,
            "Trade round closed"
        );

        _token.transferFrom(msg.sender, address(this), _mount);
        // Добавляем в массив ордеров
        ordersTrade[currentRound.numOrder++] = Order({
            mount: _mount, // Количество
            price: _price, // Стоисмость в eth
            owner: msg.sender // Владелец
        });
    }

    function withdrawAll(address payable _user)
        external
        payable
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _sendCall(_user, address(this).balance);
    }

    // call in combination with re-entrancy guard is the recommended method to use after December 2019.
    function _sendCall(address payable _to, uint256 _value) private {
        // Call returns a boolean value indicating success or failure.
        // This is the current recommended method to use.
        (bool success, ) = _to.call{value: _value}("");
        require(success, "Transfer failed.");
    }
}
