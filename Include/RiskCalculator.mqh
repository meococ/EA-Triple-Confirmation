//+------------------------------------------------------------------+
//|                                            RiskCalculator.mqh    |
//|                        Copyright 2025, Your Company              |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"
#property version   "2.00"

#include "CommonDefinitions.mqh"

class CRiskCalculator
{
private:
   // Basic risk parameters
   double            m_riskPercent;             // Percentage of account to risk per trade
   bool              m_useAtrAdaptive;          // Flag for ATR-adaptive position sizing
   double            m_baseAtr;                 // Base ATR value for adaptive sizing
   int               m_baseAtrPeriod;           // Period for base ATR calculation
   int               m_atrPeriod;               // Current ATR period
   int               m_baseAtrHandle;           // Handle for base ATR indicator
   int               m_atrHandle;               // Handle for current ATR indicator
   
   // v2.0 Enhancements
   bool              m_enableScalingAfterLoss;  // Enable size reduction after consecutive losses
   double            m_scalingFactor;           // Factor to reduce size (e.g., 0.75)
   int               m_maxConsecutiveScaling;   // Maximum times to apply scaling
   
   // Daily/Weekly risk limits
   double            m_dailyRiskLimit;          // Maximum daily risk (% of account)
   double            m_weeklyRiskLimit;         // Maximum weekly risk (% of account)
   double            m_dailyRiskUsed;           // Current daily risk used
   double            m_weeklyRiskUsed;          // Current weekly risk used
   datetime          m_lastDailyReset;          // Last time daily risk was reset
   datetime          m_lastWeeklyReset;         // Last time weekly risk was reset
   
   // Risk correlation management
   bool              m_enableCorrelationRisk;   // Enable correlation risk management
   double            m_maxCorrelatedRisk;       // Maximum risk for correlated positions
   
   // Cache for current symbol properties
   string            m_symbol;                  // Current symbol
   double            m_tickValue;               // Tick value in account currency
   double            m_minLot;                  // Minimum lot size
   double            m_maxLot;                  // Maximum lot size
   double            m_lotStep;                 // Lot step
   
   // Helper methods
   void UpdateSymbolInfo(string symbol)
   {
      if(m_symbol != symbol)
      {
         m_symbol = symbol;
         m_tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
         m_minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
         m_maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
         m_lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      }
   }
   
   // Check and reset daily/weekly risk limits if needed
   void CheckRiskLimitReset()
   {
      datetime current = TimeCurrent();
      MqlDateTime currentTime;
      TimeToStruct(current, currentTime);
      
      // Daily reset at midnight
      if(TimeDay(m_lastDailyReset) != currentTime.day)
      {
         m_dailyRiskUsed = 0.0;
         m_lastDailyReset = current;
      }
      
      // Weekly reset on Monday
      if(m_lastWeeklyReset == 0 || 
         (currentTime.day_of_week == 1 && TimeDay(m_lastWeeklyReset) != currentTime.day))
      {
         m_weeklyRiskUsed = 0.0;
         m_lastWeeklyReset = current;
      }
   }

public:
   // Constructor
   CRiskCalculator()
   {
      m_riskPercent = 0.5;               // Default to 0.5% risk (v2.0)
      m_useAtrAdaptive = true;
      m_baseAtr = 0.0;
      m_baseAtrPeriod = 50;
      m_atrPeriod = 14;
      m_baseAtrHandle = INVALID_HANDLE;
      m_atrHandle = INVALID_HANDLE;
      
      // v2.0 defaults
      m_enableScalingAfterLoss = true;
      m_scalingFactor = 0.75;
      m_maxConsecutiveScaling = 3;
      
      // Risk limits
      m_dailyRiskLimit = 2.0;            // 2% daily limit
      m_weeklyRiskLimit = 5.0;           // 5% weekly limit
      m_dailyRiskUsed = 0.0;
      m_weeklyRiskUsed = 0.0;
      m_lastDailyReset = 0;
      m_lastWeeklyReset = 0;
      
      // Correlation risk
      m_enableCorrelationRisk = false;   // Disabled by default
      m_maxCorrelatedRisk = 2.0;         // 2% max for correlated positions
      
      // Symbol info cache
      m_symbol = "";
      m_tickValue = 0.0;
      m_minLot = 0.0;
      m_maxLot = 0.0;
      m_lotStep = 0.0;
   }
   
