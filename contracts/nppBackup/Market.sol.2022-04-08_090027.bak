// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


contract Market {

   address private _token;

   uint256 private duringTimeRound;
   uint256 private multPriceSale; // Увеличение стоимости с каждым раундом = 100/103 + 4/1_000_000
   


// Стартуем ЯКОБЫ с трейд раунда

    // трейд раун

    struct CurrentRound {
        uint256 volumeTradeETH; // Объем ETH в трейд раунде
        uint256 priceTokenSale; // Текущая стоимость токена
        uint256 supply;         // Объем текущего раунда
        uint256 roundId;        // ID текущего раунда
    }
    CurrentRound public currentRound;

    struct Round {
        uint256 finishTime; // Время завершения раунда
        //uint256 totalSupply; 
        uint256 price;
    }
    mapping (uint256 => Round) public rounds;
    mapping (address => address) public referer;
    //первый раунд !!!!сейла!!!, но якобы уже был трейд раунд и натороговали на 1eth
    constructor(address _token_, uint duringTime){
        _token = _token_;
        duringTimeRound = duringTime;

        // временно!!!!!!!!! ТИПА ПЕРВЫЙ ТРЕЙД РАУНД прошел 
        currentRound = CurrentRound({
            volumeTradeETH: 1 ether,
            priceTokenSale: 1 ether / 100_000,
            supply: 100_000 * (10 ** 18),
            roundId:0
        });
    }

    function registr(address _referer) external {
        require(_referer != address(0x0),"ERROR: Referer is not valid"); 
        referer[msg.sender] = _referer;
    } 

    function startSaleRound() external{
        rounds[currentRound.roundId + 1] = Round({
            finishTime: block.timestamp + duringTimeRound,
            price: (currentRound.priceTokenSale * 103/100) + 4000 gwei
        });

        currentRound.roundId++;

        currentRound = CurrentRound({
            volumeTradeETH: 0,
            priceTokenSale: 1 ether / 100_000 * (10 ** 18),
            supply: 100_000 * (10 ** 18),
            roundId: currentRound.roundId + 1
        });

    } 

    function buyToken() external{

    } 

    function startTradeRound() external payable{

        currentRound.volumeTradeETH += msg.value;
    } 
    // выкуп токенов
    function redeemOrder() payable external{

    } 

    function removeOrder() external{

    } 

    function addOrder() external{

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