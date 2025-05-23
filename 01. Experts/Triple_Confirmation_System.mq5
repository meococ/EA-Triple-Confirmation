//+------------------------------------------------------------------+
//|                                           TripleConfirmation.mq5 |
//|                        Copyright 2025, Your Company               |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"
#property version   "2.00"  // Updated to version 2.0

// Các include cần thiết
#include <Trade\Trade.mqh>       // Thư viện giao dịch chuẩn
#include "..\\Include\\CommonDefinitions.mqh"  // Định nghĩa chung
#include "..\\Include\\TradeManager.mqh"       // Quản lý giao dịch
#include "..\\Include\\RiskCalculator.mqh"     // Tính toán rủi ro
#include "..\\Include\\NewsManager.mqh"        // Quản lý tin tức
#include "..\\Include\\TradeJournal.mqh"       // Nhật ký giao dịch
#include "..\\Include\\TripleConfirmEdgeTracker.mqh"  // Edge Tracker
#include "..\\Data\\ConfigManager.mqh"         // Quản lý cấu hình

// UI includes - chỉ bao gồm khi cần
#include "..\\Include\\Dashboard.mqh"
#include "..\\Include\\TripleConfirmPanel.mqh"
#include "..\\Include\\EdgeDisplay.mqh"
#include "..\\Include\\EdgeCalculator.mqh"

// Định nghĩa buffer index cho TripleConfirmationIndicator
#define BUY_SIGNAL_BUFFER         4
#define SELL_SIGNAL_BUFFER        5
#define ATR_BUFFER                8
#define SETUP_QUALITY_BUFFER      9  // Buffer mới cho chất lượng setup

// Enum cho loại giao dịch
enum ENUM_TRADE_ENTRY_TYPE {
   TRADE_ENTRY_NONE,    // Không có vào lệnh
   TRADE_ENTRY_BUY,     // Vào lệnh mua
   TRADE_ENTRY_SELL     // Vào lệnh bán
};

// Khởi tạo các đối tượng cốt lõi
CTrade         Trade;              // Đối tượng giao dịch
CTradeManager  TradeManager;       // Quản lý giao dịch
CRiskCalculator RiskCalc;          // Tính toán rủi ro
CNewsManager   NewsManager;        // Quản lý tin tức
CTradeJournal  Journal;            // Nhật ký giao dịch
CTripleConfirmEdgeTracker EdgeTracker;  // Edge Tracker

// Khởi tạo các đối tượng UI
CConfigManager ConfigManager;      // Quản lý cấu hình
CTripleConfirmPanel DashboardPanel;  // Dashboard panel
CEdgeDisplay   EdgePanel;          // Panel hiển thị Edge

// Tham số đầu vào cho EA
input group "===== Cài Đặt Chung ====="
input string   EA_Name = "Triple_Confirmation";  // Tên EA
input bool     Enable_Trading = true;            // Bật/tắt giao dịch
input bool     Enable_News_Filter = true;        // Bật/tắt lọc tin tức
input double   Risk_Percent = 0.5;               // % rủi ro/lệnh (giảm từ 1%)
input int      Magic_Number = 123456;            // Số magic

input group "===== Cài Đặt Chiến Lược ====="
input int      VWAP_Period = 20;                 // Chu kỳ VWAP
input int      RSI_Period = 14;                  // Chu kỳ RSI
input double   RSI_Upper = 70;                   // Ngưỡng quá mua RSI
input double   RSI_Lower = 30;                   // Ngưỡng quá bán RSI
input int      BB_Period = 20;                   // Chu kỳ Bollinger Bands
input double   BB_Deviation = 2.0;               // Độ lệch chuẩn BB
input int      ATR_Period = 14;                  // Chu kỳ ATR cho SL/TP
input bool     ShowAlerts = true;                // Hiển thị cảnh báo
input double   VWAP_Min_Distance = 0.5;          // Khoảng cách VWAP tối thiểu (ATR)

input group "===== Cài Đặt Take Profit & Stop Loss ====="
input double   SL_ATR_Multiplier = 1.8;          // Hệ số ATR cho SL (tăng từ 1.2)
input double   TP1_ATR_Multiplier = 2.0;         // Hệ số ATR cho TP1 (tăng từ 1.5)
input double   TP2_ATR_Multiplier = 3.2;         // Hệ số ATR cho TP2 (tăng từ 2.5)
input double   TP3_ATR_Multiplier = 4.8;         // Hệ số ATR cho TP3 (tăng từ 4.0)
input int      TP1_Percent = 40;                 // % khối lượng TP1
input int      TP2_Percent = 35;                 // % khối lượng TP2
input int      TP3_Percent = 25;                 // % khối lượng TP3

