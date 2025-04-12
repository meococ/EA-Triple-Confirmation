//+------------------------------------------------------------------+
//|                                              TradeManager.mqh    |
//|                        Copyright 2025, Your Company              |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"
#property version   "2.00"

#include <Trade\Trade.mqh>
#include "CommonDefinitions.mqh"

class CTradeManager
{
private:
   CTrade*           m_trade;         // Trade object pointer
   int               m_magic;         // Magic number
   bool              m_isMultiTP;     // Flag for multiple take profits
   
   // Partial close management
   struct PartialCloseInfo
   {
      ulong            ticket;            // Position ticket
      double           entryPrice;        // Entry price
      double           stopLoss;          // Current stop loss
      double           tp1;               // Take profit 1 level
      double           tp2;               // Take profit 2 level
      double           tp3;               // Take profit 3 level
      bool             tp1_triggered;     // TP1 triggered flag
      bool             tp2_triggered;     // TP2 triggered flag
      bool             tp3_triggered;     // TP3 triggered flag
      bool             breakeven_set;     // Breakeven SL set flag
      bool             trail_active;      // Trailing stop active flag
      double           trail_step;        // Trailing step in points
      double           original_volume;   // Original position volume
      int              tp1_percent;       // Percentage to close at TP1
      int              tp2_percent;       // Percentage to close at TP2
      int              tp3_percent;       // Percentage to close at TP3
      ENUM_SETUP_QUALITY setupQuality;    // Setup quality for this position
      datetime         openTime;          // Position open time
   };
   
   PartialCloseInfo  m_positions[];       // Array to store position info
   
