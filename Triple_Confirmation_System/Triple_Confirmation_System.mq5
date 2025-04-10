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
#include "..\\Data\\ConfigManager.mqh"
#include "..\\Include\\NewsManager.mqh"
#include "..\\Include\\TradeJournal.mqh"
#include "..\\Include\\Dashboard.mqh"
#include "..\\Include\\TripleConfirmPanel.mqh"
#include "..\\Include\\EdgeCalculator.mqh"
#include "..\\Include\\EdgeTracker.mqh"
#include "..\\Include\\EdgeDisplay.mqh"
#include "..\\Include\\TradeManager.mqh"
#include "..\\Include\\RiskCalculator.mqh"
#include "..\\Include\\CommonDefinitions.mqh"
#include "..\\Include\\TripleConfirmEdgeTracker.mqh"

// Định nghĩa các hằng số nếu chưa được định nghĩa
#ifndef MODE_UPPER
#define MODE_UPPER 1  // Band thượng của Bollinger Bands
#endif

#ifndef MODE_LOWER
#define MODE_LOWER 2  // Band dưới của Bollinger Bands
#endif

#ifndef MODE_MAIN
#define MODE_MAIN 0   // Đường trung tâm của Bollinger Bands hoặc đường chính của indicator
#endif

// Khởi tạo các đối tượng
CTrade         Trade;            // Đối tượng giao dịch
CConfigManager ConfigManager;    // Quản lý cấu hình
CNewsManager   NewsManager;      // Quản lý tin tức
CTradeJournal  Journal;          // Nhật ký giao dịch
CTripleConfirmPanel DashboardPanel;  // Dashboard mới
CTripleConfirmEdgeTracker EdgeTracker; // Edge Tracker mới
CEdgeDisplay   EdgePanel;         // Panel hiển thị Edge
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
input int      RSI_Period = 14;                   // Chu kỳ RSI
input double   RSI_Upper = 70;            // Ngưỡng quá mua RSI
input double   RSI_Lower = 30;            // Ngưỡng quá bán RSI
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
input string   ConfigDirectory = "..\\Data";         // Thư mục cấu hình

// Biến toàn cục
bool           IsNewBar = false;
datetime       LastBarTime = 0;
int            ConsecutiveLosses = 0;
ENUM_MARKET_CONDITION MarketCondition = MARKET_CONDITION_UNDEFINED;

// Handle cho indicator Triple Confirmation
int            TC_Handle = INVALID_HANDLE;

