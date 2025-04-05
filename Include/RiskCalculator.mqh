//+------------------------------------------------------------------+
//|                                            RiskCalculator.mqh |
//|                        Copyright 2025, Your Company               |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"

class CRiskCalculator
{
private:
   double            m_riskPercent;      // Percentage of account to risk per trade
   bool              m_useAtrAdaptive;   // Flag for ATR-adaptive position sizing
   double            m_baseAtr;          // Base ATR value for adaptive sizing
   int               m_baseAtrPeriod;    // Period for base ATR calculation
   int               m_atrPeriod;        // Current ATR period
   int               m_baseAtrHandle;    // Handle for base ATR indicator
   int               m_atrHandle;        // Handle for current ATR indicator

public:
   // Constructor
   CRiskCalculator()
   {
      m_riskPercent = 1.0;
      m_useAtrAdaptive = false;
      m_baseAtr = 0.0;
      m_baseAtrPeriod = 50;
      m_atrPeriod = 14;
      m_baseAtrHandle = INVALID_HANDLE;
      m_atrHandle = INVALID_HANDLE;
   }
   
   // Destructor
   ~CRiskCalculator() 
   { 
      if(m_baseAtrHandle != INVALID_HANDLE)
         IndicatorRelease(m_baseAtrHandle);
      if(m_atrHandle != INVALID_HANDLE)
         IndicatorRelease(m_atrHandle);
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
      
      return true;
   }
   
   // Calculate position size based on risk and ATR
   double CalculatePositionSize(double entryPrice, double stopLoss, double riskMultiplier = 1.0)
   {
      if(MathAbs(entryPrice - stopLoss) < _Point)
      {
         Print("Error: Entry price and stop loss are too close");
         return 0.0;
      }
      
      // Calculate risk amount in account currency
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = accountBalance * m_riskPercent / 100.0 * riskMultiplier;
      
      // Calculate stop loss distance in points
      double stopLossDistance = MathAbs(entryPrice - stopLoss) / _Point;
      
      // Calculate tick value in account currency
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tickValue == 0)
      {
         Print("Error: Unable to get tick value");
         return 0.0;
      }
      
      // Calculate lot size based on risk
      double lotSize = NormalizeDouble(riskAmount / (stopLossDistance * tickValue), 2);
      
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
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
      lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;
      
      return lotSize;
   }
   
   // Calculate risk percentage for a given position size and stop loss
   double CalculateRiskPercentage(double lotSize, double entryPrice, double stopLoss)
   {
      if(MathAbs(entryPrice - stopLoss) < _Point)
      {
         Print("Error: Entry price and stop loss are too close");
         return 0.0;
      }
      
      // Calculate stop loss distance in points
      double stopLossDistance = MathAbs(entryPrice - stopLoss) / _Point;
      
      // Calculate tick value in account currency
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tickValue == 0)
      {
         Print("Error: Unable to get tick value");
         return 0.0;
      }
      
      // Calculate risk amount in account currency
      double riskAmount = lotSize * stopLossDistance * tickValue;
      
      // Calculate as percentage of account balance
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskPercentage = (riskAmount / accountBalance) * 100.0;
      
      return riskPercentage;
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
   
   // Deinitialize
   void Deinit()
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
};