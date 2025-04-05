//+------------------------------------------------------------------+
//|                                              TradeManager.mqh |
//|                        Copyright 2025, Your Company               |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"

#include <Trade\Trade.mqh>

enum ENUM_TRADE_DIRECTION
{
   TRADE_DIRECTION_BUY,
   TRADE_DIRECTION_SELL
};

enum ENUM_SETUP_QUALITY
{
   SETUP_QUALITY_NONE,
   SETUP_QUALITY_B,
   SETUP_QUALITY_A,
   SETUP_QUALITY_A_PLUS
};

enum ENUM_MARKET_CONDITION
{
   MARKET_CONDITION_UNDEFINED,
   MARKET_CONDITION_TRENDING,
   MARKET_CONDITION_RANGING,
   MARKET_CONDITION_VOLATILE,
   MARKET_CONDITION_TRANSITION
};

class CTradeManager
{
private:
   CTrade*           m_trade;         // Trade object pointer
   int               m_magic;         // Magic number
   bool              m_isMultiTP;     // Flag for multiple take profits
   
   // Partial close management
   struct PartialCloseInfo
   {
      ulong    ticket;            // Position ticket
      double   tp1;               // Take profit 1 level
      double   tp2;               // Take profit 2 level
      double   tp3;               // Take profit 3 level
      bool     tp1_triggered;     // TP1 triggered flag
      bool     tp2_triggered;     // TP2 triggered flag
      bool     tp3_triggered;     // TP3 triggered flag
      double   original_volume;   // Original position volume
      int      tp1_percent;       // Percentage to close at TP1
      int      tp2_percent;       // Percentage to close at TP2
      int      tp3_percent;       // Percentage to close at TP3
   };
   
   PartialCloseInfo  m_positions[];   // Array to store position info
   
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
   void AddPosition(ulong ticket, double tp1, double tp2, double tp3, double volume, 
                   int tp1_percent, int tp2_percent, int tp3_percent)
   {
      int size = ArraySize(m_positions);
      ArrayResize(m_positions, size + 1);
      
      m_positions[size].ticket = ticket;
      m_positions[size].tp1 = tp1;
      m_positions[size].tp2 = tp2;
      m_positions[size].tp3 = tp3;
      m_positions[size].tp1_triggered = false;
      m_positions[size].tp2_triggered = false;
      m_positions[size].tp3_triggered = false;
      m_positions[size].original_volume = volume;
      m_positions[size].tp1_percent = tp1_percent;
      m_positions[size].tp2_percent = tp2_percent;
      m_positions[size].tp3_percent = tp3_percent;
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
         if(tp1Volume < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
            tp1Volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            
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
         if(tp2Volume < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
            tp2Volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            
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
      if(m_trade != NULL)
         delete m_trade;
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
                 double takeProfit2 = 0.0, double takeProfit3 = 0.0)
   {
      // Validate parameters
      if(volume <= 0)
      {
         Print("Invalid volume: ", volume);
         return false;
      }
      
      // Check if we need to use multiple take profits
      m_isMultiTP = (tp1Percent < 100) && (tp2Percent > 0 || tp3Percent > 0);
      
      // For multi-TP, we initially set TP1 only and handle TP2 and TP3 with partial closes
      double tp = m_isMultiTP ? takeProfit : takeProfit;
      
      // Execute the trade
      if(!m_trade.PositionOpen(_Symbol, type, volume, 0, stopLoss, tp, "Triple Confirmation EA"))
      {
         Print("Error opening position: ", m_trade.ResultRetcodeDescription());
         return false;
      }
      
      // If using multiple TPs, add position to tracking array
      if(m_isMultiTP)
      {
         ulong ticket = m_trade.ResultDeal();
         AddPosition(ticket, takeProfit, takeProfit2, takeProfit3, volume, 
                     tp1Percent, tp2Percent, tp3Percent);
         
         Print("Multi-TP position opened: #", ticket, " with TPs at ", takeProfit, ", ", 
               takeProfit2, ", ", takeProfit3);
      }
      
      return true;
   }
   
   // Manage open positions (check for partial closes, etc.)
   void ManagePositions(double slAtrMultiplier, double tp1AtrMultiplier, 
                       double tp2AtrMultiplier, double tp3AtrMultiplier,
                       int tp1Percent, int tp2Percent, int tp3Percent)
   {
      // Skip if no multi-TP positions
      if(!m_isMultiTP || ArraySize(m_positions) == 0)
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
         
         // Check and execute partial closes if needed
         ExecutePartialClose(index, currentPrice, posType);
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
               RemovePosition(index);
               Print("Position #", posTicket, " closed and removed from tracking");
            }
         }
      }
   }
};