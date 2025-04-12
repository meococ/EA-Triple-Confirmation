//+------------------------------------------------------------------+
//|                                            SignalModule.mqh      |
//|                        Copyright 2025, Your Company              |
//|                                            https://yoursite.com  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"
#property version   "2.00"

#include "CommonDefinitions.mqh"
#include "MarketCondition.mqh"

//+------------------------------------------------------------------+
//| Class for handling trading signals                               |
//+------------------------------------------------------------------+
class CSignalModule
{
private:
   // Indicator handle
   int            m_tcHandle;          // Triple Confirmation indicator handle
   
   // Buffer indices for the indicator
   int            m_buySignalBuffer;   // Buy signal buffer index
   int            m_sellSignalBuffer;  // Sell signal buffer index
   int            m_atrBuffer;         // ATR buffer index
   int            m_qualityBuffer;     // Setup quality buffer index
   
   // Signal data
   bool           m_hasSignal;          // Has valid signal flag
   ENUM_TRADE_DIRECTION m_signalType;   // Current signal type
   ENUM_SETUP_QUALITY m_setupQuality;   // Current setup quality
   double         m_atr;                // Current ATR value
   datetime       m_signalTime;         // Signal time
   string         m_symbol;             // Trading symbol
   ENUM_TIMEFRAMES m_timeframe;         // Timeframe
   
   // Signal parameters
   double         m_vwapMinDistance;    // Minimum distance from VWAP (in ATR)
   
   // Market condition manager (reference)
   CMarketCondition* m_marketCondition;
   
   // Helper methods
   bool CopyIndicatorData()
   {
      if(m_tcHandle == INVALID_HANDLE)
         return false;
      
      // Copy data from the indicator buffers
      double buyBuffer[2], sellBuffer[2], atrBuffer[1], qualityBuffer[2];
      ArraySetAsSeries(buyBuffer, true);
      ArraySetAsSeries(sellBuffer, true);
      ArraySetAsSeries(atrBuffer, true);
      ArraySetAsSeries(qualityBuffer, true);
      
      bool dataOK = true;
      
      // Copy buy signal buffer
      if(CopyBuffer(m_tcHandle, m_buySignalBuffer, 0, 2, buyBuffer) <= 0)
      {
         Print("Cannot copy buy signal buffer. Error: ", GetLastError());
         dataOK = false;
      }
      
      // Copy sell signal buffer
      if(CopyBuffer(m_tcHandle, m_sellSignalBuffer, 0, 2, sellBuffer) <= 0)
      {
         Print("Cannot copy sell signal buffer. Error: ", GetLastError());
         dataOK = false;
      }
      
      // Copy ATR buffer
      if(CopyBuffer(m_tcHandle, m_atrBuffer, 0, 1, atrBuffer) <= 0)
      {
         Print("Cannot copy ATR buffer. Error: ", GetLastError());
         dataOK = false;
      }
      
      // Copy quality buffer
      if(CopyBuffer(m_tcHandle, m_qualityBuffer, 0, 2, qualityBuffer) <= 0)
      {
         Print("Cannot copy quality buffer. Error: ", GetLastError());
         dataOK = false;
      }
      
      if(!dataOK)
         return false;
      
      // Process the data
      m_hasSignal = false;
      m_signalType = TRADE_DIRECTION_NONE;
      m_setupQuality = SETUP_QUALITY_NONE;
      
      // Check for buy signal
      if(buyBuffer[0] != EMPTY_VALUE)
      {
         m_hasSignal = true;
         m_signalType = TRADE_DIRECTION_BUY;
         m_setupQuality = (ENUM_SETUP_QUALITY)(int)qualityBuffer[0];
      }
      // Check for sell signal
      else if(sellBuffer[0] != EMPTY_VALUE)
      {
         m_hasSignal = true;
         m_signalType = TRADE_DIRECTION_SELL;
         m_setupQuality = (ENUM_SETUP_QUALITY)(int)qualityBuffer[0];
      }
      
      // Get ATR value
      m_atr = atrBuffer[0];
      
      // Get current time as signal time
      m_signalTime = TimeCurrent();
      
      return true;
   }

public:
   // Constructor
   CSignalModule()
   {
      m_tcHandle = INVALID_HANDLE;
      m_buySignalBuffer = 4;       // Default index for buy signal buffer
      m_sellSignalBuffer = 5;      // Default index for sell signal buffer
      m_atrBuffer = 8;             // Default index for ATR buffer
      m_qualityBuffer = 9;         // Default index for quality buffer
      
      m_hasSignal = false;
      m_signalType = TRADE_DIRECTION_NONE;
      m_setupQuality = SETUP_QUALITY_NONE;
      m_atr = 0.0;
      m_signalTime = 0;
      m_symbol = "";
      m_timeframe = PERIOD_CURRENT;
      
      m_vwapMinDistance = 0.5;     // Default minimum VWAP distance (v2.0)
      
      m_marketCondition = NULL;
   }
   
   // Destructor
   ~CSignalModule()
   {
      if(m_tcHandle != INVALID_HANDLE)
         IndicatorRelease(m_tcHandle);
   }
   
   // Initialization
   bool Init(string symbol, ENUM_TIMEFRAMES timeframe, 
            int vwapPeriod, int rsiPeriod, double rsiLower, double rsiUpper,
            int bbPeriod, double bbDeviation, int atrPeriod, bool showAlerts,
            double vwapMinDistance, CMarketCondition* marketCondition)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_vwapMinDistance = vwapMinDistance;
      m_marketCondition = marketCondition;
      
