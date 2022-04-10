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
  it.only("Checking function startSaleRound() after tradeRaund", async () => {

    // запускаем раунд сейла
    await market.connect(user1).startSaleRound()

    let tx = await market.connect(user1).buyTokenSale({ value: buyUser })
    expect(await token.balanceOf(user1.address))
      .to.be.equal((buyUser).div(startPriceTokenSale))
    expect(await token.balanceOf(market.address))
      .to.be.equal(((startVolumeTradeETH).div(startPriceTokenSale)).sub((buyUser).div(startPriceTokenSale)))


    console.log(await token.balanceOf(market.address))
    console.log(await token.balanceOf(user1.address))

    /*
        await expect(() => tx)
          .to.changeEtherBalance(market.address, buyUser);
    
        /*
          await expect(market.connect(user1).buyTokenSale({ value: buyUser }))
            .to.changeEtherBalances([user1.address, market.address], [-buyUser, buyUser]);
      
           
           // Смещаем время на 3дня
           await ethers.provider.send("evm_increaseTime", [duringTimeRound])
           await ethers.provider.send("evm_mine", [])
       
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
             */
  });

});
