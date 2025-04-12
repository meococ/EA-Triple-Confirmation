//+------------------------------------------------------------------+
//|                                         MarketCondition.mqh      |
//|                        Copyright 2025, Your Company              |
//|                                            https://yoursite.com  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"
#property version   "2.00"

#include "CommonDefinitions.mqh"

//+------------------------------------------------------------------+
//| Class for analyzing market conditions and volatility             |
//+------------------------------------------------------------------+
class CMarketCondition
{
private:
   // Handles for market condition indicators
   int            m_adxHandle;        // ADX handle
   int            m_atrHandle;        // ATR handle
   int            m_baseAtrHandle;    // ATR (long-term) handle for volatility ratio
   
   // Configuration parameters
   int            m_adxPeriod;                // ADX period
   int            m_adxTrendingThreshold;     // ADX threshold for trending market
   int            m_adxRangingThreshold;      // ADX threshold for ranging market
   int            m_atrPeriod;                // ATR period
   int            m_atrBasePeriod;            // Base period for ATR ratio
   double         m_volatilityMinRatio;       // Minimum acceptable volatility ratio
   double         m_volatilityMaxRatio;       // Maximum acceptable volatility ratio
   
   // Cache values
   double         m_currentAdx;               // Current ADX value
   double         m_currentAtr;               // Current ATR value
   double         m_baseAtr;                  // Base ATR value (for comparison)
   double         m_volatilityRatio;          // Current volatility ratio
   datetime       m_lastBaseAtrCalc;          // Time of last base ATR calculation
   ENUM_MARKET_CONDITION m_currentCondition;  // Current market condition
   datetime       m_lastUpdateTime;           // Last update time
   bool           m_isTimeFilterActive;       // Time filter active flag
   int            m_startHour;                // Trading start hour (GMT)
   int            m_endHour;                  // Trading end hour (GMT)
   
   // Private methods
   bool UpdateIndicatorValues()
   {
      // Update ADX value
      double adxBuffer[];
      ArraySetAsSeries(adxBuffer, true);
      
      if(CopyBuffer(m_adxHandle, 0, 0, 1, adxBuffer) <= 0)
      {
         Print("Cannot copy ADX data. Error: ", GetLastError());
         return false;
      }
      
      m_currentAdx = adxBuffer[0];
      
      // Update ATR value
      double atrBuffer[];
      ArraySetAsSeries(atrBuffer, true);
      
      if(CopyBuffer(m_atrHandle, 0, 0, 1, atrBuffer) <= 0)
      {
         Print("Cannot copy ATR data. Error: ", GetLastError());
         return false;
      }
      
      m_currentAtr = atrBuffer[0];
      
      // Update base ATR periodically (once per hour to save resources)
      if(m_baseAtr == 0.0 || TimeCurrent() - m_lastBaseAtrCalc > 3600)
      {
         double baseAtrBuffer[];
         ArraySetAsSeries(baseAtrBuffer, true);
         
         if(CopyBuffer(m_baseAtrHandle, 0, 0, 1, baseAtrBuffer) <= 0)
         {
            Print("Cannot copy base ATR data. Error: ", GetLastError());
            return false;
         }
         
         m_baseAtr = baseAtrBuffer[0];
         m_lastBaseAtrCalc = TimeCurrent();
      }
      
      // Calculate volatility ratio
      if(m_baseAtr > 0.0)
         m_volatilityRatio = m_currentAtr / m_baseAtr;
      else
         m_volatilityRatio = 1.0;
      
      return true;
   }
   
   void DetermineMarketCondition()
   {
      // Default condition
      m_currentCondition = MARKET_CONDITION_UNDEFINED;
      
      // Determine based on ADX
      if(m_currentAdx >= m_adxTrendingThreshold)
      {
         m_currentCondition = MARKET_CONDITION_TRENDING;
      }
      else if(m_currentAdx < m_adxRangingThreshold)
      {
         m_currentCondition = MARKET_CONDITION_RANGING;
      }
      else
      {
         // Transition zone between ranging and trending
         m_currentCondition = MARKET_CONDITION_TRANSITION;
      }
      
      // Override based on volatility if necessary
      if(m_volatilityRatio > m_volatilityMaxRatio)
      {
         m_currentCondition = MARKET_CONDITION_VOLATILE;
      }
      else if(m_volatilityRatio < m_volatilityMinRatio)
      {
         m_currentCondition = MARKET_CONDITION_LOW_VOLATILITY;
      }
   }

public:
   // Constructor
   CMarketCondition()
   {
      // Initialize default values
      m_adxHandle = INVALID_HANDLE;
      m_atrHandle = INVALID_HANDLE;
      m_baseAtrHandle = INVALID_HANDLE;
      
      m_adxPeriod = 14;
      m_adxTrendingThreshold = 25;
      m_adxRangingThreshold = 20;
      m_atrPeriod = 14;
      m_atrBasePeriod = 50;
      m_volatilityMinRatio = 0.7;
      m_volatilityMaxRatio = 1.3;
      
      m_currentAdx = 0.0;
      m_currentAtr = 0.0;
      m_baseAtr = 0.0;
      m_volatilityRatio = 1.0;
      m_lastBaseAtrCalc = 0;
      m_currentCondition = MARKET_CONDITION_UNDEFINED;
      m_lastUpdateTime = 0;
      m_isTimeFilterActive = false;
      m_startHour = 0;
      m_endHour = 24;
   }
   