      // Create the Triple Confirmation indicator handle
      m_tcHandle = iCustom(symbol, timeframe, "TripleConfirmationIndicator", 
                          vwapPeriod, rsiPeriod, rsiLower, rsiUpper, 
                          bbPeriod, bbDeviation, atrPeriod, showAlerts, vwapMinDistance);
      
      if(m_tcHandle == INVALID_HANDLE)
      {
         Print("Error creating Triple Confirmation indicator handle: ", GetLastError());
         return false;
      }
      
      return true;
   }
   
   // Update the signal
   bool Update()
   {
      return CopyIndicatorData();
   }
   
   // Check if there is a valid signal
   bool HasSignal()
   {
      return m_hasSignal;
   }
   
   // Get the current signal type
   ENUM_TRADE_DIRECTION GetSignalType()
   {
      return m_signalType;
   }
   
   // Get the current setup quality
   ENUM_SETUP_QUALITY GetSetupQuality()
   {
      return m_setupQuality;
   }
   
   // Get the current ATR value
   double GetATR()
   {
      return m_atr;
   }
   
   // Get the signal time
   datetime GetSignalTime()
   {
      return m_signalTime;
   }
   
   // Check if the signal is tradable (quality and market condition)
   bool IsSignalTradable()
   {
      // No signal
      if(!m_hasSignal)
         return false;
      
      // Check setup quality - only trade A+ and A setups
      if(m_setupQuality != SETUP_QUALITY_A_PLUS && m_setupQuality != SETUP_QUALITY_A)
         return false;
      
      // Check market condition if available
      if(m_marketCondition != NULL)
      {
         if(!m_marketCondition->IsMarketSuitable(true)) // Require ranging market for mean reversion
            return false;
      }
      
      return true;
   }
   
   // Calculate entry/exit levels for a given signal
   bool CalculateLevels(double &entryPrice, double &stopLoss, 
                       double &takeProfit1, double &takeProfit2, double &takeProfit3,
                       double slMultiplier, double tp1Multiplier, 
                       double tp2Multiplier, double tp3Multiplier)
   {
      // Make sure we have a valid signal and ATR
      if(!m_hasSignal || m_atr <= 0.0)
         return false;
      
      // Get current price
      entryPrice = (m_signalType == TRADE_DIRECTION_BUY) ? 
                   SymbolInfoDouble(m_symbol, SYMBOL_ASK) : 
                   SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      // Calculate levels based on signal type
      if(m_signalType == TRADE_DIRECTION_BUY)
      {
         stopLoss = entryPrice - m_atr * slMultiplier;
         takeProfit1 = entryPrice + m_atr * tp1Multiplier;
         takeProfit2 = entryPrice + m_atr * tp2Multiplier;
         takeProfit3 = entryPrice + m_atr * tp3Multiplier;
      }
      else // SELL
      {
         stopLoss = entryPrice + m_atr * slMultiplier;
         takeProfit1 = entryPrice - m_atr * tp1Multiplier;
         takeProfit2 = entryPrice - m_atr * tp2Multiplier;
         takeProfit3 = entryPrice - m_atr * tp3Multiplier;
      }
      
      return true;
   }
   
   // Get a string representation of the setup quality
   string GetSetupQualityString()
   {
      switch(m_setupQuality)
      {
         case SETUP_QUALITY_A_PLUS: return "A+";
         case SETUP_QUALITY_A: return "A";
         case SETUP_QUALITY_B: return "B";
         case SETUP_QUALITY_C: return "C";
         default: return "None";
      }
   }
   
   // Get a detailed description of the signal
   string GetSignalDescription()
   {
      if(!m_hasSignal)
         return "No signal";
      
      string direction = (m_signalType == TRADE_DIRECTION_BUY) ? "BUY" : "SELL";
      string quality = GetSetupQualityString();
      
      string result = direction + " signal with " + quality + " quality";
      result += " at " + TimeToString(m_signalTime, TIME_MINUTES);
      result += " (ATR: " + DoubleToString(m_atr, 5) + ")";
      
      if(m_marketCondition != NULL)
      {
         bool isTradable = m_marketCondition->IsMarketSuitable(true);
         result += ", Market: " + (isTradable ? "Suitable" : "Not Suitable");
      }
      
      return result;
   }
   
   // Create a trade details structure for logging
   STradeDetails GetTradeDetails(double entryPrice, double stopLoss, 
                                double takeProfit1, double takeProfit2, double takeProfit3,
                                double lotSize, double riskPercent)
   {
      STradeDetails details;
      
      details.symbol = m_symbol;
      details.entryPrice = entryPrice;
      details.direction = m_signalType;
      details.stopLoss = stopLoss;
      details.takeProfit1 = takeProfit1;
      details.takeProfit2 = takeProfit2;
      details.takeProfit3 = takeProfit3;
      details.riskReward = (m_signalType == TRADE_DIRECTION_BUY) ? 
                          (takeProfit1 - entryPrice) / (entryPrice - stopLoss) : 
                          (entryPrice - takeProfit1) / (stopLoss - entryPrice);
      details.setupQuality = m_setupQuality;
      details.marketCondition = (m_marketCondition != NULL) ? 
                               m_marketCondition->GetCurrentCondition() : 
                               MARKET_CONDITION_UNDEFINED;
      details.lotSize = lotSize;
      details.risk = riskPercent;
      details.ATR = m_atr;
      
      return details;
   }
};