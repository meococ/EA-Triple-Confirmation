//+------------------------------------------------------------------+
//|                                               CoreLogic.mqh      |
//|                        Copyright 2025, Your Company              |
//|                                            https://yoursite.com  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"
#property version   "2.00"

#include "CommonDefinitions.mqh"
#include "MarketCondition.mqh"
#include "SignalModule.mqh"

//+------------------------------------------------------------------+
//| Class for integrating core logic components                       |
//+------------------------------------------------------------------+
class CCoreLogic
{
private:
   // Core components
   CMarketCondition  m_marketCondition;   // Market condition analyzer
   CSignalModule     m_signalModule;      // Signal processor
   
   // Trading parameters
   string            m_symbol;            // Trading symbol
   ENUM_TIMEFRAMES   m_timeframe;         // Timeframe
   
   // Risk parameters
   double            m_slMultiplier;      // Stop loss multiplier (ATR)
   double            m_tp1Multiplier;     // Take profit 1 multiplier (ATR)
   double            m_tp2Multiplier;     // Take profit 2 multiplier (ATR)
   double            m_tp3Multiplier;     // Take profit 3 multiplier (ATR)
   int               m_tp1Percent;        // Percentage to close at TP1
   int               m_tp2Percent;        // Percentage to close at TP2
   int               m_tp3Percent;        // Percentage to close at TP3
   
   // State tracking
   bool              m_isInitialized;     // Initialization flag
   datetime          m_lastBarTime;       // Last processed bar time
   bool              m_isNewBar;          // New bar flag
   
   // Helper methods
   bool IsNewBarFormed()
   {
      datetime currentBarTime = iTime(m_symbol, m_timeframe, 0);
      
      if(currentBarTime != m_lastBarTime)
      {
         m_lastBarTime = currentBarTime;
         m_isNewBar = true;
         return true;
      }
      
      m_isNewBar = false;
      return false;
   }

public:
   // Constructor
   CCoreLogic()
   {
      m_isInitialized = false;
      m_lastBarTime = 0;
      m_isNewBar = false;
      m_symbol = "";
      m_timeframe = PERIOD_CURRENT;
      
      // Default risk parameters (v2.0)
      m_slMultiplier = 1.8;     // Stop loss - increased from 1.2
      m_tp1Multiplier = 2.0;    // TP1 - increased from 1.5
      m_tp2Multiplier = 3.2;    // TP2 - increased from 2.5
      m_tp3Multiplier = 4.8;    // TP3 - increased from 4.0
      m_tp1Percent = 40;        // Percentage to close at TP1
      m_tp2Percent = 35;        // Percentage to close at TP2
      m_tp3Percent = 25;        // Percentage to close at TP3
   }
   
   // Destructor
   ~CCoreLogic()
   {
      // Components have their own cleanup in destructors
   }
   
   // Initialization
   bool Init(
      // Basic parameters
      string symbol, ENUM_TIMEFRAMES timeframe,
      
      // Triple Confirmation parameters
      int vwapPeriod, int rsiPeriod, double rsiLower, double rsiUpper,
      int bbPeriod, double bbDeviation, int atrPeriod, bool showAlerts,
      double vwapMinDistance,
      
      // Market condition parameters
      int adxPeriod, int adxTrendingThreshold, int adxRangingThreshold,
      int atrBasePeriod, double volatilityMinRatio, double volatilityMaxRatio,
      bool useTimeFilter, int startHour, int endHour,
      
      // Risk parameters
      double slMultiplier, double tp1Multiplier, double tp2Multiplier, double tp3Multiplier,
      int tp1Percent, int tp2Percent, int tp3Percent
   )
   {
      // Store basic parameters
      m_symbol = symbol;
      m_timeframe = timeframe;
      
      // Store risk parameters
      m_slMultiplier = slMultiplier;
      m_tp1Multiplier = tp1Multiplier;
      m_tp2Multiplier = tp2Multiplier;
      m_tp3Multiplier = tp3Multiplier;
      m_tp1Percent = tp1Percent;
      m_tp2Percent = tp2Percent;
      m_tp3Percent = tp3Percent;
      
      // Initialize market condition analyzer
      if(!m_marketCondition.Init(symbol, timeframe, 
                               adxPeriod, adxTrendingThreshold, adxRangingThreshold,
                               atrPeriod, atrBasePeriod, 
                               volatilityMinRatio, volatilityMaxRatio))
      {
         Print("Failed to initialize MarketCondition module");
         return false;
      }
      
      // Set up time filter if needed
      m_marketCondition.SetTimeFilter(useTimeFilter, startHour, endHour);
      
      // Initialize signal module with reference to market condition
      if(!m_signalModule.Init(symbol, timeframe, 
                            vwapPeriod, rsiPeriod, rsiLower, rsiUpper,
                            bbPeriod, bbDeviation, atrPeriod, showAlerts,
                            vwapMinDistance, &m_marketCondition))
      {
         Print("Failed to initialize SignalModule");
         return false;
      }
      
      m_isInitialized = true;
      return true;
   }
   