   // Find position by ticket
   int FindPositionIndex(ulong ticket)
   {
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         if(m_positions[i].ticket == ticket)
            return i;
      }
      return -1;
   }
   
   // Add new position to tracking array
   void AddPosition(ulong ticket, double entryPrice, double stopLoss, 
                   double tp1, double tp2, double tp3, double volume, 
                   int tp1_percent, int tp2_percent, int tp3_percent,
                   ENUM_SETUP_QUALITY setupQuality)
   {
      int size = ArraySize(m_positions);
      ArrayResize(m_positions, size + 1);
      
      m_positions[size].ticket = ticket;
      m_positions[size].entryPrice = entryPrice;
      m_positions[size].stopLoss = stopLoss;
      m_positions[size].tp1 = tp1;
      m_positions[size].tp2 = tp2;
      m_positions[size].tp3 = tp3;
      m_positions[size].tp1_triggered = false;
      m_positions[size].tp2_triggered = false;
      m_positions[size].tp3_triggered = false;
      m_positions[size].breakeven_set = false;
      m_positions[size].trail_active = false;
      m_positions[size].trail_step = 10 * _Point; // Default 10 points trail step
      m_positions[size].original_volume = volume;
      m_positions[size].tp1_percent = tp1_percent;
      m_positions[size].tp2_percent = tp2_percent;
      m_positions[size].tp3_percent = tp3_percent;
      m_positions[size].setupQuality = setupQuality;
      m_positions[size].openTime = TimeCurrent();
      
      Print("Position added to tracking: #", ticket, ", Entry: ", entryPrice, 
           ", SL: ", stopLoss, ", TP1: ", tp1, ", Quality: ", 
           GetSetupQualityString(setupQuality));
   }
   
   // Remove position from tracking array
   void RemovePosition(int index)
   {
      if(index < 0 || index >= ArraySize(m_positions))
         return;
         
      for(int i = index; i < ArraySize(m_positions) - 1; i++)
      {
         m_positions[i] = m_positions[i + 1];
      }
      
      ArrayResize(m_positions, ArraySize(m_positions) - 1);
   }
   
   // Check and execute partial close
   bool ExecutePartialClose(int index, double currentPrice, ENUM_POSITION_TYPE posType)
   {
      if(index < 0 || index >= ArraySize(m_positions))
         return false;
         
      PartialCloseInfo pos = m_positions[index];
      
      // Check if we need to do partial close at TP1
      if(!pos.tp1_triggered && 
         ((posType == POSITION_TYPE_BUY && currentPrice >= pos.tp1) || 
          (posType == POSITION_TYPE_SELL && currentPrice <= pos.tp1)))
      {
         // Calculate volume to close at TP1
         double tp1Volume = NormalizeDouble(pos.original_volume * pos.tp1_percent / 100.0, 2);
         
         // Ensure minimum volume
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(tp1Volume < minLot)
            tp1Volume = minLot;
            
         // Execute partial close
         if(m_trade.PositionClosePartial(pos.ticket, tp1Volume))
         {
            m_positions[index].tp1_triggered = true;
            Print("TP1 triggered for position #", pos.ticket, " - Closed ", tp1Volume, " lots");
            return true;
         }
      }
      
      // Check if we need to do partial close at TP2
      if(pos.tp1_triggered && !pos.tp2_triggered && 
         ((posType == POSITION_TYPE_BUY && currentPrice >= pos.tp2) || 
          (posType == POSITION_TYPE_SELL && currentPrice <= pos.tp2)))
      {
         // Calculate volume to close at TP2
         double tp2Volume = NormalizeDouble(pos.original_volume * pos.tp2_percent / 100.0, 2);
         
         // Ensure minimum volume
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(tp2Volume < minLot)
            tp2Volume = minLot;
            
         // Execute partial close
         if(m_trade.PositionClosePartial(pos.ticket, tp2Volume))
         {
            m_positions[index].tp2_triggered = true;
            Print("TP2 triggered for position #", pos.ticket, " - Closed ", tp2Volume, " lots");
            return true;
         }
      }
      
      // Check if we need to do partial close at TP3
      if(pos.tp1_triggered && pos.tp2_triggered && !pos.tp3_triggered && 
         ((posType == POSITION_TYPE_BUY && currentPrice >= pos.tp3) || 
          (posType == POSITION_TYPE_SELL && currentPrice <= pos.tp3)))
      {
         // At TP3, close the entire remaining position
         if(m_trade.PositionClose(pos.ticket))
         {
            m_positions[index].tp3_triggered = true;
            Print("TP3 triggered for position #", pos.ticket, " - Closed remaining position");
            return true;
         }
      }
      
      return false;
   }
   
   // Check and update trailing stop
   bool UpdateTrailingStop(int index, double currentPrice, ENUM_POSITION_TYPE posType)
   {
      if(index < 0 || index >= ArraySize(m_positions))
         return false;
         
      PartialCloseInfo &pos = m_positions[index]; // Use reference to update position
      
      // Calculate current profit in ATR units (using TP1 as 1R reference)
      double profitPoints = 0;
      double r1Size = 0;
      
      if(posType == POSITION_TYPE_BUY)
      {
         profitPoints = currentPrice - pos.entryPrice;
         r1Size = pos.tp1 - pos.entryPrice;
      }
      else // SELL
      {
         profitPoints = pos.entryPrice - currentPrice;
         r1Size = pos.entryPrice - pos.tp1;
      }
      
      // Make sure r1Size is not zero to avoid division by zero
      if(MathAbs(r1Size) < _Point)
         return false;
         
      // Calculate R multiple
      double rMultiple = profitPoints / r1Size;
      
      // NEW: Move SL to breakeven when profit > 1R (v2.0)
      if(!pos.breakeven_set && rMultiple >= 1.0)
      {
         if(m_trade.PositionModify(pos.ticket, pos.entryPrice, 0))
         {
            pos.breakeven_set = true;
            pos.stopLoss = pos.entryPrice;
            Print("Breakeven SL set for position #", pos.ticket);
            return true;
         }
      }
      
      // NEW: Implement protective trailing when profit > 2R (v2.0)
      if(rMultiple >= 2.0)
      {
         pos.trail_active = true;
         
         // Calculate new SL based on position type
         double newSL;
         if(posType == POSITION_TYPE_BUY)
         {
            // For buy positions, set SL to protect 1R of profit
            double protectLevel = pos.entryPrice + (r1Size * 1.0); // Protect 1R of profit
            newSL = MathMax(pos.stopLoss, protectLevel);
            
            // Implement trailing stop with minimum step
            double potentialSL = currentPrice - pos.trail_step;
            if(potentialSL > newSL + pos.trail_step) // Only move if significant improvement
               newSL = potentialSL;
         }
         else // SELL
         {
            // For sell positions, set SL to protect 1R of profit
            double protectLevel = pos.entryPrice - (r1Size * 1.0); // Protect 1R of profit
            newSL = MathMin(pos.stopLoss, protectLevel);
            
            // Implement trailing stop with minimum step
            double potentialSL = currentPrice + pos.trail_step;
            if(potentialSL < newSL - pos.trail_step) // Only move if significant improvement
               newSL = potentialSL;
         }
         
         // Only modify if SL actually changes
         if(MathAbs(newSL - pos.stopLoss) > _Point)
         {
            if(m_trade.PositionModify(pos.ticket, newSL, 0))
            {
               Print("Trailing SL updated for position #", pos.ticket, 
                    " from ", pos.stopLoss, " to ", newSL, 
                    " (R multiple: ", DoubleToString(rMultiple, 2), ")");
               pos.stopLoss = newSL;
               return true;
            }
         }
      }
      
      return false;
   }
   
   // Helper method to convert setup quality to string
   string GetSetupQualityString(ENUM_SETUP_QUALITY quality)
   {
      switch(quality)
      {
         case SETUP_QUALITY_A_PLUS: return "A+";
         case SETUP_QUALITY_A: return "A";
         case SETUP_QUALITY_B: return "B";
         case SETUP_QUALITY_C: return "C";
         default: return "None";
      }
   }

