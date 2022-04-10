import { expect, assert } from "chai";
import { ethers, waffle } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

// Функция для получения timestamp блока
async function getTimestampBlock(bn: any) {
  return (await ethers.provider.getBlock(bn)).timestamp
}

describe.only("Market platform", function () {

  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;

  let market: any;
  let token: any;

  const duringTimeRound = 3 * 24 * 60 * 60;
  const startVolumeTradeETH = ethers.utils.parseEther("1");  // recommended 1 ether = 1000000000000000000 Wei
  const startPriceTokenSale = ethers.utils.parseEther("0.00001"); // recommended 0.00001 ether = 10000000000000 Wei

  const buyUser = ethers.utils.parseEther("0.25");

  // создаём экземпляр контрактов
  beforeEach(async () => {
    [owner, user1, user2, user3] = await ethers.getSigners();

    // Token MTK
    const Token = await ethers.getContractFactory("MyTokenMarket");
    token = await Token.connect(owner).deploy("MyTokenMarket", "MTK");
    await token.connect(owner).deployed();

    // Market
    const Market = await ethers.getContractFactory("Market");
    market = await Market.connect(owner).deploy(
      token.address,
      duringTimeRound,
      startPriceTokenSale,
      startVolumeTradeETH);
    await market.connect(owner).deployed();

    // Назначаем роль MARKET_ROLE для управления токенами
    let MARKET_ROLE = await token.connect(owner).MARKET_ROLE();
    await token.grantRole(MARKET_ROLE, market.address);
  });

  // Проверяем все контракты на деплой
  it('Checking that contract token is deployed', async () => {
    assert(token.address);
  });

  it('Checking that contract market is deployed', async () => {
    assert(market.address);
  });
  it('Checking function registration()', async () => {

    // При регистрации пользователь указывает своего реферера (Реферер должен быть уже зарегистрирован на платформе).
    // Проверяем первого рефера от которого пойдут все рефералы
    expect(await market.connect(user1)
      .referer(owner.address)).to.be.equal(market.address)

    // Проверка require
    await expect(market.connect(user1)
      .registration(ethers.constants.AddressZero))
      .to.be.revertedWith(
        "ERROR: Referer is not valid"
      )

    await expect(market.connect(user1)
      .registration(user2.address))
      .to.be.revertedWith(
        "ERROR: Referer hasn't been registered before"
      )
    // Регаемся
    await market.connect(user1).registration(owner.address)
    // Проверяем регистрацию
    expect(await market.connect(user1)
      .referer(user1.address)).to.be.equal(owner.address)
  });

  it("Checking function startSaleRound()", async () => {

    // запускаем раунд сейла
    await market.connect(user1).startSaleRound()
    //console.log((await market.connect(user1).currentRound()))

    // Проверяем все переменные
    let currentRound = await market.connect(user1).currentRound()
    expect(currentRound['volumeTradeETH']).to.be.equal(startVolumeTradeETH)
    expect(currentRound['priceTokenSale']).to.be.equal(startPriceTokenSale)
    expect(currentRound['numOrder']).to.be.equal(0)
    expect(currentRound['round']).to.be.equal(0)
    // Проверяем время
    const txTime = await getTimestampBlock(currentRound.blockNumber)
    expect(currentRound.finishTime).to.be.equal(txTime + duringTimeRound)
    // Проверяем сколько токенов заминтилось
    expect(await token.connect(user1)
      .balanceOf(market.address)).to.be.equal((startVolumeTradeETH).div(startPriceTokenSale))

    // пытаемся повторно запустить раунд сейла
    await expect(market.connect(user1)
      .startSaleRound())
      .to.be.revertedWith(
        "Sale round has already started"
      )
  });
  it("Checking function startSaleRound() after tradeRound", async () => {

    // запускаем раунд сейла
    await market.connect(user1).startSaleRound()

    let mountTokensForbuyUser = (buyUser).div(startPriceTokenSale);

    // Покупатели покупают
    await market.connect(user1).buyTokenSale({ value: buyUser })
    await market.connect(user2).buyTokenSale({ value: buyUser })
    await market.connect(user3).buyTokenSale({ value: buyUser })

    // проверяем балансы покупателей и маркета
    expect(await token.balanceOf(user1.address))
      .to.be.equal(mountTokensForbuyUser)
    expect(await token.balanceOf(user2.address))
      .to.be.equal(mountTokensForbuyUser)
    expect(await token.balanceOf(user3.address))
      .to.be.equal(mountTokensForbuyUser)
    // баланс токенов которые остались на маркете
    expect(await token.balanceOf(market.address))
      .to.be.equal(mountTokensForbuyUser)

    // Смещаем время на 3дня
    await ethers.provider.send("evm_increaseTime", [duringTimeRound])
    await ethers.provider.send("evm_mine", [])

    // Запускаем трейд раунд
    await market.connect(user1).startTradeRound()
    // Высталяем ордера на продажу, но предарительно апрувим
    await token.connect(user1).approve(market.address, mountTokensForbuyUser)
    await token.connect(user3).approve(market.address, mountTokensForbuyUser)
    await market.connect(user1).addOrder(mountTokensForbuyUser, startPriceTokenSale.toNumber() + 1)
    await market.connect(user3).addOrder(mountTokensForbuyUser, startPriceTokenSale.toNumber() + 2)
    // Проверяем балансы что токены ушли на контракт
    expect(await token.balanceOf(user1.address))
      .to.be.equal(0)
    expect(await token.balanceOf(user3.address))
      .to.be.equal(0)

    // Смещаем время на 3дня
    await ethers.provider.send("evm_increaseTime", [duringTimeRound])
    await ethers.provider.send("evm_mine", [])

    // Снова запускаем раунд сейла
    await market.connect(user1).startSaleRound()

    // Проверяем все переменные
    let currentRound = await market.connect(user1).currentRound()
    expect(currentRound['volumeTradeETH']).to.be.equal((mountTokensForbuyUser).div(startPriceTokenSale))
    let newprice = (startPriceTokenSale.toNumber() * 103) / 100 + 4 * 10 ** 12;
    expect(currentRound['priceTokenSale']).to.be.equal(newprice)
    expect(currentRound['numOrder']).to.be.equal(0)
    expect(currentRound['round']).to.be.equal(0)

    // Проверяем время
    const txTime = await getTimestampBlock(currentRound.blockNumber)
    expect(currentRound.finishTime).to.be.equal(txTime + duringTimeRound)

    // проверяем балансы покупателей и маркета все токены должны вернуться владельцам
    expect(await token.balanceOf(user1.address))
      .to.be.equal(mountTokensForbuyUser)
    expect(await token.balanceOf(user2.address))
      .to.be.equal(mountTokensForbuyUser)
    expect(await token.balanceOf(user3.address))
      .to.be.equal(mountTokensForbuyUser)
    expect(await token.balanceOf(market.address))
      .to.be.equal(0)
  });
  it("Checking function buyTokenSale()", async () => {

    // Проверяем require
    await expect(market.connect(user1).buyTokenSale()).to.be.revertedWith(
      "Sale round hasn't started yet"
    );
    // запускаем раунд сейла
    await market.connect(user1).startSaleRound()

    let mountTokensForbuyUser = (buyUser).div(startPriceTokenSale);

    // Регистрируем пользователей
    await market.connect(user1).registration(owner.address)
    await market.connect(user2).registration(user1.address)
    await market.connect(user3).registration(user2.address)

    let balanceOwner = await owner.getBalance();
    let balanceUser1 = await user1.getBalance();
    let balanceUser2 = await user2.getBalance();
    let balanceUser3 = await user3.getBalance();
    let bonus1 = (buyUser.mul(5)).div(100)    // 3%
    let bonus2 = (buyUser.mul(3)).div(100)    // 2%
    //console.log(user1.address, balanceUser1, user2.address, balanceUser2)
    //console.log(buyUser, bonus1, bonus2)
    //console.log(balanceOwner)

    // Покупатели покупают
    await market.connect(user3).buyTokenSale({ value: buyUser })
    // проверяем что бонус пришел реферу
    expect(await user1.getBalance()).to.be.equal(balanceUser1.add(bonus2))
    expect(await user2.getBalance()).to.be.equal(balanceUser2.add(bonus1))

    // Смещаем время на 3дня
    await ethers.provider.send("evm_increaseTime", [duringTimeRound])
    await ethers.provider.send("evm_mine", [])

    // Проверяем require
    await expect(market.connect(user1).buyTokenSale()).to.be.revertedWith(
      "Sale round closed"
    );
  });

});