   // Process current tick/bar
   bool Process()
   {
      if(!m_isInitialized)
      {
         Print("CoreLogic not initialized!");
         return false;
      }
      
      // Check for new bar
      bool isNewBar = IsNewBarFormed();
      
      // Update market condition on new bar
      if(isNewBar)
      {
         if(!m_marketCondition.Update())
         {
            Print("Failed to update market condition");
            return false;
         }
      }
      
      // Only update signals on new bar to save resources
      // (signals are only valid on bar close in this strategy)
      if(isNewBar)
      {
         if(!m_signalModule.Update())
         {
            Print("Failed to update signals");
            return false;
         }
      }
      
      return true;
   }
   
   // Check if we have a new bar
   bool IsNewBar()
   {
      return m_isNewBar;
   }
   
   // Check if we have a valid trading signal
   bool HasTradableSignal()
   {
      return m_signalModule.HasSignal() && m_signalModule.IsSignalTradable();
   }
   
   // Get current signal details
   bool GetSignalDetails(ENUM_TRADE_DIRECTION &direction, ENUM_SETUP_QUALITY &quality)
   {
      if(!m_signalModule.HasSignal())
         return false;
      
      direction = m_signalModule.GetSignalType();
      quality = m_signalModule.GetSetupQuality();
      
      return true;
   }
   
   // Get entry/exit levels for current signal
   bool GetTradeLevels(double &entryPrice, double &stopLoss, 
                      double &takeProfit1, double &takeProfit2, double &takeProfit3)
   {
      return m_signalModule.CalculateLevels(entryPrice, stopLoss, 
                                          takeProfit1, takeProfit2, takeProfit3,
                                          m_slMultiplier, m_tp1Multiplier, 
                                          m_tp2Multiplier, m_tp3Multiplier);
   }
   
   // Get take profit percentages
   void GetTPPercentages(int &tp1Percent, int &tp2Percent, int &tp3Percent)
   {
      tp1Percent = m_tp1Percent;
      tp2Percent = m_tp2Percent;
      tp3Percent = m_tp3Percent;
   }
   
   // Get ATR value
   double GetATR()
   {
      return m_signalModule.GetATR();
   }
   
   // Get current market condition
   ENUM_MARKET_CONDITION GetMarketCondition()
   {
      return m_marketCondition.GetCurrentCondition();
   }
   
   // Check if market is suitable for trading
   bool IsMarketSuitable()
   {
      return m_marketCondition.IsMarketSuitable(true); // For mean reversion
   }
   
   // Get detailed market condition explanation (for logging)
   string GetMarketConditionExplanation()
   {
      return m_marketCondition.GetConditionExplanation();
   }
   
   // Get reason why market is not suitable (for logging)
   string GetMarketUnsuitableReason()
   {
      return m_marketCondition.GetUnsuitableReason(true); // For mean reversion
   }
   
   // Get signal description (for logging)
   string GetSignalDescription()
   {
      return m_signalModule.GetSignalDescription();
   }
   
   // Get volatility ratio (for position sizing)
   double GetVolatilityRatio()
   {
      return m_marketCondition.GetVolatilityRatio();
   }
   
   // Check if current time is within trading hours
   bool IsWithinTradingHours()
   {
      return m_marketCondition.IsWithinTradingHours();
   }
   
   // Create trade details for logging/tracking
   STradeDetails CreateTradeDetails(double lotSize, double riskPercent)
   {
      double entryPrice, stopLoss, takeProfit1, takeProfit2, takeProfit3;
      
      if(!GetTradeLevels(entryPrice, stopLoss, takeProfit1, takeProfit2, takeProfit3))
      {
         // Return empty struct if levels calculation fails
         STradeDetails empty;
         ZeroMemory(empty);
         return empty;
      }
      
      return m_signalModule.GetTradeDetails(entryPrice, stopLoss, 
                                          takeProfit1, takeProfit2, takeProfit3,
                                          lotSize, riskPercent);
   }
   
   // Calculate adaptive position size based on ATR
   double CalculateAdaptiveSize(double baseSize, double baseATR)
   {
      double currentATR = m_signalModule.GetATR();
      if(currentATR <= 0.0 || baseATR <= 0.0)
         return baseSize;
      
      double atrRatio = baseATR / currentATR;
      return NormalizeDouble(baseSize * atrRatio, 2);
   }
   
   // Calculate position size multiplier based on setup quality
   double GetQualityMultiplier()
   {
      ENUM_SETUP_QUALITY quality = m_signalModule.GetSetupQuality();
      
      switch(quality)
      {
         case SETUP_QUALITY_A_PLUS:
            return 1.0;  // 100% for A+ setups
         case SETUP_QUALITY_A:
            return 0.75; // 75% for A setups
         default:
            return 0.0;  // No trading for B/C setups
      }
   }
};