// Biến lưu trữ handle indicator
int rsiHandle = INVALID_HANDLE;
int bbHandle = INVALID_HANDLE;
int obvHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;

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
   TC_Handle = iCustom(_Symbol, PERIOD_CURRENT, "Indicators\\TripleConfirmationIndicator", 
                      VWAP_Period, RSI_Period, RSI_Lower, RSI_Upper, 
                      BB_Period, BB_Deviation, ATR_Period, false);
   
   if(TC_Handle == INVALID_HANDLE)
   {
      int error = GetLastError();
      Print("Lỗi khi tạo Triple Confirmation Indicator handle: ", error);
      // Xử lý lỗi
      return INIT_FAILED;
   }
   Print("Triple Confirmation Indicator handle tạo thành công: ", TC_Handle);
   Journal.LogInfo("Triple Confirmation Indicator đã được khởi tạo thành công");
   
   // Khởi tạo các module
   if(!NewsManager.Init(Enable_News_Filter))
   {
      Print("Không thể khởi tạo NewsManager. Lỗi: ", GetLastError());
      return INIT_FAILED;
   }
   
   // Tải dữ liệu tin tức ngay khi khởi động
   if(Enable_News_Filter && !NewsManager.UpdateNewsData())
   {
      Print("Cảnh báo: Không thể tải dữ liệu tin tức. Vui lòng kiểm tra kết nối internet và cài đặt WebRequest.");
      Print("Bạn có thể cần bật quyền WebRequest trong Tools -> Options -> Expert Advisors.");
   }
   
   if(!Journal.Init(Log_Directory, EA_Name, Enable_Detailed_Logging))
      return INIT_FAILED;
   
   // Khởi tạo Dashboard Panel mới
   if(!DashboardPanel.Init(EA_Name, 10, 10)) // Vị trí góc trên bên trái
      return INIT_FAILED;
   
   // Khởi tạo Edge Tracker mới
   if(!EdgeTracker.Init(EA_Name))
      return INIT_FAILED;
      
   // Khởi tạo Edge Panel mới
   if(!EdgePanel.Init(&EdgeTracker, (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - 210, 10)) // Vị trí góc trên bên phải
      return INIT_FAILED;
   
   if(!TradeManager.Init(&Trade, Magic_Number))
      return INIT_FAILED;
   
   if(!RiskCalc.Init(Risk_Percent, Use_ATR_Adaptive_Sizing))
      return INIT_FAILED;
      
   // Thiết lập ADX parameter cho Edge Tracker
   EdgeTracker.SetADXParameters(ADX_Period, ADX_Trending_Threshold);
      
   // Ghi log khởi động EA
   Journal.LogInfo("EA Triple Confirmation khởi động. Phiên bản: 1.00");
   Journal.LogInfo("Cấu hình từ file: " + (UseConfigFile ? "Bật" : "Tắt"));
   Journal.LogInfo("Bộ lọc tin tức: " + (Enable_News_Filter ? "Bật" : "Tắt"));
   Journal.LogEAStart();
   
   // Cập nhật panel
   UpdatePanels();
   
   // Khởi tạo các handle indicator
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   bbHandle = iBands(_Symbol, PERIOD_CURRENT, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
   obvHandle = iOBV(_Symbol, PERIOD_CURRENT, VOLUME_TICK);
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   
   // Kiểm tra các handle
   if(rsiHandle == INVALID_HANDLE || bbHandle == INVALID_HANDLE || 
      obvHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
   {
      Print("Không thể tạo handle cho một số indicator. Lỗi: ", GetLastError());
      return INIT_FAILED;
   }
   
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
   // Dọn dẹp các module Dashboard và EdgeTracking mới
   DashboardPanel.Deinit();
   EdgeTracker.Deinit();
   EdgePanel.Deinit();
   TradeManager.Deinit();
   RiskCalc.Deinit();
   
   // Giải phóng các handle indicator
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(bbHandle != INVALID_HANDLE) IndicatorRelease(bbHandle);
   if(obvHandle != INVALID_HANDLE) IndicatorRelease(obvHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
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
      // Nếu đang có tin tức quan trọng cho cặp tiền hiện tại, bỏ qua
      if(NewsManager.IsHighImpactNewsForSymbol(_Symbol))
      {
         Journal.LogInfo("Đang có tin tức quan trọng cho " + _Symbol + ", bỏ qua tìm kiếm tín hiệu");
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
   // Lấy điều kiện thị trường từ EdgeTracker
   MarketCondition = EdgeTracker.GetMarketCondition();
      
   // Cập nhật vào Dashboard
   DashboardPanel.UpdateMarketCondition(MarketCondition);
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
      double atrBuffer[];  // Thêm buffer để lấy ATR từ indicator
      
      ArraySetAsSeries(buyBuffer, true);
      ArraySetAsSeries(sellBuffer, true);
      ArraySetAsSeries(atrBuffer, true);  // Đặt chế độ series cho atrBuffer
      
      // Buffer 4 là tín hiệu mua, buffer 5 là tín hiệu bán, buffer 8 là ATR trong indicator mới
      if(CopyBuffer(TC_Handle, 4, 0, 2, buyBuffer) > 0 && 
         CopyBuffer(TC_Handle, 5, 0, 2, sellBuffer) > 0 &&
         CopyBuffer(TC_Handle, 8, 0, 1, atrBuffer) > 0)  // Copy ATR từ buffer 8
      {
         // Kiểm tra nếu có tín hiệu mua
         if(buyBuffer[0] != EMPTY_VALUE)
         {
            buySignal = true;
            buySetupQuality = DetermineSetupQuality(true);
            Journal.LogInfo("Phát hiện tín hiệu MUA từ Triple Confirmation Indicator");
         }
         
         // Kiểm tra nếu có tín hiệu bán
         if(sellBuffer[0] != EMPTY_VALUE)
         {
            sellSignal = true;
            sellSetupQuality = DetermineSetupQuality(false);
            Journal.LogInfo("Phát hiện tín hiệu BÁN từ Triple Confirmation Indicator");
         }
         
         // Sử dụng ATR từ indicator cho các tính toán sau này
         double atr = atrBuffer[0];
         
         // Khi sử dụng ATR từ indicator, cập nhật biến atr cho các tính toán SL/TP
         if(atr > 0)
         {
            Journal.LogInfo("Sử dụng ATR từ indicator: " + DoubleToString(atr, 5));
         }
         else
         {
            // Fallback nếu không lấy được ATR từ indicator
            double buffer[];
            ArraySetAsSeries(buffer, true);
            if(CopyBuffer(atrHandle, 0, 0, 1, buffer) > 0)
               atr = buffer[0];
            else {
               Print("Không thể copy dữ liệu ATR. Lỗi: ", GetLastError());
               return;
            }
         }
      }
      else
      {
         // Xử lý lỗi khi không thể copy buffer
         int error = GetLastError();
         Print("Không thể copy buffer từ indicator. Lỗi: ", error);
         Journal.LogError("Copy buffer thất bại: " + IntegerToString(error));
      }
   }
   else
   {
      // Nếu không có handle indicator, tính toán trực tiếp các chỉ báo
      
      // 1. VWAP
      double vwap = iCustom(_Symbol, PERIOD_CURRENT, "..\\Indicators\\VWAP", VWAP_Period, 0);
      if(vwap == 0)  // Nếu không có indicator VWAP riêng
      {
         // Tính VWAP bằng cách sử dụng formula đơn giản
         double sumPV = 0, sumV = 0;
         for(int i = 0; i < VWAP_Period; i++)
         {
            double typicalPrice = (iHigh(_Symbol, PERIOD_CURRENT, i) + 
                                  iLow(_Symbol, PERIOD_CURRENT, i) + 
                                  iClose(_Symbol, PERIOD_CURRENT, i)) / 3;
            double volume = (double)iVolume(_Symbol, PERIOD_CURRENT, i);
            sumPV += typicalPrice * volume;
            sumV += volume;
         }
         vwap = sumPV / (sumV > 0 ? sumV : 1);
      }
      
      // 2. RSI
      double rsiBuffer[];
      ArraySetAsSeries(rsiBuffer, true);
      int copied = CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer);
      if(copied <= 0) {
         Print("Không thể copy dữ liệu RSI. Lỗi: ", GetLastError());
         return;
      }
      double rsi = rsiBuffer[0]; // Giá trị RSI mới nhất
      
      // 3. Bollinger Bands
      double upperBuffer[], middleBuffer[], lowerBuffer[];
      ArraySetAsSeries(upperBuffer, true);
      ArraySetAsSeries(middleBuffer, true);
      ArraySetAsSeries(lowerBuffer, true);
      
      copied = CopyBuffer(bbHandle, MODE_UPPER, 0, 3, upperBuffer);
      if(copied <= 0) {
         Print("Không thể copy dữ liệu BB Upper. Lỗi: ", GetLastError());
         return;
      }
      
      copied = CopyBuffer(bbHandle, MODE_MAIN, 0, 3, middleBuffer);
      if(copied <= 0) {
         Print("Không thể copy dữ liệu BB Main. Lỗi: ", GetLastError());
         return;
      }
      
      copied = CopyBuffer(bbHandle, MODE_LOWER, 0, 3, lowerBuffer);
      if(copied <= 0) {
         Print("Không thể copy dữ liệu BB Lower. Lỗi: ", GetLastError());
         return;
      }
      
      double bbUpper = upperBuffer[0];
      double bbMiddle = middleBuffer[0];
      double bbLower = lowerBuffer[0];
      
      // 4. OBV (On Balance Volume)
      double obvBuffer[];
      ArraySetAsSeries(obvBuffer, true);
      copied = CopyBuffer(obvHandle, 0, 0, 3, obvBuffer);
      if(copied <= 0) {
         Print("Không thể copy dữ liệu OBV. Lỗi: ", GetLastError());
         return;
      }
      double obv = obvBuffer[0];
      double obvPrev = obvBuffer[1];
      
      // 5. ATR cho SL/TP
      double atrBuffer[];
      ArraySetAsSeries(atrBuffer, true);
      copied = CopyBuffer(atrHandle, 0, 0, 3, atrBuffer);
      if(copied <= 0) {
         Print("Không thể copy dữ liệu ATR. Lỗi: ", GetLastError());
         return;
      }
      double atr = atrBuffer[0];
      
      // Lấy giá đóng cửa hiện tại
      double currentClose = iClose(_Symbol, PERIOD_CURRENT, 0);
      
      // --- Kiểm tra tín hiệu mua ---
      if(currentClose < vwap && rsi < RSI_Lower && currentClose < bbLower && obv > obvPrev)
      {
         buySignal = true;
         
         // Đánh giá chất lượng setup
         int confirmationCount = 0;
         
         // VWAP xác nhận
         double vwapDistance = MathAbs(currentClose - vwap) / atr;
         if(vwapDistance > 0.5) confirmationCount++;
         
         // RSI xác nhận mạnh
         if(rsi < 30) confirmationCount++;
         
         // BB xác nhận mạnh
         double bbDistance = MathAbs(currentClose - bbLower) / atr;
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
      if(currentClose > vwap && rsi > RSI_Upper && currentClose > bbUpper && obv < obvPrev)
      {
         sellSignal = true;
         
         // Đánh giá chất lượng setup
         int confirmationCount = 0;
         
         // VWAP xác nhận
         double vwapDistance = MathAbs(currentClose - vwap) / atr;
         if(vwapDistance > 0.5) confirmationCount++;
         
         // RSI xác nhận mạnh
         if(rsi > 70) confirmationCount++;
         
         // BB xác nhận mạnh
         double bbDistance = MathAbs(currentClose - bbUpper) / atr;
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
   
   // Lấy giá đóng cửa hiện tại
   double currentClose = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   // Chỉ giao dịch setup A+ và A
   if(buySignal && (buySetupQuality == SETUP_QUALITY_A_PLUS || buySetupQuality == SETUP_QUALITY_A))
   {
      // Lấy giá trị ATR
      double atr = 0;
      {
         double buffer[];
         ArraySetAsSeries(buffer, true);
         if(CopyBuffer(atrHandle, 0, 0, 1, buffer) > 0)
            atr = buffer[0];
         else {
            Print("Không thể copy dữ liệu ATR cho BUY signal. Lỗi: ", GetLastError());
            return;
         }
      }
      
      // Tính stop loss và take profit
      double stopLoss = currentClose - atr * SL_ATR_Multiplier;
      double takeProfit1 = currentClose + atr * TP1_ATR_Multiplier;
      double takeProfit2 = currentClose + atr * TP2_ATR_Multiplier;
      double takeProfit3 = currentClose + atr * TP3_ATR_Multiplier;
      
      // Điều chỉnh position size theo chất lượng setup
      if(buySetupQuality == SETUP_QUALITY_A)
         positionSizeMultiplier *= 0.75;  // Giảm 25% cho setup A
      
      // Tính toán khối lượng giao dịch
      double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * Risk_Percent / 100.0 * positionSizeMultiplier;
      double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double stopLossPips = MathAbs(currentClose - stopLoss) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double lotSize = NormalizeDouble(riskAmount / (stopLossPips * pointValue), 2);
      
      // Điều chỉnh theo ATR nếu cần
      if(Use_ATR_Adaptive_Sizing)
      {
         // Lấy ATR cơ sở
         double atrBase = 0;
         int atrBaseHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_Base_Period);
         if(atrBaseHandle != INVALID_HANDLE)
         {
            double baseBuffer[];
            ArraySetAsSeries(baseBuffer, true);
            if(CopyBuffer(atrBaseHandle, 0, 0, 1, baseBuffer) > 0)
               atrBase = baseBuffer[0];
            IndicatorRelease(atrBaseHandle);
            
            double atrRatio = atrBase / atr;
            lotSize *= atrRatio;
            lotSize = NormalizeDouble(lotSize, 2);
         }
      }
      
      // Kiểm tra min/max lot size
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
      
      // Thiết lập chi tiết trade để log
      STradeDetails tradeDetails;
      tradeDetails.symbol = _Symbol;
      tradeDetails.entryPrice = currentClose;
      tradeDetails.direction = TRADE_DIRECTION_BUY;
      tradeDetails.stopLoss = stopLoss;
      tradeDetails.takeProfit1 = takeProfit1;
      tradeDetails.takeProfit2 = takeProfit2;
      tradeDetails.takeProfit3 = takeProfit3;
      tradeDetails.riskReward = (takeProfit1 - currentClose) / (currentClose - stopLoss);
      tradeDetails.setupQuality = buySetupQuality;
      tradeDetails.marketCondition = MarketCondition;
      tradeDetails.lotSize = lotSize;
      tradeDetails.risk = Risk_Percent * positionSizeMultiplier;
      
      // Get indicators value for log
      {
         // RSI
         double rsiBuffer[];
         ArraySetAsSeries(rsiBuffer, true);
         if(CopyBuffer(rsiHandle, 0, 0, 1, rsiBuffer) > 0)
            tradeDetails.RSI = rsiBuffer[0];
         
         // VWAP
         double vwap = 0;
         int vwapHandle = iCustom(_Symbol, PERIOD_CURRENT, "..\\Indicators\\VWAP", VWAP_Period);
         if(vwapHandle != INVALID_HANDLE)
         {
            double vwapBuffer[];
            ArraySetAsSeries(vwapBuffer, true);
            if(CopyBuffer(vwapHandle, 0, 0, 1, vwapBuffer) > 0)
               vwap = vwapBuffer[0];
            IndicatorRelease(vwapHandle);
            tradeDetails.VWAP_Distance = MathAbs(currentClose - vwap) / atr;
         }
         
         // Bollinger Bands
         double bbLowerBuffer[];
         ArraySetAsSeries(bbLowerBuffer, true);
         if(CopyBuffer(bbHandle, MODE_LOWER, 0, 1, bbLowerBuffer) > 0)
         {
            double bbLower = bbLowerBuffer[0];
            tradeDetails.BB_Distance = MathAbs(currentClose - bbLower) / atr;
         }
         
         // OBV
         double obvBuffer[];
         ArraySetAsSeries(obvBuffer, true);
         if(CopyBuffer(obvHandle, 0, 0, 1, obvBuffer) > 0)
            tradeDetails.OBV = obvBuffer[0];
         
         tradeDetails.ATR = atr;
      }
      
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
         EdgePanel.UpdateLastSignal("BUY", buySetupQuality);
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
      // Lấy giá trị ATR
      double atr = 0;
      {
         double buffer[];
         ArraySetAsSeries(buffer, true);
         if(CopyBuffer(atrHandle, 0, 0, 1, buffer) > 0)
            atr = buffer[0];
         else {
            Print("Không thể copy dữ liệu ATR cho SELL signal. Lỗi: ", GetLastError());
            return;
         }
      }
      
      // Tính stop loss và take profit
      double stopLoss = currentClose + atr * SL_ATR_Multiplier;
      double takeProfit1 = currentClose - atr * TP1_ATR_Multiplier;
      double takeProfit2 = currentClose - atr * TP2_ATR_Multiplier;
      double takeProfit3 = currentClose - atr * TP3_ATR_Multiplier;
      
      // Điều chỉnh position size theo chất lượng setup
      if(sellSetupQuality == SETUP_QUALITY_A)
         positionSizeMultiplier *= 0.75;  // Giảm 25% cho setup A
      
      // Tính toán khối lượng giao dịch
      double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * Risk_Percent / 100.0 * positionSizeMultiplier;
      double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double stopLossPips = MathAbs(currentClose - stopLoss) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double lotSize = NormalizeDouble(riskAmount / (stopLossPips * pointValue), 2);
      
      // Điều chỉnh theo ATR nếu cần
      if(Use_ATR_Adaptive_Sizing)
      {
         // Lấy ATR cơ sở
         double atrBase = 0;
         int atrBaseHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_Base_Period);
         if(atrBaseHandle != INVALID_HANDLE)
         {
            double baseBuffer[];
            ArraySetAsSeries(baseBuffer, true);
            if(CopyBuffer(atrBaseHandle, 0, 0, 1, baseBuffer) > 0)
               atrBase = baseBuffer[0];
            IndicatorRelease(atrBaseHandle);
            
            double atrRatio = atrBase / atr;
            lotSize *= atrRatio;
            lotSize = NormalizeDouble(lotSize, 2);
         }
      }
      
      // Kiểm tra min/max lot size
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
      
      // Thiết lập chi tiết trade để log
      STradeDetails tradeDetails;
      tradeDetails.symbol = _Symbol;
      tradeDetails.entryPrice = currentClose;
      tradeDetails.direction = TRADE_DIRECTION_SELL;
      tradeDetails.stopLoss = stopLoss;
      tradeDetails.takeProfit1 = takeProfit1;
      tradeDetails.takeProfit2 = takeProfit2;
      tradeDetails.takeProfit3 = takeProfit3;
      tradeDetails.riskReward = (currentClose - takeProfit1) / (stopLoss - currentClose);
      tradeDetails.setupQuality = sellSetupQuality;
      tradeDetails.marketCondition = MarketCondition;
      tradeDetails.lotSize = lotSize;
      tradeDetails.risk = Risk_Percent * positionSizeMultiplier;
      
      // Get indicators value for log
      {
         // RSI
         double rsiBuffer[];
         ArraySetAsSeries(rsiBuffer, true);
         if(CopyBuffer(rsiHandle, 0, 0, 1, rsiBuffer) > 0)
            tradeDetails.RSI = rsiBuffer[0];
         
         // VWAP
         double vwap = 0;
         int vwapHandle = iCustom(_Symbol, PERIOD_CURRENT, "..\\Indicators\\VWAP", VWAP_Period);
         if(vwapHandle != INVALID_HANDLE)
         {
            double vwapBuffer[];
            ArraySetAsSeries(vwapBuffer, true);
            if(CopyBuffer(vwapHandle, 0, 0, 1, vwapBuffer) > 0)
               vwap = vwapBuffer[0];
            IndicatorRelease(vwapHandle);
            tradeDetails.VWAP_Distance = MathAbs(currentClose - vwap) / atr;
         }
         
         // Bollinger Bands
         double bbUpperBuffer[];
         ArraySetAsSeries(bbUpperBuffer, true);
         if(CopyBuffer(bbHandle, MODE_UPPER, 0, 1, bbUpperBuffer) > 0)
         {
            double bbUpper = bbUpperBuffer[0];
            tradeDetails.BB_Distance = MathAbs(currentClose - bbUpper) / atr;
         }
         
         // OBV
         double obvBuffer[];
         ArraySetAsSeries(obvBuffer, true);
         if(CopyBuffer(obvHandle, 0, 0, 1, obvBuffer) > 0)
            tradeDetails.OBV = obvBuffer[0];
         
         tradeDetails.ATR = atr;
      }
      
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
         EdgePanel.UpdateLastSignal("SELL", sellSetupQuality);
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
   double rsi = 0;
   {
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(rsiHandle, 0, 0, 1, buffer) > 0)
         rsi = buffer[0];
      else {
         Print("Không thể copy dữ liệu RSI trong DetermineSetupQuality. Lỗi: ", GetLastError());
         return SETUP_QUALITY_NONE;
      }
   }
   
   // 2. VWAP
   double vwap = 0;
   int vwapHandle = iCustom(_Symbol, PERIOD_CURRENT, "..\\Indicators\\VWAP", VWAP_Period);
   if(vwapHandle != INVALID_HANDLE)
   {
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(vwapHandle, 0, 0, 1, buffer) > 0)
         vwap = buffer[0];
      IndicatorRelease(vwapHandle);
   }
   
   if(vwap == 0) // Fallback nếu không có indicator
   {
      vwap = iClose(_Symbol, PERIOD_CURRENT, 0); // Giá trị mặc định
   }
   
   // 3. BB
   double bbUpper = 0, bbLower = 0;
   {
      double upperBuffer[], lowerBuffer[];
      ArraySetAsSeries(upperBuffer, true);
      ArraySetAsSeries(lowerBuffer, true);
      
      if(CopyBuffer(bbHandle, MODE_UPPER, 0, 1, upperBuffer) > 0)
         bbUpper = upperBuffer[0];
      else {
         Print("Không thể copy dữ liệu BB Upper trong DetermineSetupQuality. Lỗi: ", GetLastError());
         return SETUP_QUALITY_NONE;
      }
      
      if(CopyBuffer(bbHandle, MODE_LOWER, 0, 1, lowerBuffer) > 0)
         bbLower = lowerBuffer[0];
      else {
         Print("Không thể copy dữ liệu BB Lower trong DetermineSetupQuality. Lỗi: ", GetLastError());
         return SETUP_QUALITY_NONE;
      }
   }
   
   // 4. OBV
   double obv = 0, obvPrev = 0;
   {
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(obvHandle, 0, 0, 2, buffer) > 0) {
         obv = buffer[0];
         obvPrev = buffer[1];
      }
      else {
         Print("Không thể copy dữ liệu OBV trong DetermineSetupQuality. Lỗi: ", GetLastError());
         return SETUP_QUALITY_NONE;
      }
   }
   
   // 5. ATR
   double atr = 0;
   {
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, buffer) > 0)
         atr = buffer[0];
      else {
         Print("Không thể copy dữ liệu ATR trong DetermineSetupQuality. Lỗi: ", GetLastError());
         return SETUP_QUALITY_NONE;
      }
   }
   
   // Lấy giá đóng cửa hiện tại
   double currentClose = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   int confirmationCount = 0;
   
   if(isBuy) 
   {
      // VWAP xác nhận
      double vwapDistance = MathAbs(currentClose - vwap) / atr;
      if(vwapDistance > 0.5) confirmationCount++;
      
      // RSI xác nhận mạnh
      if(rsi < 30) confirmationCount++;
      
      // BB xác nhận mạnh
      double bbDistance = MathAbs(currentClose - bbLower) / atr;
      if(bbDistance > 0.3) confirmationCount++;
      
      // OBV xác nhận mạnh
      double obvChange = (obv - obvPrev) / (obvPrev != 0 ? obvPrev : 1) * 100;
      if(obvChange > 1.0) confirmationCount++;
   }
   else // Sell
   {
      // VWAP xác nhận
      double vwapDistance = MathAbs(currentClose - vwap) / atr;
      if(vwapDistance > 0.5) confirmationCount++;
      
      // RSI xác nhận mạnh
      if(rsi > 70) confirmationCount++;
      
      // BB xác nhận mạnh
      double bbDistance = MathAbs(currentClose - bbUpper) / atr;
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
   
   // Lấy thông tin hiệu suất từ EdgeTracker
   SEdgePerformanceResult performance = EdgeTracker.GetCurrentPerformance();
   
   // Cập nhật dashboard mới
   DashboardPanel.Update(balance, equity, profit, 
                     EdgeTracker.GetMarketCondition(), 
                     performance.winRate, performance.expectancy, performance.profitFactor);
   
   // Cập nhật panel Edge
   EdgePanel.Update();
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
            
            // Lấy thông tin mở lệnh
            ulong positionID = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
            ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
            tradeResult.type = dealType == DEAL_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            
            // Tìm thời gian mở lệnh từ deal mở
            datetime openTime = 0;
            for(int i = 0; i < HistoryDealsTotal(); i++)
            {
               ulong dealTicketSearch = HistoryDealGetTicket(i);
               if(HistoryDealGetInteger(dealTicketSearch, DEAL_POSITION_ID) == positionID &&
                  HistoryDealGetInteger(dealTicketSearch, DEAL_ENTRY) == DEAL_ENTRY_IN)
               {
                  openTime = (datetime)HistoryDealGetInteger(dealTicketSearch, DEAL_TIME);
                  break;
               }
            }
            
            // Tính pips
            double openPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            double pips = MathAbs(openPrice - closePrice) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            tradeResult.pips = pips;
            
            // Thiết lập thời gian
            tradeResult.openTime = openTime;
            tradeResult.closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
            tradeResult.duration = (int)((tradeResult.closeTime - openTime) / 60); // phút
            
            // Thiết lập chất lượng setup (từ EA panel hoặc thiết lập mặc định)
            // Có thể cải tiến để lưu setup quality khi mở lệnh
            tradeResult.setupQuality = SETUP_QUALITY_B;
            
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
            
            // Cập nhật Edge Tracker
            EdgeTracker.AddTradeResult(tradeResult);
            
            // Kiểm tra suy giảm Edge sau mỗi 30 giao dịch
            if(EdgeTracker.GetTotalTrades() % 30 == 0 && EdgeTracker.GetTotalTrades() >= 30)
            {
               SEdgeDegradation edgeDegradation = EdgeTracker.CheckEdgeDegradation();
               if(edgeDegradation.hasDegradation)
               {
                  Journal.LogWarning("Phát hiện suy giảm Edge: " + DoubleToString(edgeDegradation.degradationPercent, 1) + "%. " + 
                                   edgeDegradation.messages);
               }
            }
            
            // Cập nhật panel
            UpdatePanels();
         }
      }
   }
}