   // Destructor
   ~CMarketCondition()
   {
      ReleaseIndicators();
   }
   
   // Initialization
   bool Init(string symbol, ENUM_TIMEFRAMES timeframe,
            int adxPeriod, int adxTrendingThreshold, int adxRangingThreshold,
            int atrPeriod, int atrBasePeriod,
            double volatilityMinRatio, double volatilityMaxRatio)
   {
      // Store parameters
      m_adxPeriod = adxPeriod;
      m_adxTrendingThreshold = adxTrendingThreshold;
      m_adxRangingThreshold = adxRangingThreshold;
      m_atrPeriod = atrPeriod;
      m_atrBasePeriod = atrBasePeriod;
      m_volatilityMinRatio = volatilityMinRatio;
      m_volatilityMaxRatio = volatilityMaxRatio;
      
      // Create indicator handles
      m_adxHandle = iADX(symbol, timeframe, adxPeriod);
      m_atrHandle = iATR(symbol, timeframe, atrPeriod);
      m_baseAtrHandle = iATR(symbol, timeframe, atrBasePeriod);
      
      // Validate handles
      if(m_adxHandle == INVALID_HANDLE)
      {
         Print("Error creating ADX indicator handle: ", GetLastError());
         return false;
      }
      
      if(m_atrHandle == INVALID_HANDLE)
      {
         Print("Error creating ATR indicator handle: ", GetLastError());
         IndicatorRelease(m_adxHandle);
         return false;
      }
      
      if(m_baseAtrHandle == INVALID_HANDLE)
      {
         Print("Error creating base ATR indicator handle: ", GetLastError());
         IndicatorRelease(m_adxHandle);
         IndicatorRelease(m_atrHandle);
         return false;
      }
      
      // Initial update
      UpdateIndicatorValues();
      DetermineMarketCondition();
      
      return true;
   }
   
   // Set up time filter
   void SetTimeFilter(bool isActive, int startHour, int endHour)
   {
      m_isTimeFilterActive = isActive;
      m_startHour = startHour;
      m_endHour = endHour;
   }
   
   // Release indicator handles
   void ReleaseIndicators()
   {
      if(m_adxHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_adxHandle);
         m_adxHandle = INVALID_HANDLE;
      }
      
