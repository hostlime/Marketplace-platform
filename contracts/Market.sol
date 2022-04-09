// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MyTokenMarket is ERC20, AccessControl {

    // Роль моста
    bytes32 public constant MARKET_ROLE = keccak256("MARKET_ROLE");

    //constructor() ERC20("MyTokenForBridge", "MTK") {}
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MARKET_ROLE, msg.sender);
        //_mint(msg.sender, 1000_000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external onlyRole(MARKET_ROLE) {
        _mint(to, amount);
    }
    function burn(address user, uint256 amount) external onlyRole(MARKET_ROLE) {
        _burn(user, amount);
    }
}

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
contract Market is ReentrancyGuard, AccessControl{

   MyTokenMarket private _token;

   uint256 private duringTimeRound;
   uint256 private multPriceSale;       // Увеличение стоимости с каждым раундом = 100/103 + 4/1_000_000
   
    uint256 public refBonusLevel1 = 5;        // Бонус реферала первого уровня
    uint256 public refBonusLevel2 = 3;     // Бонус реферала второго уровня

// Стартуем ЯКОБЫ с трейд раунда

    // трейд раун
    enum RoundType {Sale, Trade}
    struct CurrentRound {
        uint256 volumeTradeETH; // Объем ETH в трейд раунде
        uint256 priceTokenSale; // Текущая стоимость токена
        //uint256 supply;         // Объем текущего раунда   ?????
        //uint256 roundId;        // ID текущего раунда ???????
        uint256 finishTime;     // Время завершения раунда
        uint256 numOrder;       // Количество ордеров в раунде ТРЕЙД
        RoundType round;        // Если сейл раунд то true
    }
    CurrentRound public currentRound;


    struct Order {
        uint256 mount;  // Количество
        uint256 price;  // Стоисмость в eth
        address owner;  // Владелец
    }
    mapping (uint256 => Order) public ordersTrade;
    mapping (address => address) public referer;

    //первый раунд !!!!сейла!!!, но якобы уже был трейд раунд и натороговали на 1eth
    constructor(MyTokenMarket _token_, uint duringTime){
        _token = _token_;
        duringTimeRound = duringTime;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // временно!!!!!!!!! ТИПА ПЕРВЫЙ ТРЕЙД РАУНД прошел 
        currentRound = CurrentRound({
            volumeTradeETH: 1 ether,
            priceTokenSale: 5825242718000,
            finishTime: block.timestamp,
            round: RoundType.Trade,
            numOrder: 0
        });
    }

    function registr(address _referer) external {
        require(_referer != address(0x0),"ERROR: Referer is not valid"); 
        require(referer[_referer] != address(0x0),"ERROR: Referer has not been registered before"); 
        referer[msg.sender] = _referer;
    }

    function startSaleRound() external {
        require(currentRound.round == RoundType.Trade,"Sale round has already started");
        require(currentRound.finishTime < block.timestamp, "Trade round hasnt finished");

        // Возвращаем все ордера
        for(uint256 i = currentRound.numOrder - 1; i >= 0; i--){
            if(ordersTrade[i].mount > 0){
               _token.transferFrom(address(this), ordersTrade[i].owner, ordersTrade[i].mount);
            }
        }
        currentRound.numOrder = 0;

        currentRound.round = RoundType.Sale;
        // 0,000004 eth = 4000 gwei
        // Price ETH = lastPrice*1,03+0,000004 = (lastPrice*103 + 0,000004*100)/100
        currentRound.priceTokenSale = (currentRound.priceTokenSale * 103) / 100 + 4000 gwei;
        currentRound.finishTime = block.timestamp + duringTimeRound;

        _token.mint(address(this), currentRound.volumeTradeETH / currentRound.priceTokenSale);
    }

    // Покупка токенов в период сейла
    function buyTokenSale() external payable nonReentrant {
        require(currentRound.round == RoundType.Sale,"Sale round hasn't started yet");
        require(currentRound.finishTime > block.timestamp, "Sale round closed");

        // Рассчитываем количество купленных токенов
        uint256 mountBuyToken = msg.value / currentRound.priceTokenSale;
        // Переводим токуены
        _token.transfer(msg.sender, mountBuyToken);
        
        // Проверяем наличие реферала первого уровня
        // если есть то выплачиваем
        address payable ref = payable (referer[msg.sender]);
        if(address(0x0) != ref){
            _sendCall(ref, (msg.value * refBonusLevel1) / 100);

            ref = payable (referer[ref]);
            if(address(0x0) != ref) _sendCall(ref, (msg.value * refBonusLevel2) / 100);
        } 
    } 

    function startTradeRound() external payable {
        require(currentRound.round == RoundType.Sale,"Trade round has already started");
        uint256 tokenBalance = _token.balanceOf(address(this));
        
        if(tokenBalance > 0){
            if(currentRound.finishTime > block.timestamp)revert("Sale round hasn't finished");
            // Время раунда сейла закончилось и поэтому сжигаем нераспроданные токены
            _token.burn(address(this), tokenBalance);
        }
        
        currentRound.round = RoundType.Trade;
        currentRound.volumeTradeETH = 0; 
        currentRound.finishTime = block.timestamp + duringTimeRound;
    } 

    // выкуп токенов
    function redeemOrder(uint256 _idOrder) payable external nonReentrant {
        require(currentRound.round == RoundType.Trade,"Redeem order is available only in the trade round");
        require(currentRound.finishTime > block.timestamp, "Trade round closed");
        require(_idOrder < currentRound.numOrder, "Such order id does not exist");

        Order storage _order = ordersTrade[_idOrder];
        
        uint256 _mountTokenForEth = msg.value / _order.price;
        require(_order.mount >= _mountTokenForEth, "You can not buy more than the order");

        _token.transferFrom(address(this), msg.sender, _mountTokenForEth);
        _order.mount -= _mountTokenForEth;
        currentRound.volumeTradeETH += msg.value;

        // Выплачиваем продавцу
        uint256 mountEthBonus = (_order.price * 5) / 100;   // 5%
        _sendCall(payable(_order.owner), _order.price - mountEthBonus);

        // Выплачиваем рефералам по 2,5%
        address payable ref = payable (referer[_order.owner]);
        if(address(0x0) != ref){
            mountEthBonus /= 2;  // 2.5%
            _sendCall(ref, mountEthBonus);

            ref = payable (referer[ref]);
            if(address(0x0) != ref) _sendCall(ref, mountEthBonus);
        }

    } 

    // Отмена ордера
    function removeOrder(uint256 _idOrder) external {
        require(currentRound.round == RoundType.Trade,"Remove order is available only in the trade round");
        require(currentRound.finishTime > block.timestamp, "Trade round closed");

        Order storage _order = ordersTrade[_idOrder];
        require(_idOrder < currentRound.numOrder, "Such order id does not exist");
        require(_order.owner == msg.sender, "Only owner can remove order");

        if(_order.mount > 0){
             _token.transferFrom(address(this), _order.owner, _order.mount);
            _order.mount = 0;
        }
    } 

    function addOrder(uint256 _mount, uint256 _price) external {
        require(currentRound.round == RoundType.Trade,"Add Order is available only in the trade round");
        require(currentRound.finishTime > block.timestamp, "Trade round closed");

        _token.transferFrom(msg.sender, address(this), _mount);
        // Добавляем в массив ордеров
        ordersTrade[currentRound.numOrder++] = Order({
            mount: _mount,  // Количество
            price: _price,  // Стоисмость в eth
            owner: msg.sender  // Владелец
        });
    }

    // call in combination with re-entrancy guard is the recommended method to use after December 2019.
    function _sendCall(address payable _to, uint256 _value) private {
        // Call returns a boolean value indicating success or failure.
        // This is the current recommended method to use.
        (bool sent,  ) = _to.call{value: _value}("");
        require(sent, "Failed to send Ether");
    }
}

