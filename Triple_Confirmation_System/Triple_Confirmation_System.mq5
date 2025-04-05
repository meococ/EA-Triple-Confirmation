//+------------------------------------------------------------------+
//|                                           TripleConfirmation.mq5 |
//|                        Copyright 2025, Your Company               |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"
#property version   "1.00"

// Các include cần thiết
#include <Trade\Trade.mqh>       // Thư viện giao dịch chuẩn
#include <Include\ConfigManager.mqh>   // Thêm ConfigManager
#include <Include\NewsManager.mqh>
#include <Include\TradeJournal.mqh>
#include <Include\Dashboard.mqh>
#include <Include\EAPanel.mqh>
#include <Include\EdgeCalculator.mqh>
#include <Include\TradeManager.mqh>
#include <Include\RiskCalculator.mqh>

// Khởi tạo các đối tượng
CTrade         Trade;            // Đối tượng giao dịch
CConfigManager ConfigManager;    // Quản lý cấu hình
CNewsManager   NewsManager;      // Quản lý tin tức
CTradeJournal  Journal;          // Nhật ký giao dịch
CDashboard     MainDashboard;    // Panel tổng quan
CEAPanel       EAPanel;          // Panel riêng EA
CEdgeCalculator EdgeCalc;        // Tính toán Edge
CTradeManager  TradeManager;     // Quản lý giao dịch
CRiskCalculator RiskCalc;        // Tính toán rủi ro

// Tham số đầu vào cho EA
input group "===== Cài Đặt Chung ====="
input string   EA_Name = "Triple_Confirmation";  // Tên EA
input bool     Enable_Trading = true;            // Bật/tắt giao dịch
input bool     Enable_News_Filter = true;        // Bật/tắt lọc tin tức
input double   Risk_Percent = 1.0;               // % rủi ro/lệnh
input int      Magic_Number = 123456;            // Số magic

input group "===== Cài Đặt Chiến Lược ====="
input int      VWAP_Period = 20;                 // Chu kỳ VWAP
input int      RSI_Period = 9;                   // Chu kỳ RSI
input int      RSI_Oversold = 35;                // Ngưỡng quá bán RSI
input int      RSI_Overbought = 65;              // Ngưỡng quá mua RSI
input int      BB_Period = 20;                   // Chu kỳ Bollinger Bands
input double   BB_Deviation = 2.0;               // Độ lệch chuẩn BB
input int      ATR_Period = 14;                  // Chu kỳ ATR cho SL/TP

input group "===== Cài Đặt Take Profit & Stop Loss ====="
input double   SL_ATR_Multiplier = 1.2;          // Hệ số ATR cho SL
input double   TP1_ATR_Multiplier = 1.5;         // Hệ số ATR cho TP1
input double   TP2_ATR_Multiplier = 2.5;         // Hệ số ATR cho TP2
input double   TP3_ATR_Multiplier = 4.0;         // Hệ số ATR cho TP3
input int      TP1_Percent = 40;                 // % khối lượng TP1
input int      TP2_Percent = 35;                 // % khối lượng TP2
input int      TP3_Percent = 25;                 // % khối lượng TP3

input group "===== Cài Đặt Quản Lý Vốn ====="
input bool     Use_ATR_Adaptive_Sizing = true;   // Size thích ứng theo ATR
input int      ATR_Base_Period = 50;             // ATR cơ sở
input bool     Enable_Scaling_After_Loss = true; // Giảm size sau thua
input double   Scaling_Factor = 0.75;            // Hệ số giảm

input group "===== Cài Đặt Lọc Thị Trường ====="
input bool     Use_ADX_Filter = true;            // Sử dụng lọc ADX
input int      ADX_Period = 14;                  // Chu kỳ ADX
input int      ADX_Trending_Threshold = 25;      // Ngưỡng xu hướng
input int      ADX_Ranging_Threshold = 20;       // Ngưỡng dao động