input group "===== Cài Đặt Quản Lý Vốn ====="
input bool     Use_ATR_Adaptive_Sizing = true;   // Size thích ứng theo ATR
input int      ATR_Base_Period = 50;             // ATR cơ sở
input bool     Enable_Scaling_After_Loss = true; // Giảm size sau thua
input double   Scaling_Factor = 0.75;            // Hệ số giảm
input int      Max_Consecutive_Scaling = 3;      // Số lần giảm size tối đa

input group "===== Cài Đặt Lọc Thị Trường ====="
input bool     Use_ADX_Filter = true;            // Sử dụng lọc ADX
input int      ADX_Period = 14;                  // Chu kỳ ADX
input int      ADX_Trending_Threshold = 25;      // Ngưỡng xu hướng
input int      ADX_Ranging_Threshold = 20;       // Ngưỡng dao động
input bool     Use_Time_Filter = true;           // Sử dụng bộ lọc thời gian
input int      Start_Hour = 7;                   // Giờ bắt đầu (GMT)
input int      End_Hour = 17;                    // Giờ kết thúc (GMT)
input double   Volatility_Min_Ratio = 0.7;       // Tỷ lệ biến động tối thiểu
input double   Volatility_Max_Ratio = 1.3;       // Tỷ lệ biến động tối đa

input group "===== Cài Đặt Ghi Log ====="
input bool     Enable_Detailed_Logging = true;   // Ghi log chi tiết
input string   Log_Directory = "TripleConfirmation_Logs"; // Thư mục log

input group "===== Cài Đặt Cấu Hình ====="
input bool     UseConfigFile = false;            // Sử dụng file cấu hình
input string   ConfigDirectory = "..\\Data";     // Thư mục cấu hình

// Biến toàn cục
bool           IsNewBar = false;                 // Có nến mới không
datetime       LastBarTime = 0;                  // Thời gian nến cuối
int            ConsecutiveLosses = 0;            // Số lệnh thua liên tiếp
ENUM_MARKET_CONDITION MarketCondition = MARKET_CONDITION_UNDEFINED;  // Điều kiện thị trường
int            TC_Handle = INVALID_HANDLE;       // Handle cho indicator Triple Confirmation
int            ATR_Handle = INVALID_HANDLE;       // Handle cho ATR (chỉ để sử dụng khi cần)
datetime       LastPanelUpdate = 0;              // Thời gian cập nhật panel cuối cùng
double         BaseATR = 0;                      // ATR cơ sở để so sánh
datetime       LastBaseATRCalc = 0;              // Thời gian tính toán ATR cơ sở

