/* eslint-disable */

const { BigNumber: Decimal } = require("bignumber.js");
const { BigNumber, utils } = require("ethers");
// const [
//   _deltaTime,
//   _utilization,
//   _fullUtilizationInterest,
//   _vertexUtilization,
//   _vertexRatePercentOfDelta,
//   _minUtil,
//   _maxUtil,
//   _zeroUtilizationRate,
//   _minFullUtilizationRate,
//   _maxFullUtilizationRate,
//   _rateHalfLife,
// ] = ["1637", "86542", "146090229566", "80000", "10000", "75000", "85000", "158247046", "158247046", "146248476607", "172800"]
const [
  _deltaTime,
  _utilization,
  _fullUtilizationInterest,
  _vertexUtilization,
  _vertex2Utilization,
  _vertexRatePercentOfDelta,
  _vertex2RatePercentOfDelta,
  _minUtil,
  _maxUtil,
  _zeroUtilizationRate,
  _minFullUtilizationRate,
  _maxFullUtilizationRate,
  _rateHalfLife,
] = process.argv.slice(2);

// Utilization Rate Settings
const MIN_TARGET_UTIL = new Decimal(_minUtil).div(new Decimal(10).pow(5));
const MAX_TARGET_UTIL = new Decimal(_maxUtil).div(new Decimal(10).pow(5));
const VERTEX_UTILIZATION = new Decimal(_vertexUtilization).div(new Decimal(10).pow(5));
const VERTEX_2_UTILIZATION = new Decimal(_vertex2Utilization).div(new Decimal(10).pow(5));
const UTIL_PREC = new Decimal(1e5).div(new Decimal(10).pow(5)); // 5 decimals

// Interest Rate Settings (all rates are per second), 365.24 days per year
const MIN_FULL_UTIL_RATE = new Decimal(_minFullUtilizationRate).div(new Decimal(10).pow(18));
const MAX_FULL_UTIL_RATE = new Decimal(_maxFullUtilizationRate).div(new Decimal(10).pow(18));
const ZERO_UTIL_RATE = new Decimal(_zeroUtilizationRate).div(new Decimal(10).pow(18));
const VERTEX_RATE_PERCENT = new Decimal(_vertexRatePercentOfDelta).div(new Decimal(10).pow(18));
const VERTEX_2_RATE_PERCENT = new Decimal(_vertex2RatePercentOfDelta).div(new Decimal(10).pow(18));
const RATE_HALF_LIFE = new Decimal(_rateHalfLife);

const getNewMaxRate = (deltaTime, utilization, fullUtilizationInterest) => {
  let newFullUtilizationRate;

  if (utilization.lt(MIN_TARGET_UTIL)) {
    const deltaUtilization = new Decimal(MIN_TARGET_UTIL).minus(utilization).div(MIN_TARGET_UTIL);
    // console.log("file: variableInterestRateCalculator.js ~ line 50 ~ getNewMaxRate ~ deltaUtilization", deltaUtilization.toString());
    const decayGrowth = new Decimal(RATE_HALF_LIFE).plus(deltaUtilization.times(deltaUtilization).times(deltaTime));
    // console.log("file: variableInterestRateCalculator.js ~ line 52 ~ getNewMaxRate ~ decayGrowth", decayGrowth.toString());
    newFullUtilizationRate = fullUtilizationInterest.times(RATE_HALF_LIFE).div(decayGrowth);
  } else if (utilization.gt(MAX_TARGET_UTIL)) {
    const deltaUtilization = utilization.minus(MAX_TARGET_UTIL).div(new Decimal(1).minus(MAX_TARGET_UTIL));
    // console.log("file: variableInterestRateCalculator.js ~ line 58 ~ getNewMaxRate ~ deltaUtilization", deltaUtilization.toString());
    const decayGrowth = new Decimal(RATE_HALF_LIFE).plus(deltaUtilization.times(deltaUtilization).times(deltaTime));
    // console.log("file: variableInterestRateCalculator.js ~ line 60 ~ getNewMaxRate ~ decayGrowth", decayGrowth.toString());
    newFullUtilizationRate = fullUtilizationInterest.times(decayGrowth).div(new Decimal(RATE_HALF_LIFE));
  } else {
    newFullUtilizationRate = fullUtilizationInterest;
  }
  if (newFullUtilizationRate.lt(MIN_FULL_UTIL_RATE)) {
    newFullUtilizationRate = new Decimal(MIN_FULL_UTIL_RATE);
  } else if (newFullUtilizationRate.gt(MAX_FULL_UTIL_RATE)) {
    newFullUtilizationRate = new Decimal(MAX_FULL_UTIL_RATE);
  }

  return newFullUtilizationRate;
};

const getNewRate = (_deltaTime, _utilization, _fullUtilizationInterest) => {
  // 1e18 precision downgrade
  const fullUtilizationInterest = new Decimal(_fullUtilizationInterest).div(new Decimal(10).pow(18));
  const deltaTime = new Decimal(_deltaTime);
  // 1e5 precision downgrade
  const utilization = new Decimal(_utilization).div(new Decimal(10).pow(5));

  const newFullUtilizationRate = getNewMaxRate(deltaTime, utilization, fullUtilizationInterest);
  // console.log("file: variableInterestRateCalculator.js ~ line 82 ~ getNewRate ~ newFullUtilizationRate", newFullUtilizationRate.toString());
  const vertexInterest = newFullUtilizationRate.minus(ZERO_UTIL_RATE).times(VERTEX_RATE_PERCENT).plus(ZERO_UTIL_RATE);
  // console.log("file: variableInterestRateCalculator.js ~ line 83 ~ getNewRate ~ vertexInterest", vertexInterest.toString());
  const vertex2Interest = newFullUtilizationRate
    .minus(ZERO_UTIL_RATE)
    .times(VERTEX_2_RATE_PERCENT)
    .plus(ZERO_UTIL_RATE);

  let newRatePerSec;

  if (utilization.lt(VERTEX_UTILIZATION)) {
    const slope = vertexInterest.minus(ZERO_UTIL_RATE).div(VERTEX_UTILIZATION);
    newRatePerSec = slope.times(utilization).plus(ZERO_UTIL_RATE);
  } else if (utilization.lt(VERTEX_2_UTILIZATION)) {
    const slope = vertex2Interest.minus(vertexInterest).div(VERTEX_2_UTILIZATION.minus(VERTEX_UTILIZATION));
    newRatePerSec = slope.times(utilization.minus(VERTEX_UTILIZATION)).plus(vertexInterest);
  } else if (utilization.gte(VERTEX_2_UTILIZATION)) {
    const slope = newFullUtilizationRate.minus(vertex2Interest).div(new Decimal(1).minus(VERTEX_2_UTILIZATION));
    newRatePerSec = slope.times(utilization.minus(VERTEX_2_UTILIZATION)).plus(vertex2Interest);
  } else {
    newRatePerSec = vertexInterest;
  }
  // console.log("file: variableInterestRateCalculator.js ~ line 95 ~ getNewRate ~ newRatePerSec", newRatePerSec.toString());

  console.log(
    utils.defaultAbiCoder.encode(
      ["uint256", "uint256"],
      [
        newRatePerSec.times(new Decimal(10).pow(18)).dp(0).toString(),
        newFullUtilizationRate.times(new Decimal(10).pow(18)).dp(0).toString(),
      ],
    ),
  );
};
getNewRate(_deltaTime, _utilization, _fullUtilizationInterest);