input group "===== Cài Đặt Ghi Log ====="
input bool     Enable_Detailed_Logging = true;   // Ghi log chi tiết
input string   Log_Directory = "TripleConfirmation_Logs"; // Thư mục log

input group "===== Cài Đặt Cấu Hình ====="
input bool     UseConfigFile = false;            // Sử dụng file cấu hình
input string   ConfigDirectory = "Triple_Confirmation_System\\Data"; // Thư mục cấu hình

// Biến toàn cục
bool           IsNewBar = false;
datetime       LastBarTime = 0;
int            ConsecutiveLosses = 0;
ENUM_MARKET_CONDITION MarketCondition = MARKET_CONDITION_UNDEFINED;

// Handle cho indicator Triple Confirmation
int            TC_Handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Khởi tạo ConfigManager
   if(UseConfigFile)
   {
      if(!ConfigManager.Init(EA_Name))
      {
         Print("Không thể khởi tạo ConfigManager. EA sẽ sử dụng tham số nhập trực tiếp.");
      }
      else
      {
         // Tải cấu hình từ file (nếu UseConfigFile = true)
         // Có thể ghi đè lên các tham số nhập nếu muốn
         // Risk_Percent = ConfigManager.GetRiskPercent();
         // Enable_News_Filter = ConfigManager.GetEnableNewsFilter();
         // ...
      }
   }
   
   // Thiết lập magic number
   Trade.SetExpertMagicNumber(Magic_Number);
   
   // Khởi tạo handle cho indicator Triple Confirmation
   TC_Handle = iCustom(_Symbol, PERIOD_CURRENT, "Triple_Confirmation_System\\Indicators\\TripleConfirmation", 
                      VWAP_Period, RSI_Period, RSI_Oversold, RSI_Overbought, 
                      BB_Period, BB_Deviation, false);
   
   if(TC_Handle == INVALID_HANDLE)
   {
      Print("Không thể tạo handle cho indicator TripleConfirmation. Lỗi: ", GetLastError());
      // Không return INIT_FAILED ở đây vì EA vẫn có thể hoạt động với các chỉ báo riêng lẻ
   }
   
   // Khởi tạo các module
   if(!NewsManager.Init(Enable_News_Filter))
      return INIT_FAILED;
   
   if(!Journal.Init(Log_Directory, EA_Name, Enable_Detailed_Logging))
      return INIT_FAILED;
   
   if(!MainDashboard.Init(EA_Name, 10, 10)) // Vị trí góc trên bên trái
      return INIT_FAILED;
   
   if(!EAPanel.Init(EA_Name, ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - 210, 10)) // Góc trên bên phải
      return INIT_FAILED;
   
   if(!EdgeCalc.Init(EA_Name))
      return INIT_FAILED;
   
   if(!TradeManager.Init(&Trade, Magic_Number))
      return INIT_FAILED;
   
   if(!RiskCalc.Init(Risk_Percent, Use_ATR_Adaptive_Sizing))
      return INIT_FAILED;
      
   // Ghi log khởi động EA
   Journal.LogInfo("EA Triple Confirmation khởi động. Phiên bản: 1.00");
   Journal.LogInfo("Cấu hình từ file: " + (UseConfigFile ? "Bật" : "Tắt"));
   Journal.LogEAStart();
   
   // Cập nhật panel
   UpdatePanels();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Ghi log kết thúc EA
   Journal.LogEAStop(reason);
   
   // Lưu cấu hình nếu đã có thay đổi
   if(UseConfigFile)
   {
      ConfigManager.SaveConfig();
   }
   
   // Giải phóng handle indicator
   if(TC_Handle != INVALID_HANDLE)
   {
      IndicatorRelease(TC_Handle);
      TC_Handle = INVALID_HANDLE;
   }
   
   // Dọn dẹp các module
   NewsManager.Deinit();
   Journal.Deinit();
   MainDashboard.Deinit();
   EAPanel.Deinit();
   EdgeCalc.Deinit();
   TradeManager.Deinit();
   RiskCalc.Deinit();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Kiểm tra nến mới
   IsNewBar = IsNewBarFormed();
   
   // Cập nhật trạng thái thị trường và điều kiện
   UpdateMarketCondition();
   
   // Kiểm tra và quản lý các lệnh đang mở
   ManageOpenPositions();
   
   // Chỉ tìm kiếm tín hiệu mới khi có nến mới và cho phép giao dịch
   if(IsNewBar && Enable_Trading)
   {
      // Nếu đang có tin tức quan trọng, bỏ qua
      if(NewsManager.IsHighImpactNews())
      {
         Journal.LogInfo("Đang có tin tức quan trọng, bỏ qua tìm kiếm tín hiệu");
         return;
      }
      
      // Tìm kiếm tín hiệu mới
      CheckForSignals();
   }
   
   // Cập nhật panel mỗi 3 giây
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate >= 3)
   {
      UpdatePanels();
      lastUpdate = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Kiểm tra xem có nến mới hay không                               |
//+------------------------------------------------------------------+
bool IsNewBarFormed()
{
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(currentBarTime != LastBarTime)
   {
      LastBarTime = currentBarTime;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Cập nhật điều kiện thị trường                                   |
//+------------------------------------------------------------------+
void UpdateMarketCondition()
{
   // Tính ADX
   double adxValue = iADX(_Symbol, PERIOD_CURRENT, ADX_Period, PRICE_CLOSE, 0);
   
   // Phân loại thị trường
   if(adxValue > ADX_Trending_Threshold)
      MarketCondition = MARKET_CONDITION_TRENDING;
   else if(adxValue < ADX_Ranging_Threshold)
      MarketCondition = MARKET_CONDITION_RANGING;
   else
      MarketCondition = MARKET_CONDITION_TRANSITION;
      
   // Cập nhật vào EAPanel
   EAPanel.UpdateMarketCondition(MarketCondition);
}

//+------------------------------------------------------------------+
//| Quản lý các lệnh đang mở                                        |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   // Chuyển giao cho TradeManager xử lý
   TradeManager.ManagePositions(SL_ATR_Multiplier, TP1_ATR_Multiplier, 
                               TP2_ATR_Multiplier, TP3_ATR_Multiplier,
                               TP1_Percent, TP2_Percent, TP3_Percent);
}

//+------------------------------------------------------------------+
//| Tìm kiếm tín hiệu giao dịch mới                                 |
//+------------------------------------------------------------------+
void CheckForSignals()
{
   // --- Kiểm tra điều kiện lọc thị trường ---
   if(Use_ADX_Filter)
   {
      if(MarketCondition == MARKET_CONDITION_UNDEFINED)
         return;
         
      // Chỉ giao dịch khi thị trường phù hợp với chiến lược
      if(MarketCondition != MARKET_CONDITION_TRENDING && 
         MarketCondition != MARKET_CONDITION_RANGING)
      {
         Journal.LogInfo("Điều kiện thị trường không phù hợp để giao dịch");
         return;
      }
   }
   
   // --- Tính toán các chỉ báo ---
   
   // Kiểm tra nếu có handle TripleConfirmation hợp lệ (cách ưu tiên)
   bool buySignal = false;
   bool sellSignal = false;
   ENUM_SETUP_QUALITY buySetupQuality = SETUP_QUALITY_NONE;
   ENUM_SETUP_QUALITY sellSetupQuality = SETUP_QUALITY_NONE;
   
   if(TC_Handle != INVALID_HANDLE)
   {
      // Lấy tín hiệu từ indicator TripleConfirmation
      double buyBuffer[];
      double sellBuffer[];
      
      ArraySetAsSeries(buyBuffer, true);
      ArraySetAsSeries(sellBuffer, true);
      
      // Buffer 4 là tín hiệu mua, buffer 5 là tín hiệu bán
      if(CopyBuffer(TC_Handle, 4, 0, 2, buyBuffer) > 0 && 
         CopyBuffer(TC_Handle, 5, 0, 2, sellBuffer) > 0)
      {
         // Kiểm tra nếu có tín hiệu mua
         if(buyBuffer[0] != EMPTY_VALUE)
         {
            buySignal = true;
            buySetupQuality = DetermineSetupQuality(true);
         }
         
         // Kiểm tra nếu có tín hiệu bán
         if(sellBuffer[0] != EMPTY_VALUE)
         {
            sellSignal = true;
            sellSetupQuality = DetermineSetupQuality(false);
         }
      }
   }
   else
   {
      // Nếu không có handle indicator, tính toán trực tiếp các chỉ báo
      
      // 1. VWAP
      double vwap = iCustom(_Symbol, PERIOD_CURRENT, "VWAP", VWAP_Period, 0);
      if(vwap == 0)  // Nếu không có indicator VWAP riêng
      {
         // Tính VWAP bằng cách sử dụng formula đơn giản
         double sumPV = 0, sumV = 0;
         for(int i = 0; i < VWAP_Period; i++)
         {
            double typicalPrice = (High[i] + Low[i] + Close[i]) / 3;
            double volume = Volume[i];
            sumPV += typicalPrice * volume;
            sumV += volume;
         }
         vwap = sumPV / (sumV > 0 ? sumV : 1);
      }
      
      // 2. RSI
      double rsi = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE, 0);
      
      // 3. Bollinger Bands
      double bbUpper = iBands(_Symbol, PERIOD_CURRENT, BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_UPPER, 0);
      double bbLower = iBands(_Symbol, PERIOD_CURRENT, BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_LOWER, 0);
      double bbMiddle = iBands(_Symbol, PERIOD_CURRENT, BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_MAIN, 0);
      
      // 4. OBV (On Balance Volume)
      double obv = iOBV(_Symbol, PERIOD_CURRENT, VOLUME_TICK, 0);
      double obvPrev = iOBV(_Symbol, PERIOD_CURRENT, VOLUME_TICK, 1);
      
      // 5. ATR cho SL/TP
      double atr = iATR(_Symbol, PERIOD_CURRENT, ATR_Period, 0);
      
      // --- Kiểm tra tín hiệu mua ---
      if(Close[0] < vwap && rsi < RSI_Oversold && Close[0] < bbLower && obv > obvPrev)
      {
         buySignal = true;
         
         // Đánh giá chất lượng setup
         int confirmationCount = 0;
         
         // VWAP xác nhận
         double vwapDistance = MathAbs(Close[0] - vwap) / atr;
         if(vwapDistance > 0.5) confirmationCount++;
         
         // RSI xác nhận mạnh
         if(rsi < 30) confirmationCount++;
         
         // BB xác nhận mạnh
         double bbDistance = MathAbs(Close[0] - bbLower) / atr;
         if(bbDistance > 0.3) confirmationCount++;
         
         // OBV xác nhận mạnh
         double obvChange = (obv - obvPrev) / (obvPrev != 0 ? obvPrev : 1) * 100;
         if(obvChange > 1.0) confirmationCount++;
         
         // Xếp loại setup
         if(confirmationCount >= 4)
            buySetupQuality = SETUP_QUALITY_A_PLUS;
         else if(confirmationCount == 3)
            buySetupQuality = SETUP_QUALITY_A;
         else
            buySetupQuality = SETUP_QUALITY_B;
      }
      
      // --- Kiểm tra tín hiệu bán ---
      if(Close[0] > vwap && rsi > RSI_Overbought && Close[0] > bbUpper && obv < obvPrev)
      {
         sellSignal = true;
         
         // Đánh giá chất lượng setup
         int confirmationCount = 0;
         
         // VWAP xác nhận
         double vwapDistance = MathAbs(Close[0] - vwap) / atr;
         if(vwapDistance > 0.5) confirmationCount++;
         
         // RSI xác nhận mạnh
         if(rsi > 70) confirmationCount++;
         
         // BB xác nhận mạnh
         double bbDistance = MathAbs(Close[0] - bbUpper) / atr;
         if(bbDistance > 0.3) confirmationCount++;
         
         // OBV xác nhận mạnh
         double obvChange = (obvPrev - obv) / (obvPrev != 0 ? obvPrev : 1) * 100;
         if(obvChange > 1.0) confirmationCount++;
         
         // Xếp loại setup
         if(confirmationCount >= 4)
            sellSetupQuality = SETUP_QUALITY_A_PLUS;
         else if(confirmationCount == 3)
            sellSetupQuality = SETUP_QUALITY_A;
         else
            sellSetupQuality = SETUP_QUALITY_B;
      }
   }
   
   // --- Thực hiện vào lệnh nếu có tín hiệu và đủ điều kiện ---
   
   // Điều chỉnh position size dựa trên chất lượng setup
   double positionSizeMultiplier = 1.0;
   
   if(Enable_Scaling_After_Loss && ConsecutiveLosses > 0)
   {
      positionSizeMultiplier *= MathPow(Scaling_Factor, ConsecutiveLosses);
      Journal.LogInfo("Giảm size do thua lỗ liên tiếp: " + IntegerToString(ConsecutiveLosses) + 
                     " lệnh, hệ số: " + DoubleToString(positionSizeMultiplier, 2));
   }
   
   // Chỉ giao dịch setup A+ và A
   if(buySignal && (buySetupQuality == SETUP_QUALITY_A_PLUS || buySetupQuality == SETUP_QUALITY_A))
   {
      double atr = iATR(_Symbol, PERIOD_CURRENT, ATR_Period, 0);
      
      // Tính stop loss và take profit
      double stopLoss = Close[0] - atr * SL_ATR_Multiplier;
      double takeProfit1 = Close[0] + atr * TP1_ATR_Multiplier;
      double takeProfit2 = Close[0] + atr * TP2_ATR_Multiplier;
      double takeProfit3 = Close[0] + atr * TP3_ATR_Multiplier;
      
      // Điều chỉnh position size theo chất lượng setup
      if(buySetupQuality == SETUP_QUALITY_A)
         positionSizeMultiplier *= 0.75;  // Giảm 25% cho setup A
      
      // Tính toán khối lượng giao dịch
      double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * Risk_Percent / 100.0 * positionSizeMultiplier;
      double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double stopLossPips = MathAbs(Close[0] - stopLoss) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double lotSize = NormalizeDouble(riskAmount / (stopLossPips * pointValue), 2);
      
      // Điều chỉnh theo ATR nếu cần
      if(Use_ATR_Adaptive_Sizing)
      {
         double atrBase = iATR(_Symbol, PERIOD_CURRENT, ATR_Base_Period, 0);
         double atrRatio = atrBase / atr;
         lotSize *= atrRatio;
         lotSize = NormalizeDouble(lotSize, 2);
      }
      
      // Kiểm tra min/max lot size
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
      
      // Thiết lập chi tiết trade để log
      STradeDetails tradeDetails;
      tradeDetails.symbol = _Symbol;
      tradeDetails.entryPrice = Close[0];
      tradeDetails.direction = TRADE_DIRECTION_BUY;
      tradeDetails.stopLoss = stopLoss;
      tradeDetails.takeProfit1 = takeProfit1;
      tradeDetails.takeProfit2 = takeProfit2;
      tradeDetails.takeProfit3 = takeProfit3;
      tradeDetails.riskReward = (takeProfit1 - Close[0]) / (Close[0] - stopLoss);
      tradeDetails.setupQuality = buySetupQuality;
      tradeDetails.marketCondition = MarketCondition;
      tradeDetails.lotSize = lotSize;
      tradeDetails.risk = Risk_Percent * positionSizeMultiplier;
      
      // Get indicators value for log
      tradeDetails.RSI = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE, 0);
      double vwap = iCustom(_Symbol, PERIOD_CURRENT, "VWAP", VWAP_Period, 0);
      tradeDetails.VWAP_Distance = MathAbs(Close[0] - vwap) / atr;
      double bbLower = iBands(_Symbol, PERIOD_CURRENT, BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_LOWER, 0);
      tradeDetails.BB_Distance = MathAbs(Close[0] - bbLower) / atr;
      tradeDetails.OBV = iOBV(_Symbol, PERIOD_CURRENT, VOLUME_TICK, 0);
      tradeDetails.ATR = atr;
      
      // Log chi tiết trước khi vào lệnh
      Journal.LogTradeSetup(tradeDetails);
      
      // Thực hiện vào lệnh mua
      bool tradeResult = TradeManager.OpenTrade(ORDER_TYPE_BUY, lotSize, stopLoss, takeProfit1, 
                                              TP1_Percent, TP2_Percent, TP3_Percent,
                                              takeProfit2, takeProfit3);
      
      // Log kết quả vào lệnh
      if(tradeResult)
      {
         Journal.LogTradeEntry(tradeDetails);
         
         // Cập nhật panel
         EAPanel.UpdateLastSignal("BUY", buySetupQuality);
         UpdatePanels();
      }
      else
      {
         Journal.LogError("Vào lệnh BUY thất bại: " + Trade.ResultRetcodeDescription());
      }
   }
   
   // Tương tự cho tín hiệu bán
   else if(sellSignal && (sellSetupQuality == SETUP_QUALITY_A_PLUS || sellSetupQuality == SETUP_QUALITY_A))
   {
      double atr = iATR(_Symbol, PERIOD_CURRENT, ATR_Period, 0);
      
      // Tính stop loss và take profit
      double stopLoss = Close[0] + atr * SL_ATR_Multiplier;
      double takeProfit1 = Close[0] - atr * TP1_ATR_Multiplier;
      double takeProfit2 = Close[0] - atr * TP2_ATR_Multiplier;
      double takeProfit3 = Close[0] - atr * TP3_ATR_Multiplier;
      
      // Điều chỉnh position size theo chất lượng setup
      if(sellSetupQuality == SETUP_QUALITY_A)
         positionSizeMultiplier *= 0.75;  // Giảm 25% cho setup A
      
      // Tính toán khối lượng giao dịch
      double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * Risk_Percent / 100.0 * positionSizeMultiplier;
      double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double stopLossPips = MathAbs(Close[0] - stopLoss) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double lotSize = NormalizeDouble(riskAmount / (stopLossPips * pointValue), 2);
      
      // Điều chỉnh theo ATR nếu cần
      if(Use_ATR_Adaptive_Sizing)
      {
         double atrBase = iATR(_Symbol, PERIOD_CURRENT, ATR_Base_Period, 0);
         double atrRatio = atrBase / atr;
         lotSize *= atrRatio;
         lotSize = NormalizeDouble(lotSize, 2);
      }
      
      // Kiểm tra min/max lot size
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
      
      // Thiết lập chi tiết trade để log
      STradeDetails tradeDetails;
      tradeDetails.symbol = _Symbol;
      tradeDetails.entryPrice = Close[0];
      tradeDetails.direction = TRADE_DIRECTION_SELL;
      tradeDetails.stopLoss = stopLoss;
      tradeDetails.takeProfit1 = takeProfit1;
      tradeDetails.takeProfit2 = takeProfit2;
      tradeDetails.takeProfit3 = takeProfit3;
      tradeDetails.riskReward = (Close[0] - takeProfit1) / (stopLoss - Close[0]);
      tradeDetails.setupQuality = sellSetupQuality;
      tradeDetails.marketCondition = MarketCondition;
      tradeDetails.lotSize = lotSize;
      tradeDetails.risk = Risk_Percent * positionSizeMultiplier;
      
      // Get indicators value for log
      tradeDetails.RSI = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE, 0);
      double vwap = iCustom(_Symbol, PERIOD_CURRENT, "VWAP", VWAP_Period, 0);
      tradeDetails.VWAP_Distance = MathAbs(Close[0] - vwap) / atr;
      double bbUpper = iBands(_Symbol, PERIOD_CURRENT, BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_UPPER, 0);
      tradeDetails.BB_Distance = MathAbs(Close[0] - bbUpper) / atr;
      tradeDetails.OBV = iOBV(_Symbol, PERIOD_CURRENT, VOLUME_TICK, 0);
      tradeDetails.ATR = atr;
      
      // Log chi tiết trước khi vào lệnh
      Journal.LogTradeSetup(tradeDetails);
      
      // Thực hiện vào lệnh bán
      bool tradeResult = TradeManager.OpenTrade(ORDER_TYPE_SELL, lotSize, stopLoss, takeProfit1, 
                                               TP1_Percent, TP2_Percent, TP3_Percent,
                                               takeProfit2, takeProfit3);
      
      // Log kết quả vào lệnh
      if(tradeResult)
      {
         Journal.LogTradeEntry(tradeDetails);
         
         // Cập nhật panel
         EAPanel.UpdateLastSignal("SELL", sellSetupQuality);
         UpdatePanels();
      }
      else
      {
         Journal.LogError("Vào lệnh SELL thất bại: " + Trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//| Xác định chất lượng setup từ indicator hoặc phân tích kỹ thuật  |
//+------------------------------------------------------------------+
ENUM_SETUP_QUALITY DetermineSetupQuality(bool isBuy)
{
   // Xác định chất lượng dựa trên phân tích kỹ thuật
   // Càng nhiều confirmation, càng cao chất lượng
   
   // 1. RSI
   double rsi = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE, 0);
   
   // 2. VWAP
   double vwap = iCustom(_Symbol, PERIOD_CURRENT, "VWAP", VWAP_Period, 0);
   if(vwap == 0) // Fallback nếu không có indicator
   {
      vwap = Close[0]; // Giá trị mặc định
   }
   
   // 3. BB
   double bbUpper = iBands(_Symbol, PERIOD_CURRENT, BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_UPPER, 0);
   double bbLower = iBands(_Symbol, PERIOD_CURRENT, BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_LOWER, 0);
   
   // 4. OBV
   double obv = iOBV(_Symbol, PERIOD_CURRENT, VOLUME_TICK, 0);
   double obvPrev = iOBV(_Symbol, PERIOD_CURRENT, VOLUME_TICK, 1);
   
   // 5. ATR
   double atr = iATR(_Symbol, PERIOD_CURRENT, ATR_Period, 0);
   
   int confirmationCount = 0;
   
   if(isBuy) 
   {
      // VWAP xác nhận
      double vwapDistance = MathAbs(Close[0] - vwap) / atr;
      if(vwapDistance > 0.5) confirmationCount++;
      
      // RSI xác nhận mạnh
      if(rsi < 30) confirmationCount++;
      
      // BB xác nhận mạnh
      double bbDistance = MathAbs(Close[0] - bbLower) / atr;
      if(bbDistance > 0.3) confirmationCount++;
      
      // OBV xác nhận mạnh
      double obvChange = (obv - obvPrev) / (obvPrev != 0 ? obvPrev : 1) * 100;
      if(obvChange > 1.0) confirmationCount++;
   }
   else // Sell
   {
      // VWAP xác nhận
      double vwapDistance = MathAbs(Close[0] - vwap) / atr;
      if(vwapDistance > 0.5) confirmationCount++;
      
      // RSI xác nhận mạnh
      if(rsi > 70) confirmationCount++;
      
      // BB xác nhận mạnh
      double bbDistance = MathAbs(Close[0] - bbUpper) / atr;
      if(bbDistance > 0.3) confirmationCount++;
      
      // OBV xác nhận mạnh
      double obvChange = (obvPrev - obv) / (obvPrev != 0 ? obvPrev : 1) * 100;
      if(obvChange > 1.0) confirmationCount++;
   }
   
   // Xếp loại setup
   if(confirmationCount >= 4)
      return SETUP_QUALITY_A_PLUS;
   else if(confirmationCount == 3)
      return SETUP_QUALITY_A;
   else
      return SETUP_QUALITY_B;
}

//+------------------------------------------------------------------+
//| Cập nhật các panel hiển thị                                     |
//+------------------------------------------------------------------+
void UpdatePanels()
{
   // Cập nhật thông tin tài khoản
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double profit = equity - balance;
   
   // Lấy thông tin hiệu suất từ EdgeCalc
   SPerformanceStats performance = EdgeCalc.GetCurrentPerformance();
   
   // Cập nhật dashboard tổng quan
   MainDashboard.Update(balance, equity, profit, performance.winRate,
                       performance.expectancy, performance.profitFactor);
   
   // Cập nhật panel chi tiết EA
   EAPanel.Update(EA_Name, MarketCondition, performance.winRate, 
                 performance.avgWin, performance.avgLoss, performance.expectancy, 
                 performance.maxDrawdown, ConsecutiveLosses);
}

//+------------------------------------------------------------------+
//| Xử lý khi có thông báo trade                                   |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
   // Chuyển cho TradeManager xử lý
   TradeManager.OnTradeTransaction(trans, request, result);
   
   // Cập nhật thông tin thua lỗ liên tiếp
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      // Lấy thông tin giao dịch
      ulong dealTicket = trans.deal;
      if(dealTicket == 0)
         return;
         
      HistorySelect(0, TimeCurrent());
      
      if(HistoryDealSelect(dealTicket))
      {
         // Kiểm tra nếu là giao dịch đóng lệnh
         if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            // Kiểm tra kết quả
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            if(profit < 0)
            {
               ConsecutiveLosses++;
               Journal.LogInfo("Thua lỗ lệnh thứ " + IntegerToString(ConsecutiveLosses) + " liên tiếp");
            }
            else if(profit > 0)
            {
               ConsecutiveLosses = 0;
               Journal.LogInfo("Reset chuỗi thua lỗ sau lệnh thắng");
            }
            
            // Log chi tiết kết quả giao dịch
            STradeResult tradeResult;
            tradeResult.ticket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
            tradeResult.symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
            tradeResult.profit = profit;
            
            // Tính pips
            double openPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            double pips = MathAbs(openPrice - closePrice) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            tradeResult.pips = pips;
            
            // Tính thời gian giữ lệnh
            datetime openTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
            datetime closeTime = TimeCurrent();
            tradeResult.duration = (int)((closeTime - openTime) / 60); // phút
            
            // Xác định lý do đóng lệnh
            ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(dealTicket, DEAL_REASON);
            if(reason == DEAL_REASON_SL)
               tradeResult.exitReason = "Stop Loss";
            else if(reason == DEAL_REASON_TP)
               tradeResult.exitReason = "Take Profit";
            else if(reason == DEAL_REASON_CLIENT)
               tradeResult.exitReason = "Manual Close";
            else
               tradeResult.exitReason = "Other";
            
            Journal.LogTradeResult(tradeResult);
            
            // Cập nhật Edge Calculator
            EdgeCalc.AddTradeResult(tradeResult);
            
            // Kiểm tra suy giảm Edge sau mỗi 30 giao dịch
            if(EdgeCalc.GetTotalTrades() % 30 == 0)
            {
               SEdgeDegradation edgeDegradation = EdgeCalc.CheckEdgeDegradation();
               if(edgeDegradation.hasDegradation)
               {
                  Journal.LogWarning("Phát hiện suy giảm Edge: " + edgeDegradation.message);
               }
            }
            
            // Cập nhật panel
            UpdatePanels();
         }
      }
   }
}