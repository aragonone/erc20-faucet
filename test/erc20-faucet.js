const ERC20Token = artifacts.require('ERC20TokenMock')
const ERC20Faucet = artifacts.require('ERC20FaucetMock')
const { assertRevert } = require('./helpers/assertThrow')
const { bn, assertBn, bigExp } = require('./helpers/numbers')
const { assertEvent, assertAmountOfEvents } = require('./helpers/assertEvent')

const ONE_MONTH = 60 * 60 * 24 * 30

contract('ERC20Faucet', ([_, owner, donor, account, unknownToken]) => {
  let faucet, token, anotherToken

  const TOKEN_QUOTA_PERIOD = ONE_MONTH
  const TOKEN_QUOTA_AMOUNT = bigExp(100, 18)

  const ANOTHER_TOKEN_QUOTA_PERIOD = ONE_MONTH * 2
  const ANOTHER_TOKEN_QUOTA_AMOUNT = bigExp(50, 18)

  beforeEach('deploy contracts', async () => {
    token = await ERC20Token.new('Token', 'TOK', 18)
    anotherToken = await ERC20Token.new('Another Token', 'ATOK', 18)

    const TOKENS = [token.address, anotherToken.address]
    const PERIODS = [TOKEN_QUOTA_PERIOD, ANOTHER_TOKEN_QUOTA_PERIOD]
    const AMOUNTS = [TOKEN_QUOTA_AMOUNT, ANOTHER_TOKEN_QUOTA_AMOUNT]
    faucet = await ERC20Faucet.new(TOKENS, PERIODS, AMOUNTS, { from: owner })
  })

  beforeEach('approve tokens to the faucet', async () => {
    const balance = bigExp(10000, 18)
    await token.generateTokens(donor, balance)
    await token.approve(faucet.address, balance, { from: donor })
  })

  describe('constructor', () => {
    it('sets initial quotas', async () => {
      const { period, amount } = await faucet.getQuota(token.address)
      assertBn(period, TOKEN_QUOTA_PERIOD, 'token quota period does not match')
      assertBn(amount, TOKEN_QUOTA_AMOUNT, 'token quota amount does not match')

      const { period: anotherPeriod, amount: anotherAmount } = await faucet.getQuota(anotherToken.address)
      assertBn(anotherPeriod, ANOTHER_TOKEN_QUOTA_PERIOD, 'another token quota period does not match')
      assertBn(anotherAmount, ANOTHER_TOKEN_QUOTA_AMOUNT, 'another token quota amount does not match')
    })
  })

  describe('set quota', () => {

  })

  describe('donate', () => {
    const from = donor
    const amount = bigExp(1, 18)

    context('when the token quota was set', async () => {
      it('receives the donation', async () => {
        const firstReceipt = await faucet.donate(token.address, amount, { from })
        const secondsReceipt = await faucet.donate(token.address, amount, { from })

        const supply = await faucet.getTotalSupply(token.address)
        const expectedSupply = amount.mul(bn(2))
        assertBn(supply, expectedSupply, 'token supply does not match')

        assertAmountOfEvents(firstReceipt, 'TokensDonated')
        assertEvent(firstReceipt, 'TokensDonated', { token: token.address, donor, amount, totalSupply: amount })

        assertAmountOfEvents(secondsReceipt, 'TokensDonated')
        assertEvent(secondsReceipt, 'TokensDonated', { token: token.address, donor, amount, totalSupply: expectedSupply })
      })

      it('transfers the tokens to the faucet', async () => {
        const previousDonorBalance = await token.balanceOf(from)
        const previousFaucetBalance = await token.balanceOf(faucet.address)

        await faucet.donate(token.address, amount, { from })

        const currentDonorBalance = await token.balanceOf(from)
        assertBn(currentDonorBalance, previousDonorBalance.sub(amount), 'donor balance does not match')

        const currentFaucetBalance = await token.balanceOf(faucet.address)
        assertBn(currentFaucetBalance, previousFaucetBalance.add(amount), 'faucet balance does not match')
      })
    })

    context('when the token quota was not set', async () => {
      it('reverts', async () => {
        await assertRevert(faucet.donate(unknownToken, amount, { from }), 'FAUCET_QUOTA_AMOUNT_ZERO')
      })
    })
  })

  describe('withdraw', () => {
    const from = account
    const amount = bigExp(1, 18)
    const initialSupply = TOKEN_QUOTA_AMOUNT.mul(bn(5))

    context('when the token quota was set', async () => {
      context('when the quota was not exceeded', async () => {
        context('when there is enough supply', async () => {
          beforeEach('donate', async () => {
            await faucet.donate(token.address, initialSupply, { from: donor })
          })

          it('reduces the supply', async () => {
            const firstReceipt = await faucet.withdraw(token.address, amount, { from })
            const secondsReceipt = await faucet.withdraw(token.address, amount, { from })

            const supply = await faucet.getTotalSupply(token.address)
            const expectedSupply = initialSupply.sub(amount.mul(bn(2)))
            assertBn(supply, expectedSupply, 'token supply does not match')

            assertAmountOfEvents(firstReceipt, 'TokensWithdrawn')
            assertEvent(firstReceipt, 'TokensWithdrawn', { token: token.address, account, amount, totalSupply: initialSupply.sub(amount) })

            assertAmountOfEvents(secondsReceipt, 'TokensWithdrawn')
            assertEvent(secondsReceipt, 'TokensWithdrawn', { token: token.address, account, amount, totalSupply: expectedSupply })
          })

          it('transfers the tokens to the faucet', async () => {
            const previousFaucetBalance = await token.balanceOf(faucet.address)
            const previousAccountBalance = await token.balanceOf(from)

            await faucet.withdraw(token.address, amount, { from })

            const currentFaucetBalance = await token.balanceOf(faucet.address)
            assertBn(currentFaucetBalance, previousFaucetBalance.sub(amount), 'faucet balance does not match')

            const currenAccountBalance = await token.balanceOf(from)
            assertBn(currenAccountBalance, previousAccountBalance.add(amount), 'account balance does not match')
          })
        })

        context('when there is not enough supply', async () => {
          it('reverts', async () => {
            await assertRevert(faucet.withdraw(token.address, amount, { from }), 'FAUCET_NOT_ENOUGH_SUPPLY')
          })
        })
      })

      context('when the quota was exceeded', async () => {
        beforeEach('withdraw full quota', async () => {
          await faucet.donate(token.address, initialSupply, { from: donor })
          await faucet.withdraw(token.address, TOKEN_QUOTA_AMOUNT, { from })
        })

        it('reverts', async () => {
          await assertRevert(faucet.withdraw(token.address, amount, { from }), 'FAUCET_AMOUNT_EXCEEDS_QUOTA')
        })

        it('can withdraw after the current period', async () => {
          await faucet.mockIncreaseTime(TOKEN_QUOTA_PERIOD)

          const receipt = await faucet.withdraw(token.address, amount, { from })

          assertAmountOfEvents(receipt, 'TokensWithdrawn')
          assertEvent(receipt, 'TokensWithdrawn', { token: token.address, account, amount })
        })
      })
    })

    context('when the token quota was not set', async () => {
      it('reverts', async () => {
        await assertRevert(faucet.withdraw(unknownToken, amount, { from }), 'FAUCET_NOT_ENOUGH_SUPPLY')
      })
    })
  })
})
