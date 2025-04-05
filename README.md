# EA Triple Confirmation System

A sophisticated MetaTrader 5 Expert Advisor that uses a triple confirmation strategy for enhanced trading decisions.

## Overview

The EA Triple Confirmation System is designed to generate trading signals based on three different technical indicators:
- VWAP (Volume Weighted Average Price)
- RSI (Relative Strength Index)
- Bollinger Bands

The system only enters trades when all three indicators confirm the same trading direction, which helps filter out false signals and improves overall trading performance.

## Features

- Triple confirmation strategy for higher-quality trade signals
- Configurable parameters for each indicator
- Advanced risk management with multiple take profit levels
- ATR-based stop loss and take profit calculations
- News filtering capability to avoid trading during high-impact news events
- Detailed logging system for performance analysis

## Installation

1. Copy all files to your MT5 terminal's Experts folder
2. Compile the EA in MetaEditor
3. Attach the EA to any chart in your MT5 terminal

## Configuration

The EA can be configured through the included configuration file located in the Data folder. Parameters that can be adjusted include:

- Risk percentage per trade
- Indicator periods and thresholds
- Take profit and stop loss multipliers
- Market filters
- Logging options

## Disclaimer

Trading forex/CFDs carries a high level of risk and can result in the loss of your entire deposit. Only trade with capital you can afford to lose. 