// Map để lưu trữ chất lượng setup cho các lệnh đang mở
CHashMap<ulong, ENUM_SETUP_QUALITY> TradeSetupQuality;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Thiết lập magic number
   Trade.SetExpertMagicNumber(Magic_Number);
   
   // Khởi tạo handle cho indicator Triple Confirmation
   TC_Handle = iCustom(_Symbol, PERIOD_CURRENT, "TripleConfirmationIndicator", 
                      VWAP_Period, RSI_Period, RSI_Lower, RSI_Upper, 
                      BB_Period, BB_Deviation, ATR_Period, ShowAlerts, VWAP_Min_Distance);
   
   if(TC_Handle == INVALID_HANDLE)
   {
      int error = GetLastError();
      Print("Lỗi khi tạo Triple Confirmation Indicator handle: ", error, 
            " - kiểm tra đường dẫn, tên và tham số iCustom!");
      return INIT_FAILED;
   }
   
   // Khởi tạo ATR handle (backup)
   ATR_Handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   if(ATR_Handle == INVALID_HANDLE)
   {
      Print("Không thể tạo ATR handle. Lỗi: ", GetLastError());
      return INIT_FAILED;
   }
   
   // Khởi tạo các module
   if(!Journal.Init(Log_Directory, EA_Name, Enable_Detailed_Logging))
      return INIT_FAILED;
      
   if(!NewsManager.Init(Enable_News_Filter))
   {
      Journal.LogError("Không thể khởi tạo NewsManager. Lỗi: " + IntegerToString(GetLastError()));
      return INIT_FAILED;
   }
   
   if(!TradeManager.Init(&Trade, Magic_Number))
   {
      Journal.LogError("Không thể khởi tạo TradeManager");
      return INIT_FAILED;
   }
   
   if(!RiskCalc.Init(Risk_Percent, Use_ATR_Adaptive_Sizing))
   {
      Journal.LogError("Không thể khởi tạo RiskCalculator");
      return INIT_FAILED;
   }
   
   if(!EdgeTracker.Init(EA_Name))
   {
      Journal.LogError("Không thể khởi tạo EdgeTracker");
      return INIT_FAILED;
   }
   
   // Thiết lập ADX parameter cho Edge Tracker
   EdgeTracker.SetADXParameters(ADX_Period, ADX_Trending_Threshold);
   
   // Khởi tạo các module UI
   if(UseConfigFile && !ConfigManager.Init(EA_Name))
   {
      Journal.LogWarning("Không thể khởi tạo ConfigManager. EA sẽ sử dụng tham số nhập trực tiếp.");
   }
   
   if(!DashboardPanel.Init(EA_Name, 10, 10))
   {
      Journal.LogWarning("Không thể khởi tạo Dashboard Panel");
   }
   
   if(!EdgePanel.Init(&EdgeTracker, (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - 210, 10))
   {
      Journal.LogWarning("Không thể khởi tạo Edge Panel");
   }
   
   // Tải dữ liệu tin tức ngay khi khởi động
   if(Enable_News_Filter && !NewsManager.UpdateNewsData())
   {
      Journal.LogWarning("Không thể tải dữ liệu tin tức. Vui lòng kiểm tra kết nối internet và cài đặt WebRequest.");
      Journal.LogWarning("Bạn có thể cần bật quyền WebRequest trong Tools -> Options -> Expert Advisors.");
   }
   
   // Khởi tạo TradeSetupQuality map
   TradeSetupQuality.Clear();
   
   // Ghi log khởi động EA
   Journal.LogInfo("EA Triple Confirmation v2.0 khởi động");
   Journal.LogInfo("Cấu hình từ file: " + (UseConfigFile ? "Bật" : "Tắt"));
   Journal.LogInfo("Bộ lọc tin tức: " + (Enable_News_Filter ? "Bật" : "Tắt"));
   Journal.LogInfo("Bộ lọc ADX: " + (Use_ADX_Filter ? "Bật" : "Tắt"));
   Journal.LogInfo("Bộ lọc thời gian: " + (Use_Time_Filter ? "Bật" : "Tắt"));
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
   
   if(ATR_Handle != INVALID_HANDLE)
   {
      IndicatorRelease(ATR_Handle);
      ATR_Handle = INVALID_HANDLE;
   }
   
   // Dọn dẹp các module
   NewsManager.Deinit();
   Journal.Deinit();
   TradeManager.Deinit();
   RiskCalc.Deinit();
   EdgeTracker.Deinit();
   
   // Dọn dẹp các module UI
   DashboardPanel.Deinit();
   EdgePanel.Deinit();
   
   // Xóa TradeSetupQuality map
   TradeSetupQuality.Clear();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Kiểm tra nến mới - phần lớn xử lý chỉ khi có nến mới
   bool newBar = IsNewBarFormed();
   
   // Quản lý lệnh đang mở (cần xử lý mỗi tick)
   ManageOpenPositions();
   
   // Cập nhật panel với tần suất hợp lý
   UpdatePanelsWithThrottle();
   
   // Nếu không phải nến mới, thoát sớm
   if(!newBar)
      return;
   
   // Cập nhật điều kiện thị trường (chỉ khi có nến mới)
   UpdateMarketCondition();
   
   // Chỉ tìm kiếm tín hiệu khi có nến mới và cho phép giao dịch
   if(Enable_Trading && CanTrade())
   {
      // Tìm kiếm tín hiệu mới
      CheckForSignals();
   }
   
   // Cập nhật panel sau khi xử lý nến mới
   UpdatePanels();
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
      IsNewBar = true;
      return true;
   }
   
   IsNewBar = false;
   return false;
}