public:
   // Constructor
   CTradeManager()
   {
      m_trade = NULL;
      m_magic = 0;
      m_isMultiTP = false;
   }
   
   // Destructor
   ~CTradeManager()
   {
      // Don't delete m_trade as it's an external pointer
   }
   
   // Initialization
   bool Init(CTrade* trade, int magic)
   {
      if(trade == NULL)
      {
         Print("Error: Trade object is NULL");
         return false;
      }
      
      m_trade = trade;
      m_magic = magic;
      
      return true;
   }
   
   // Deinitialization
   void Deinit()
   {
      ArrayFree(m_positions);
   }
   
   // Open a new trade
   bool OpenTrade(ENUM_ORDER_TYPE type, double volume, double stopLoss, double takeProfit,
                 int tp1Percent = 100, int tp2Percent = 0, int tp3Percent = 0,
                 double takeProfit2 = 0.0, double takeProfit3 = 0.0,
                 ENUM_SETUP_QUALITY setupQuality = SETUP_QUALITY_A_PLUS)
   {
      // Validate parameters
      if(volume <= 0)
      {
         Print("Invalid volume: ", volume);
         return false;
      }
      
      // Check if we need to use multiple take profits
      m_isMultiTP = (tp1Percent < 100) && (tp2Percent > 0 || tp3Percent > 0);
      
      // Get current price for entry
      double entryPrice = (type == ORDER_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      // Execute the trade
      if(!m_trade.PositionOpen(_Symbol, type, volume, entryPrice, stopLoss, takeProfit, 
                              "Triple Confirmation v2.0"))
      {
         Print("Error opening position: ", m_trade.ResultRetcodeDescription());
         return false;
      }
      
      // Get trade result info
      ulong ticket = m_trade.ResultOrder(); // Get the ticket of the order
      
      // For any position, add to tracking array
      AddPosition(ticket, entryPrice, stopLoss, 
                 takeProfit, takeProfit2, takeProfit3, volume, 
                 tp1Percent, tp2Percent, tp3Percent, 
                 setupQuality);
      
      Print("Position opened: #", ticket, " with TP at ", takeProfit, ", ", 
            takeProfit2, ", ", takeProfit3, ", SL at ", stopLoss, 
            ", Quality: ", GetSetupQualityString(setupQuality));
      
      return true;
   }
   
   // Manage open positions (check for partial closes, breakeven, trailing, etc.)
   void ManagePositions(double slAtrMultiplier, double tp1AtrMultiplier, 
                       double tp2AtrMultiplier, double tp3AtrMultiplier,
                       int tp1Percent, int tp2Percent, int tp3Percent)
   {
      // Skip if no positions to manage
      if(ArraySize(m_positions) == 0)
         return;
         
      // Loop through all open positions
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         
         // Skip positions that don't belong to this EA
         if(PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;
            
         // Find position in our tracking array
         int index = FindPositionIndex(ticket);
         if(index < 0)
            continue;
            
         // Get position details
         string symbol = PositionGetString(POSITION_SYMBOL);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         // Update trailing stop first (may modify SL)
         UpdateTrailingStop(index, currentPrice, posType);
         
         // Check and execute partial closes if needed
         if(m_isMultiTP)
         {
            ExecutePartialClose(index, currentPrice, posType);
         }
      }
      
      // Clean up positions that are no longer open
      for(int i = ArraySize(m_positions) - 1; i >= 0; i--)
      {
         if(!PositionSelectByTicket(m_positions[i].ticket))
         {
            RemovePosition(i);
         }
      }
   }
   
   // Get setup quality for a position ticket
   ENUM_SETUP_QUALITY GetPositionSetupQuality(ulong ticket)
   {
      int index = FindPositionIndex(ticket);
      if(index >= 0)
         return m_positions[index].setupQuality;
      
      return SETUP_QUALITY_NONE;
   }
   
   // Handle trade transaction events
   void OnTradeTransaction(const MqlTradeTransaction& trans,
                          const MqlTradeRequest& request,
                          const MqlTradeResult& result)
   {
      // Process position add events for our EA
      if(trans.type == TRADE_TRANSACTION_DEAL_ADD && 
         ((trans.deal_type == DEAL_TYPE_BUY) || (trans.deal_type == DEAL_TYPE_SELL)))
      {
         // Check if this is one of our deals
         ulong dealTicket = trans.deal;
         if(dealTicket == 0)
            return;
            
         if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != m_magic)
            return;
            
         // If this is a position opening, we don't need to do anything here
         // as it's handled in OpenTrade()
      }
      
      // Process position removal (fully closed)
      if(trans.type == TRADE_TRANSACTION_DEAL_ADD && 
         ((trans.deal_type == DEAL_TYPE_BUY) || (trans.deal_type == DEAL_TYPE_SELL)))
      {
         ulong dealTicket = trans.deal;
         if(dealTicket == 0)
            return;
            
         if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != m_magic)
            return;
            
         // If this is a position closing, remove it from our tracking
         if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            ulong posTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
            int index = FindPositionIndex(posTicket);
            
            if(index >= 0)
            {
               ENUM_SETUP_QUALITY quality = m_positions[index].setupQuality;
               RemovePosition(index);
               Print("Position #", posTicket, " closed and removed from tracking. Quality was: ",
                    GetSetupQualityString(quality));
            }
         }
      }
   }
   
   // Get number of positions currently tracked
   int GetPositionsCount()
   {
      return ArraySize(m_positions);
   }
   
   // Get all current position tickets
   bool GetAllPositionTickets(ulong &tickets[])
   {
      int count = ArraySize(m_positions);
      if(count == 0)
         return false;
      
      ArrayResize(tickets, count);
      for(int i = 0; i < count; i++)
      {
         tickets[i] = m_positions[i].ticket;
      }
      
      return true;
   }
   
   // Set trailing stop parameters for a position
   bool SetTrailingParameters(ulong ticket, double trailStep)
   {
      int index = FindPositionIndex(ticket);
      if(index < 0)
         return false;
      
      m_positions[index].trail_step = trailStep;
      return true;
   }
};