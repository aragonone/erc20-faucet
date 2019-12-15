const { BN } = require('web3-utils')

const bn = x => new BN(x)

const bigExp = (x, y = 18) => bn(x).mul(bn(10).pow(bn(y)))

const assertBn = (actual, expected, errorMsg) => {
  assert.equal(actual.toString(), expected.toString(), `${errorMsg} expected ${expected.toString()} to equal ${actual.toString()}`)
}

module.exports = {
  bn,
  bigExp,
  assertBn
}