//+------------------------------------------------------------------+
//| Cập nhật panel với tần suất hợp lý                              |
//+------------------------------------------------------------------+
void UpdatePanelsWithThrottle()
{
   // Cập nhật panel tối đa mỗi 3 giây
   if(TimeCurrent() - LastPanelUpdate >= 3)
   {
      UpdatePanels();
      LastPanelUpdate = TimeCurrent();
   }
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
   
   // Log điều kiện thị trường nếu có thay đổi
   static ENUM_MARKET_CONDITION lastCondition = MARKET_CONDITION_UNDEFINED;
   if(MarketCondition != lastCondition)
   {
      string conditionStr = "";
      switch(MarketCondition)
      {
         case MARKET_CONDITION_TRENDING: conditionStr = "Trending"; break;
         case MARKET_CONDITION_RANGING: conditionStr = "Ranging"; break;
         case MARKET_CONDITION_VOLATILE: conditionStr = "Volatile"; break;
         case MARKET_CONDITION_LOW_VOLATILITY: conditionStr = "Low Volatility"; break;
         default: conditionStr = "Undefined";
      }
      
      Journal.LogInfo("Điều kiện thị trường: " + conditionStr);
      lastCondition = MarketCondition;
   }
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
//| Kiểm tra tất cả các điều kiện giao dịch                         |
//+------------------------------------------------------------------+
bool CanTrade()
{
   // 1. Kiểm tra tin tức
   if(Enable_News_Filter && NewsManager.IsHighImpactNewsForSymbol(_Symbol))
   {
      Journal.LogInfo("Đang có tin tức quan trọng cho " + _Symbol + ", bỏ qua giao dịch");
      return false;
   }
   
   // 2. Kiểm tra bộ lọc ADX cải tiến (QUAN TRỌNG)
   if(Use_ADX_Filter)
   {
      if(MarketCondition == MARKET_CONDITION_UNDEFINED)
      {
         Journal.LogInfo("Điều kiện thị trường chưa xác định");
         return false;
      }
      
      // Nghiêm ngặt: Chỉ giao dịch mean reversion khi ADX < ADX_Ranging_Threshold (20)
      if(MarketCondition == MARKET_CONDITION_TRENDING)
      {
         Journal.LogInfo("Không giao dịch mean reversion trong thị trường trending (ADX > " + 
                        IntegerToString(ADX_Ranging_Threshold) + ")");
         return false;
      }
   }
   
   // 3. Kiểm tra bộ lọc thời gian
   if(Use_Time_Filter)
   {
      datetime serverTime = TimeCurrent();
      MqlDateTime time;
      TimeToStruct(serverTime, time);
      
      if(time.hour < Start_Hour || time.hour >= End_Hour)
      {
         Journal.LogInfo("Ngoài khung giờ giao dịch tối ưu (" + 
                        IntegerToString(Start_Hour) + "-" + 
                        IntegerToString(End_Hour) + " GMT)");
         return false;
      }
   }
   
   // 4. Kiểm tra bộ lọc biến động
   double currentATR = GetCurrentATR();
   double baseATR = GetBaseATR();
   
   if(baseATR <= 0)
   {
      Journal.LogWarning("Không thể lấy ATR cơ sở");
      return false;
   }
   
   double volatilityRatio = currentATR / baseATR;
   if(volatilityRatio < Volatility_Min_Ratio || volatilityRatio > Volatility_Max_Ratio)
   {
      Journal.LogInfo("Biến động không phù hợp: " + 
                     DoubleToString(volatilityRatio * 100, 0) + 
                     "% so với trung bình (phạm vi: " + 
                     DoubleToString(Volatility_Min_Ratio * 100, 0) + "-" + 
                     DoubleToString(Volatility_Max_Ratio * 100, 0) + "%)");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Tìm kiếm tín hiệu giao dịch mới                                 |
//+------------------------------------------------------------------+
void CheckForSignals()
{
   // Kiểm tra handle Triple Confirmation indicator
   if(TC_Handle == INVALID_HANDLE)
   {
      Journal.LogError("Triple Confirmation Indicator handle không hợp lệ");
      return;
   }
   
   // Lấy tín hiệu từ indicator
   ENUM_TRADE_ENTRY_TYPE signalType = TRADE_ENTRY_NONE;
   ENUM_SETUP_QUALITY setupQuality = SETUP_QUALITY_NONE;
   double atr = 0;
   
   // Đọc các buffer từ indicator
   double buyBuffer[], sellBuffer[], atrBuffer[], setupQualityBuffer[];
   ArraySetAsSeries(buyBuffer, true);
   ArraySetAsSeries(sellBuffer, true);
   ArraySetAsSeries(atrBuffer, true);
   ArraySetAsSeries(setupQualityBuffer, true);
   
   // Copy dữ liệu từ indicator
   bool dataOK = true;
   
   if(CopyBuffer(TC_Handle, BUY_SIGNAL_BUFFER, 0, 2, buyBuffer) <= 0)
   {
      Journal.LogError("Không thể copy Buy Signal buffer. Lỗi: " + IntegerToString(GetLastError()));
      dataOK = false;
   }
   
   if(CopyBuffer(TC_Handle, SELL_SIGNAL_BUFFER, 0, 2, sellBuffer) <= 0)
   {
      Journal.LogError("Không thể copy Sell Signal buffer. Lỗi: " + IntegerToString(GetLastError()));
      dataOK = false;
   }
   
   if(CopyBuffer(TC_Handle, ATR_BUFFER, 0, 1, atrBuffer) <= 0)
   {
      Journal.LogError("Không thể copy ATR buffer. Lỗi: " + IntegerToString(GetLastError()));
      dataOK = false;
   }
   
   if(CopyBuffer(TC_Handle, SETUP_QUALITY_BUFFER, 0, 2, setupQualityBuffer) <= 0)
   {
      Journal.LogError("Không thể copy Setup Quality buffer. Lỗi: " + IntegerToString(GetLastError()));
      dataOK = false;
   }
   
   if(!dataOK)
      return;
   
   // Xác định loại tín hiệu
   if(buyBuffer[0] != EMPTY_VALUE)
   {
      signalType = TRADE_ENTRY_BUY;
      setupQuality = (ENUM_SETUP_QUALITY)(int)setupQualityBuffer[0];
      Journal.LogInfo("Phát hiện tín hiệu MUA từ Triple Confirmation Indicator, chất lượng: " + 
                     GetSetupQualityString(setupQuality));
   }
   else if(sellBuffer[0] != EMPTY_VALUE)
   {
      signalType = TRADE_ENTRY_SELL;
      setupQuality = (ENUM_SETUP_QUALITY)(int)setupQualityBuffer[0];
      Journal.LogInfo("Phát hiện tín hiệu BÁN từ Triple Confirmation Indicator, chất lượng: " + 
                     GetSetupQualityString(setupQuality));
   }
   
   // Nếu không có tín hiệu, kết thúc
   if(signalType == TRADE_ENTRY_NONE)
      return;
   
   // Lấy ATR từ indicator
   atr = atrBuffer[0];
   if(atr <= 0)
   {
      // Fallback to ATR handle nếu không có ATR từ indicator
      Journal.LogWarning("ATR từ indicator không hợp lệ, sử dụng ATR handle");
      atr = GetCurrentATR();
      
      if(atr <= 0)
      {
         Journal.LogError("Không thể lấy giá trị ATR hợp lệ");
         return;
      }
   }
   
   // Chỉ giao dịch setup A+ và A
   if(setupQuality != SETUP_QUALITY_A_PLUS && setupQuality != SETUP_QUALITY_A)
   {
      Journal.LogInfo("Tín hiệu " + (signalType == TRADE_ENTRY_BUY ? "MUA" : "BÁN") + 
                     " bị bỏ qua do chất lượng setup không đủ cao: " + 
                     GetSetupQualityString(setupQuality));
      return;
   }
   
   // Tính toán và thực hiện vào lệnh
   ExecuteTrade(signalType, setupQuality, atr);
}

//+------------------------------------------------------------------+
//| Chuyển đổi chất lượng setup thành chuỗi                         |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Thực hiện giao dịch                                             |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_TRADE_ENTRY_TYPE signalType, ENUM_SETUP_QUALITY setupQuality, double atr)
{
   // Lấy giá hiện tại
   double currentPrice = signalType == TRADE_ENTRY_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Tính toán SL/TP theo phiên bản 2.0
   double stopLoss = 0, takeProfit1 = 0, takeProfit2 = 0, takeProfit3 = 0;
   
   if(signalType == TRADE_ENTRY_BUY)
   {
      stopLoss = currentPrice - atr * SL_ATR_Multiplier;
      takeProfit1 = currentPrice + atr * TP1_ATR_Multiplier;
      takeProfit2 = currentPrice + atr * TP2_ATR_Multiplier;
      takeProfit3 = currentPrice + atr * TP3_ATR_Multiplier;
   }
   else  // SELL
   {
      stopLoss = currentPrice + atr * SL_ATR_Multiplier;
      takeProfit1 = currentPrice - atr * TP1_ATR_Multiplier;
      takeProfit2 = currentPrice - atr * TP2_ATR_Multiplier;
      takeProfit3 = currentPrice - atr * TP3_ATR_Multiplier;
   }
   
   // Điều chỉnh position size dựa trên chất lượng setup
   double positionSizeMultiplier = 1.0;
   
   // Giảm size cho setup A
   if(setupQuality == SETUP_QUALITY_A)
      positionSizeMultiplier *= 0.75;  // Giảm 25% cho setup A
   
   // Giảm size sau các lệnh thua lỗ
   if(Enable_Scaling_After_Loss && ConsecutiveLosses > 0)
   {
      int scalingCount = MathMin(ConsecutiveLosses, Max_Consecutive_Scaling);
      positionSizeMultiplier *= MathPow(Scaling_Factor, scalingCount);
      Journal.LogInfo("Giảm size do thua lỗ liên tiếp: " + IntegerToString(ConsecutiveLosses) + 
                     " lệnh, hệ số: " + DoubleToString(positionSizeMultiplier, 2));
   }
   
   // Tính toán khối lượng giao dịch
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * Risk_Percent / 100.0 * positionSizeMultiplier;
   double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double stopLossPips = MathAbs(currentPrice - stopLoss) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double lotSize = NormalizeDouble(riskAmount / (stopLossPips * pointValue), 2);
   
   // Điều chỉnh theo ATR nếu cần
   if(Use_ATR_Adaptive_Sizing)
   {
      double baseATR = GetBaseATR();
      if(baseATR > 0)
      {
         double atrRatio = baseATR / atr;
         lotSize *= atrRatio;
         lotSize = NormalizeDouble(lotSize, 2);
      }
   }
   
   // Kiểm tra min/max lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   // Tạo chi tiết giao dịch cho log
   STradeDetails tradeDetails;
   tradeDetails.symbol = _Symbol;
   tradeDetails.entryPrice = currentPrice;
   tradeDetails.direction = signalType == TRADE_ENTRY_BUY ? TRADE_DIRECTION_BUY : TRADE_DIRECTION_SELL;
   tradeDetails.stopLoss = stopLoss;
   tradeDetails.takeProfit1 = takeProfit1;
   tradeDetails.takeProfit2 = takeProfit2;
   tradeDetails.takeProfit3 = takeProfit3;
   tradeDetails.riskReward = MathAbs(takeProfit1 - currentPrice) / MathAbs(currentPrice - stopLoss);
   tradeDetails.setupQuality = setupQuality;
   tradeDetails.marketCondition = MarketCondition;
   tradeDetails.lotSize = lotSize;
   tradeDetails.risk = Risk_Percent * positionSizeMultiplier;
   tradeDetails.ATR = atr;
   
   // Log chi tiết trước khi vào lệnh
   Journal.LogTradeSetup(tradeDetails);
   
   // Thực hiện vào lệnh
   ENUM_ORDER_TYPE orderType = signalType == TRADE_ENTRY_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   bool tradeResult = TradeManager.OpenTrade(orderType, lotSize, stopLoss, takeProfit1, 
                                           TP1_Percent, TP2_Percent, TP3_Percent,
                                           takeProfit2, takeProfit3);
   
   // Log kết quả vào lệnh
   if(tradeResult)
   {
      Journal.LogTradeEntry(tradeDetails);
      
      // Lưu trữ chất lượng setup cho lệnh vừa mở
      ulong ticket = Trade.ResultOrder();
      if(ticket > 0)
      {
         TradeSetupQuality.Add(ticket, setupQuality);
         Journal.LogInfo("Lưu trữ chất lượng setup cho lệnh #" + IntegerToString(ticket) + 
                        ": " + GetSetupQualityString(setupQuality));
      }
      
      // Cập nhật panel
      EdgePanel.UpdateLastSignal(signalType == TRADE_ENTRY_BUY ? "BUY" : "SELL", setupQuality);
      UpdatePanels();
   }
   else
   {
      Journal.LogError("Vào lệnh " + (signalType == TRADE_ENTRY_BUY ? "BUY" : "SELL") + 
                      " thất bại: " + Trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Lấy giá trị ATR cơ sở để so sánh với ATR hiện tại              |
//+------------------------------------------------------------------+
double GetBaseATR()
{
   // Chỉ tính lại ATR cơ sở mỗi giờ để tiết kiệm tài nguyên
   if(BaseATR == 0 || TimeCurrent() - LastBaseATRCalc > 3600)
   {
      int tempHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_Base_Period);
      
      if(tempHandle != INVALID_HANDLE)
      {
         double buffer[];
         ArraySetAsSeries(buffer, true);
         
         if(CopyBuffer(tempHandle, 0, 0, 1, buffer) > 0)
            BaseATR = buffer[0];
            
         IndicatorRelease(tempHandle);
      }
      
      LastBaseATRCalc = TimeCurrent();
   }
   
   return BaseATR;
}

//+------------------------------------------------------------------+
//| Lấy giá trị ATR hiện tại                                        |
//+------------------------------------------------------------------+
double GetCurrentATR()
{
   double atr = 0;
   double buffer[];
   ArraySetAsSeries(buffer, true);
   
   if(CopyBuffer(ATR_Handle, 0, 0, 1, buffer) > 0)
      atr = buffer[0];
      
   return atr;
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
   
   // Cập nhật thời gian cập nhật cuối cùng
   LastPanelUpdate = TimeCurrent();
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
   
   // Xử lý cập nhật ConsecutiveLosses và Edge Tracking
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      // Lấy thông tin giao dịch
      ulong dealTicket = trans.deal;
      if(dealTicket == 0)
         return;
         
      // Lựa chọn lịch sử giao dịch
      if(!HistorySelect(0, TimeCurrent()))
      {
         Journal.LogError("Không thể chọn lịch sử giao dịch");
         return;
      }
      
      if(HistoryDealSelect(dealTicket))
      {
         // Kiểm tra nếu là giao dịch đóng lệnh
         if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            // Lấy thông tin position
            ulong positionID = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
            
            // Kiểm tra kết quả lợi nhuận
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
            
            // Chuẩn bị kết quả giao dịch
            STradeResult tradeResult;
            tradeResult.ticket = positionID;
            tradeResult.symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
            tradeResult.profit = profit;
            
            // Xác định loại lệnh
            ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
            tradeResult.type = dealType == DEAL_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            
            // Tìm thời gian mở lệnh từ deal mở
            datetime openTime = 0;
            for(int i = 0; i < HistoryDealsTotal(); i++)
            {
               ulong searchTicket = HistoryDealGetTicket(i);
               if(HistoryDealGetInteger(searchTicket, DEAL_POSITION_ID) == positionID &&
                  HistoryDealGetInteger(searchTicket, DEAL_ENTRY) == DEAL_ENTRY_IN)
               {
                  openTime = (datetime)HistoryDealGetInteger(searchTicket, DEAL_TIME);
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
            
            // Lấy chất lượng setup từ lưu trữ
            if(TradeSetupQuality.ContainsKey(positionID))
            {
               tradeResult.setupQuality = TradeSetupQuality.GetValue(positionID);
               TradeSetupQuality.Remove(positionID);  // Xóa sau khi sử dụng
               Journal.LogInfo("Lấy chất lượng setup cho lệnh #" + IntegerToString(positionID) + 
                              ": " + GetSetupQualityString(tradeResult.setupQuality));
            }
            else
            {
               tradeResult.setupQuality = SETUP_QUALITY_B;  // Mặc định nếu không tìm thấy
               Journal.LogWarning("Không tìm thấy thông tin chất lượng setup cho lệnh #" + 
                                IntegerToString(positionID));
            }
            
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
            
            // Log kết quả giao dịch
            Journal.LogTradeResult(tradeResult);
            
            // Cập nhật Edge Tracker
            EdgeTracker.AddTradeResult(tradeResult);
            
            // Kiểm tra suy giảm Edge sau mỗi 30 giao dịch
            if(EdgeTracker.GetTotalTrades() % 30 == 0 && EdgeTracker.GetTotalTrades() >= 30)
            {
               SEdgeDegradation edgeDegradation = EdgeTracker.CheckEdgeDegradation();
               if(edgeDegradation.hasDegradation)
               {
                  Journal.LogWarning("Phát hiện suy giảm Edge: " + 
                                   DoubleToString(edgeDegradation.degradationPercent, 1) + 
                                   "%. " + edgeDegradation.messages);
               }
            }
            
            // Cập nhật panel
            UpdatePanels();
         }
      }
   }
}