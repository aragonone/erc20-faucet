const { assertRevert } = require('./helpers/assertThrow')
const { assertEvent, assertAmountOfEvents } = require('./helpers/assertEvent')

const Ownable = artifacts.require('Ownable')

contract('Ownable', ([_, owner, someone]) => {
  let ownable

  beforeEach('deploy contract', async () => {
    ownable = await Ownable.new({ from: owner })
  })

  describe('owner', () => {
    it('sets the creator as the owner of the contract', async () => {
      const actualOwner = await ownable.getOwner()
      assert.equal(actualOwner, owner, 'owner address does not match')
    })
  })

  describe('transferOwnership', () => {
    context('when the sender is the owner', () => {
      const from = owner

      context('when the proposed owner is not the zero address', () => {
        const newOwner = someone

        it('transfers the ownership', async () => {
          await ownable.transferOwnership(newOwner, { from })

          const actualOwner = await ownable.getOwner()
          assert.equal(actualOwner, newOwner, 'new owner address does not match')
        })

        it('emits an event', async () => {
          const receipt = await ownable.transferOwnership(newOwner, { from })

          assertAmountOfEvents(receipt, 'OwnershipTransferred')
          assertEvent(receipt, 'OwnershipTransferred', { previousOwner: owner, newOwner })
        })
      })

      context('when the new proposed owner is the zero address', () => {
        const newOwner = '0x0000000000000000000000000000000000000000'

        it('reverts', async function() {
          await assertRevert(ownable.transferOwnership(newOwner, { from: owner }), 'OWNABLE_NEW_OWNER_ADDRESS_ZERO')
        })
      })
    })

    context('when the sender is not the owner', () => {
      const from = someone

      it('reverts', async function() {
        await assertRevert(ownable.transferOwnership(someone, { from }), 'OWNABLE_SENDER_NOT_OWNER')
      })
    })
  })
})