   // Destructor
   ~CRiskCalculator() 
   { 
      ReleaseIndicators();
   }
   
   // Release indicator handles
   void ReleaseIndicators()
   {
      if(m_baseAtrHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_baseAtrHandle);
         m_baseAtrHandle = INVALID_HANDLE;
      }
      
      if(m_atrHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_atrHandle);
         m_atrHandle = INVALID_HANDLE;
      }
   }
   
   // Initialization
   bool Init(double riskPercent, bool useAtrAdaptive, int atrPeriod = 14, int baseAtrPeriod = 50)
   {
      m_riskPercent = riskPercent;
      m_useAtrAdaptive = useAtrAdaptive;
      m_atrPeriod = atrPeriod;
      m_baseAtrPeriod = baseAtrPeriod;
      
      if(m_useAtrAdaptive)
      {
         // Create ATR indicator handles
         m_baseAtrHandle = iATR(_Symbol, PERIOD_CURRENT, m_baseAtrPeriod);
         m_atrHandle = iATR(_Symbol, PERIOD_CURRENT, m_atrPeriod);
         
         if(m_baseAtrHandle == INVALID_HANDLE || m_atrHandle == INVALID_HANDLE)
         {
            Print("Error: Unable to create ATR indicator handles");
            return false;
         }
         
         // Get base ATR value on initialization
         double atrBuffer[];
         ArraySetAsSeries(atrBuffer, true);
         if(CopyBuffer(m_baseAtrHandle, 0, 0, 1, atrBuffer) <= 0)
         {
            Print("Error: Unable to copy base ATR data");
            return false;
         }
         
         m_baseAtr = atrBuffer[0];
         if(m_baseAtr == 0)
         {
            Print("Error: Base ATR value is zero");
            return false;
         }
      }
      
      // Initialize daily and weekly risk tracking
      m_lastDailyReset = TimeCurrent();
      m_lastWeeklyReset = TimeCurrent();
      m_dailyRiskUsed = 0.0;
      m_weeklyRiskUsed = 0.0;
      
      // Initialize symbol info cache
      UpdateSymbolInfo(_Symbol);
      
      return true;
   }
   
   // Configure loss scaling
   void ConfigureLossScaling(bool enable, double factor, int maxScaling)
   {
      m_enableScalingAfterLoss = enable;
      m_scalingFactor = factor;
      m_maxConsecutiveScaling = maxScaling;
   }
   
   // Configure risk limits
   void ConfigureRiskLimits(double dailyLimit, double weeklyLimit)
   {
      m_dailyRiskLimit = dailyLimit;
      m_weeklyRiskLimit = weeklyLimit;
   }
   
   // Configure correlation risk
   void ConfigureCorrelationRisk(bool enable, double maxRisk)
   {
      m_enableCorrelationRisk = enable;
      m_maxCorrelatedRisk = maxRisk;
   }
   
   // Calculate position size based on risk and ATR
   double CalculatePositionSize(string symbol, double entryPrice, double stopLoss, 
                               ENUM_SETUP_QUALITY setupQuality = SETUP_QUALITY_A_PLUS, 
                               int consecutiveLosses = 0)
   {
      // Update symbol info cache
      UpdateSymbolInfo(symbol);
      
      // Check risk limit availability
      CheckRiskLimitReset();
      
      if(MathAbs(entryPrice - stopLoss) < _Point)
      {
         Print("Error: Entry price and stop loss are too close");
         return 0.0;
      }
      
      // Calculate risk multiplier based on setup quality
      double qualityMultiplier = 1.0;
      switch(setupQuality)
      {
         case SETUP_QUALITY_A_PLUS:
            qualityMultiplier = 1.0;  // 100% for A+ setups
            break;
         case SETUP_QUALITY_A:
            qualityMultiplier = 0.75; // 75% for A setups (v2.0)
            break;
         default:
            Print("Warning: Attempting to calculate position size for low-quality setup");
            qualityMultiplier = 0.0;  // No trading for B/C setups
            return 0.0;
      }
      
      // Apply consecutive loss scaling if enabled
      double lossMultiplier = 1.0;
      if(m_enableScalingAfterLoss && consecutiveLosses > 0)
      {
         int scalingCount = MathMin(consecutiveLosses, m_maxConsecutiveScaling);
         lossMultiplier = MathPow(m_scalingFactor, scalingCount);
      }
      
      // Combined risk multiplier
      double riskMultiplier = qualityMultiplier * lossMultiplier;
      
      // Calculate risk amount in account currency
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = accountBalance * m_riskPercent / 100.0 * riskMultiplier;
      
      // Check daily and weekly risk limits
      double availableDailyRisk = m_dailyRiskLimit - m_dailyRiskUsed;
      double availableWeeklyRisk = m_weeklyRiskLimit - m_weeklyRiskUsed;
      
      double maxRiskPercent = MathMin(availableDailyRisk, availableWeeklyRisk);
      if(maxRiskPercent <= 0)
      {
         Print("Risk limit reached. Daily: ", m_dailyRiskUsed, "/", m_dailyRiskLimit, 
               "%, Weekly: ", m_weeklyRiskUsed, "/", m_weeklyRiskLimit, "%");
         return 0.0;
      }
      
      // Adjust risk if necessary
      if(m_riskPercent * riskMultiplier > maxRiskPercent)
      {
         Print("Risk adjusted from ", m_riskPercent * riskMultiplier, "% to ", maxRiskPercent, 
               "% due to risk limits");
         riskAmount = accountBalance * maxRiskPercent / 100.0;
      }
      
      // Calculate stop loss distance in points
      double stopLossDistance = MathAbs(entryPrice - stopLoss) / _Point;
      
      // Check if tick value is valid
      if(m_tickValue == 0)
      {
         Print("Error: Invalid tick value for symbol ", symbol);
         return 0.0;
      }
      
      // Calculate lot size based on risk
      double lotSize = NormalizeDouble(riskAmount / (stopLossDistance * m_tickValue), 2);
      
      // Apply ATR adaptation if enabled
      if(m_useAtrAdaptive && m_baseAtr > 0 && m_atrHandle != INVALID_HANDLE)
      {
         double atrBuffer[];
         ArraySetAsSeries(atrBuffer, true);
         if(CopyBuffer(m_atrHandle, 0, 0, 1, atrBuffer) > 0)
         {
            double currentAtr = atrBuffer[0];
            if(currentAtr > 0)
            {
               double atrRatio = m_baseAtr / currentAtr;
               lotSize = NormalizeDouble(lotSize * atrRatio, 2);
            }
         }
      }
      
      // Ensure lot size is within symbol limits
      lotSize = MathMax(m_minLot, MathMin(m_maxLot, lotSize));
      lotSize = NormalizeDouble(lotSize / m_lotStep, 0) * m_lotStep;
      
      return lotSize;
   }
   
   // Calculate risk percentage for a given position size and stop loss
   double CalculateRiskPercentage(string symbol, double lotSize, double entryPrice, double stopLoss)
   {
      // Update symbol info cache
      UpdateSymbolInfo(symbol);
      
      if(MathAbs(entryPrice - stopLoss) < _Point)
      {
         Print("Error: Entry price and stop loss are too close");
         return 0.0;
      }
      
      // Calculate stop loss distance in points
      double stopLossDistance = MathAbs(entryPrice - stopLoss) / _Point;
      
      // Check if tick value is valid
      if(m_tickValue == 0)
      {
         Print("Error: Invalid tick value for symbol ", symbol);
         return 0.0;
      }
      
      // Calculate risk amount in account currency
      double riskAmount = lotSize * stopLossDistance * m_tickValue;
      
      // Calculate as percentage of account balance
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskPercentage = (riskAmount / accountBalance) * 100.0;
      
      return riskPercentage;
   }
   
   // Record risk for a new position
   void RecordPositionRisk(double riskPercent)
   {
      CheckRiskLimitReset();
      
      m_dailyRiskUsed += riskPercent;
      m_weeklyRiskUsed += riskPercent;
   }
   
   // Get available risk (accounting for daily/weekly limits)
   double GetAvailableRiskPercent()
   {
      CheckRiskLimitReset();
      
      double availableDailyRisk = m_dailyRiskLimit - m_dailyRiskUsed;
      double availableWeeklyRisk = m_weeklyRiskLimit - m_weeklyRiskUsed;
      
      return MathMin(availableDailyRisk, availableWeeklyRisk);
   }
   
   // Check if a new position would exceed correlation risk
   bool IsCorrelationRiskAcceptable(string newSymbol, double newRiskPercent, 
                                   string existingSymbols[], double existingRisks[])
   {
      if(!m_enableCorrelationRisk)
         return true;
         
      // Basic implementation - could be enhanced with actual correlation calculation
      for(int i = 0; i < ArraySize(existingSymbols); i++)
      {
         // If symbols are related (e.g., EURUSD and EURGBP both contain EUR)
         if(StringFind(existingSymbols[i], StringSubstr(newSymbol, 0, 3)) >= 0 || 
            StringFind(existingSymbols[i], StringSubstr(newSymbol, 3, 3)) >= 0)
         {
            // Calculate combined risk
            double combinedRisk = newRiskPercent + existingRisks[i];
            
            // Check against maximum correlated risk
            if(combinedRisk > m_maxCorrelatedRisk)
            {
               Print("Correlation risk too high: ", combinedRisk, "% > ", 
                     m_maxCorrelatedRisk, "% for ", newSymbol, " and ", existingSymbols[i]);
               return false;
            }
         }
      }
      
      return true;
   }
   
   // Update base ATR value
   void UpdateBaseAtr()
   {
      if(m_useAtrAdaptive && m_baseAtrHandle != INVALID_HANDLE)
      {
         double atrBuffer[];
         ArraySetAsSeries(atrBuffer, true);
         if(CopyBuffer(m_baseAtrHandle, 0, 0, 1, atrBuffer) > 0)
         {
            double newBaseAtr = atrBuffer[0];
            if(newBaseAtr > 0)
            {
               m_baseAtr = newBaseAtr;
            }
         }
      }
   }
   
   // Get risk parameters for reporting
   string GetRiskParameters()
   {
      string report = "Risk Settings:\n";
      report += "Base Risk: " + DoubleToString(m_riskPercent, 2) + "%\n";
      report += "Daily Risk Used: " + DoubleToString(m_dailyRiskUsed, 2) + "/" + 
                DoubleToString(m_dailyRiskLimit, 2) + "%\n";
      report += "Weekly Risk Used: " + DoubleToString(m_weeklyRiskUsed, 2) + "/" + 
                DoubleToString(m_weeklyRiskLimit, 2) + "%\n";
      report += "Scaling After Loss: " + (m_enableScalingAfterLoss ? "Enabled" : "Disabled") + 
                " (Factor: " + DoubleToString(m_scalingFactor, 2) + ", Max: " + 
                IntegerToString(m_maxConsecutiveScaling) + ")\n";
      report += "ATR Adaptation: " + (m_useAtrAdaptive ? "Enabled" : "Disabled");
      
      return report;
   }
   
   // Deinitialize
   void Deinit()
   {
      ReleaseIndicators();
   }
};