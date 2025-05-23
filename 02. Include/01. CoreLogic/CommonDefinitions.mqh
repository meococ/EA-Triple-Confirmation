//+------------------------------------------------------------------+
//|                                        CommonDefinitions.mqh     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"

// Định nghĩa chung - để tránh định nghĩa trùng lặp
#ifndef COMMON_DEFINITIONS_INCLUDED
#define COMMON_DEFINITIONS_INCLUDED

enum ENUM_TRADE_DIRECTION
{
   TRADE_DIRECTION_NONE, // Không xác định
   TRADE_DIRECTION_BUY,  // Mua
   TRADE_DIRECTION_SELL  // Bán
};

enum ENUM_SETUP_QUALITY
{
   SETUP_QUALITY_NONE,
   SETUP_QUALITY_C,    // Thêm setup C (yếu)
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

// Cấu trúc cho chi tiết giao dịch
struct STradeDetails
{
   string            symbol;
   double            entryPrice;
   ENUM_TRADE_DIRECTION direction;
   double            stopLoss;
   double            takeProfit1;
   double            takeProfit2;
   double            takeProfit3;
   double            riskReward;
   ENUM_SETUP_QUALITY setupQuality;
   ENUM_MARKET_CONDITION marketCondition;
   double            lotSize;
   double            risk;
   
   // Các giá trị chỉ báo
   double            RSI;
   double            VWAP_Distance;
   double            BB_Distance;
   double            OBV;
   double            ATR;
};

// Cấu trúc cho kết quả giao dịch
struct STradeResult
{
   ulong             ticket;
   string            symbol;
   double            profit;
   ENUM_ORDER_TYPE   type;
   double            pips;
   datetime          openTime;
   datetime          closeTime;
   int               duration;
   ENUM_SETUP_QUALITY setupQuality;
   string            exitReason;
};

// Cấu trúc cho kết quả phân tích hiệu suất
struct SEdgePerformanceResult
{
   int               totalTrades;
   double            winRate;
   double            expectancy;
   double            profitFactor;
   double            averageWin;
   double            averageLoss;
   double            maxDrawdown;
};

// Cấu trúc cho kết quả phân tích suy giảm edge
struct SEdgeDegradation
{
   bool              hasDegradation;
   double            degradationPercent;
   string            messages;
   string            recommendations;
};

#endif // COMMON_DEFINITIONS_INCLUDED