/*
ТЗ площадка для продажи ACDM 

-Написать смарт контракт ACDMPlatform
-Написать полноценные тесты к контракту
-Написать скрипт деплоя
-Задеплоить в тестовую сеть
-Написать таск на на основные методы
-Верифицировать контракт

Есть 2 раунда «Торговля» и «Продажа», которые следуют друг за другом, начиная с раунда продажи.
Каждый раунд длится 3 дня.

Основные понятия:
Раунд «Sale» - В данном раунде пользователь может купить токены ACDM по фиксируемой цене у платформы за ETH.
Раунд «Trade» - в данном раунде пользователи могут выкупать друг у друга токены ACDM за ETH.
Реферальная программа — реферальная программа имеет два уровня, пользователи получают реварды в ETH.

Описание раунда «Sale»:
Цена токена с каждым раундом растет и рассчитывается по формуле (смотри excel файл). 
Количество выпущенных токенов в каждом Sale раунде разное и зависит от общего объема торгов в раунде «Trade». 
Раунд может закончиться досрочно если все токены были распроданы. По окончанию раунда не распроданные токены сжигаются. 
Самый первый раунд продает токенны на сумму 1ETH (100 000 ACDM)
Пример расчета:
объем торгов в trade раунде = 0,5 ETH (общая сумма ETH на которую пользователи наторговали в рамках одного trade раунд)
0,5 / 0,0000187 = 26737.96. (0,0000187 = цена токена в текущем раунде)
следовательно в Sale раунде будет доступно к продаже 26737.96 токенов ACDM.

Описание раунда «Trade»:
user_1 выставляет ордер на продажу ACDM токенов за определенную сумму в ETH. 
User_2 выкупает токены за ETH. Ордер может быть выкуплен не полностью. 
Также ордер можно отозвать и пользователю вернутся его токены, которые еще не были проданы. 
Полученные ETH сразу отправляются пользователю в их кошелек metamask. 
По окончанию раунда все открытые ордера закрываются и оставшиеся токены отправляются их владельцам.

Описание Реферальной программы:
При регистрации пользователь указывает своего реферера (Реферер должен быть уже зарегистрирован на платформе).
При покупке в Sale раунде токенов ACDM, рефереру_1 отправится 5% от его покупки, рефереру_2 отправится 3%, 
сама платформа получит 92% в случае отсутствия рефереров всё получает платформа.
При покупке в Trade раунде пользователь, который выставил ордер на продажу ACDM токенов 
получит 95% ETH и по 2,5% получат рефереры, в случае их отсутствия платформа забирает эти проценты себе.

Price ETH = lastPrice*1,03+0,000004
Пример расчета цены токена: 0,0000100*1,03+0,000004 = 0,0000143

Ссылки: 
https://drive.google.com/file/d/1gj3yihfvJl1WXPJtegO4N5j6q-Rd9ZMn/view?usp=sharing
Уязвимости в безопасности  https://russianblogs.com/article/857220099/
ReentrancyGuard https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard
*/