      if(m_atrHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_atrHandle);
         m_atrHandle = INVALID_HANDLE;
      }
      
      if(m_baseAtrHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_baseAtrHandle);
         m_baseAtrHandle = INVALID_HANDLE;
      }
   }
   
   // Update market condition
   bool Update()
   {
      // Update indicator values
      if(!UpdateIndicatorValues())
         return false;
      
      // Determine market condition
      DetermineMarketCondition();
      
      // Update last update time
      m_lastUpdateTime = TimeCurrent();
      
      return true;
   }
   
   // Get current market condition
   ENUM_MARKET_CONDITION GetCurrentCondition()
   {
      // Refresh if needed
      if(m_lastUpdateTime == 0 || TimeCurrent() - m_lastUpdateTime > 60) // Update if older than 1 minute
         Update();
      
      return m_currentCondition;
   }
   
   // Get current ADX value
   double GetCurrentADX()
   {
      return m_currentAdx;
   }
   
   // Get current ATR value
   double GetCurrentATR()
   {
      return m_currentAtr;
   }
   
   // Get base ATR value
   double GetBaseATR()
   {
      return m_baseAtr;
   }
   
   // Get volatility ratio
   double GetVolatilityRatio()
   {
      return m_volatilityRatio;
   }
   
   // Check if current time is within trading hours
   bool IsWithinTradingHours()
   {
      if(!m_isTimeFilterActive)
         return true;
         
      MqlDateTime currentTime;
      TimeToStruct(TimeCurrent(), currentTime);
      
      return (currentTime.hour >= m_startHour && currentTime.hour < m_endHour);
   }
   
   // Check if market conditions are suitable for trading
   bool IsMarketSuitable(bool requireRanging = true)
   {
      // Check time filter first
      if(!IsWithinTradingHours())
         return false;
      
      // Update market condition if needed
      if(m_lastUpdateTime == 0 || TimeCurrent() - m_lastUpdateTime > 60)
         Update();
      
      // Check market condition
      if(requireRanging)
      {
         // For mean reversion strategies (Triple Confirmation v2)
         return (m_currentCondition == MARKET_CONDITION_RANGING && 
                m_volatilityRatio >= m_volatilityMinRatio && 
                m_volatilityRatio <= m_volatilityMaxRatio);
      }
      else
      {
         // For general strategies
         return (m_currentCondition != MARKET_CONDITION_UNDEFINED && 
                m_currentCondition != MARKET_CONDITION_VOLATILE &&
                m_currentCondition != MARKET_CONDITION_LOW_VOLATILITY);
      }
   }
   
   // Get detailed condition explanation for logging
   string GetConditionExplanation()
   {
      string result = "Market Condition: ";
      
      switch(m_currentCondition)
      {
         case MARKET_CONDITION_TRENDING:
            result += "Trending (ADX: " + DoubleToString(m_currentAdx, 1) + ")";
            break;
         case MARKET_CONDITION_RANGING:
            result += "Ranging (ADX: " + DoubleToString(m_currentAdx, 1) + ")";
            break;
         case MARKET_CONDITION_VOLATILE:
            result += "Volatile (Volatility: " + DoubleToString(m_volatilityRatio * 100, 0) + "%)";
            break;
         case MARKET_CONDITION_LOW_VOLATILITY:
            result += "Low Volatility (Volatility: " + DoubleToString(m_volatilityRatio * 100, 0) + "%)";
            break;
         case MARKET_CONDITION_TRANSITION:
            result += "Transition (ADX: " + DoubleToString(m_currentAdx, 1) + ")";
            break;
         default:
            result += "Undefined";
      }
      
      result += ", ATR: " + DoubleToString(m_currentAtr, 5);
      result += ", Volatility Ratio: " + DoubleToString(m_volatilityRatio * 100, 0) + "%";
      
      if(m_isTimeFilterActive)
      {
         MqlDateTime currentTime;
         TimeToStruct(TimeCurrent(), currentTime);
         
         result += ", Trading Hours: " + IntegerToString(m_startHour) + "-" + IntegerToString(m_endHour);
         result += " (Current: " + IntegerToString(currentTime.hour) + ")";
         result += IsWithinTradingHours() ? " [Within]" : " [Outside]";
      }
      
      return result;
   }
   
   // Get reason why market is not suitable (for logging)
   string GetUnsuitableReason(bool requireRanging = true)
   {
      string reason = "";
      
      // Check time filter first
      if(!IsWithinTradingHours())
      {
         MqlDateTime currentTime;
         TimeToStruct(TimeCurrent(), currentTime);
         
         reason = "Outside trading hours " + IntegerToString(m_startHour) + "-" + 
                  IntegerToString(m_endHour) + " GMT (current: " + 
                  IntegerToString(currentTime.hour) + ")";
         return reason;
      }
      
      // Check market condition
      if(requireRanging)
      {
         // For mean reversion strategies
         if(m_currentCondition == MARKET_CONDITION_TRENDING)
            reason = "Market is trending (ADX: " + DoubleToString(m_currentAdx, 1) + " > " + 
                     IntegerToString(m_adxRangingThreshold) + ")";
         else if(m_currentCondition == MARKET_CONDITION_VOLATILE)
            reason = "Market volatility too high (" + DoubleToString(m_volatilityRatio * 100, 0) + 
                     "% > " + DoubleToString(m_volatilityMaxRatio * 100, 0) + "%)";
         else if(m_currentCondition == MARKET_CONDITION_LOW_VOLATILITY)
            reason = "Market volatility too low (" + DoubleToString(m_volatilityRatio * 100, 0) + 
                     "% < " + DoubleToString(m_volatilityMinRatio * 100, 0) + "%)";
         else if(m_currentCondition == MARKET_CONDITION_UNDEFINED)
            reason = "Market condition undefined";
         else if(m_currentCondition == MARKET_CONDITION_TRANSITION)
            reason = "Market in transition between ranging and trending";
      }
      else
      {
         // For general strategies
         if(m_currentCondition == MARKET_CONDITION_UNDEFINED)
            reason = "Market condition undefined";
         else if(m_currentCondition == MARKET_CONDITION_VOLATILE)
            reason = "Market volatility too high (" + DoubleToString(m_volatilityRatio * 100, 0) + 
                     "% > " + DoubleToString(m_volatilityMaxRatio * 100, 0) + "%)";
         else if(m_currentCondition == MARKET_CONDITION_LOW_VOLATILITY)
            reason = "Market volatility too low (" + DoubleToString(m_volatilityRatio * 100, 0) + 
                     "% < " + DoubleToString(m_volatilityMinRatio * 100, 0) + "%)";
      }
      
      return reason;
   }
};