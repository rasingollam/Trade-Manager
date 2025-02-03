# Trade Manager

A MetaTrader 5 Expert Advisor for advanced trade management with risk control features.

## Version History

### Version 3.2 (Latest)
- Enhanced risk management with equity protector
- Configurable take profit and stop loss settings
- Improved position sizing calculation
- Risk percentage up to 10% with safety checks
- Advanced reward multiplier system
- Real-time balance and profit tracking

### Version 3.1
- Added equity protection feature
- Default risk percentage set to 0.2%
- Improved trade execution logic
- Enhanced balance calculation system
- Better position management

### Version 3.0
- Complete redesign of the trading interface
- Added support for limit orders
- Improved risk management system
- Real-time profit/loss tracking

### Version 2.1
- Enhanced trading functionality
- Improved button interface
- Better error handling
- Added basic risk management

### Version 2.0
- Initial version with basic features
- Simple buy/sell functionality
- Basic risk percentage control
- Reward multiplier implementation

## Features

- **Risk Management**
  - Configurable risk percentage per trade
  - Equity protection system
  - Dynamic position sizing
  - Reward multiplier for take profit calculation

- **Trade Controls**
  - Buy/Sell buttons for manual trade execution
  - Support for limit orders
  - Automatic take profit and stop loss placement
  - Real-time profit/loss tracking

- **Safety Features**
  - Equity drawdown protection
  - Trade size validation
  - Error handling and logging
  - Position monitoring

## Configuration

### Risk Management Inputs
- `RiskPercentage`: Set the risk per trade (0.2% - 10%)
- `RewardMultiplier`: Define the risk-to-reward ratio
- `TakeProfit`: Enable/disable automatic take profit
- `StopLoss`: Enable/disable automatic stop loss

### Equity Protector
- `EquityProtector`: Enable/disable equity protection
- `EquityDrawdown`: Maximum allowed drawdown percentage

## Installation

1. Copy the desired version of TradeManager (e.g., `TradeManager_3.2.mq5`) to your MetaTrader 5 Experts folder
2. Compile the Expert Advisor in MetaTrader 5
3. Attach to your desired chart
4. Configure the inputs according to your trading strategy

## Usage

1. Set your desired risk parameters in the inputs
2. Draw your entry and exit levels on the chart
3. Use the Buy/Sell buttons to execute trades
4. Monitor your positions through the real-time display

## Requirements

- MetaTrader 5 Platform
- Required Libraries:
  - Controls/Button.mqh
  - Trade/Trade.mqh

## License

Copyright @2025, Malinda Rasingolla.