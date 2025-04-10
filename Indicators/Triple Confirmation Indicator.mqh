//+------------------------------------------------------------------+
//|                                      TripleConfirmation.mq5 |
//|                        Copyright 2025, Your Company               |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   7

// Cài đặt hiển thị của indicator
#property indicator_label1  "VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "BB Trên"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

#property indicator_label3  "BB Giữa"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

#property indicator_label4  "BB Dưới"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrRed
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

#property indicator_label5  "Tín Hiệu Mua"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrLimeGreen
#property indicator_width5  3

#property indicator_label6  "Tín Hiệu Bán"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrCrimson
#property indicator_width6  3

#property indicator_label7  "Mức RSI"
#property indicator_type7   DRAW_COLOR_HISTOGRAM
#property indicator_color7  clrGreen,clrGray,clrRed
#property indicator_style7  STYLE_SOLID
#property indicator_width7  2

// Tham số đầu vào của indicator
input int      VWAP_Period = 20;            // Chu kỳ VWAP
input int      RSI_Period = 9;              // Chu kỳ RSI
input int      RSI_Oversold = 35;           // Ngưỡng quá bán RSI
input int      RSI_Overbought = 65;         // Ngưỡng quá mua RSI
input int      BB_Period = 20;              // Chu kỳ Bollinger Bands
input double   BB_Deviation = 2.0;          // Độ lệch chuẩn BB
input int      ATR_Period = 14;             // Chu kỳ ATR
input int      ATR_Base_Period = 50;        // Chu kỳ ATR cơ sở
input bool     ShowAlerts = false;          // Hiển thị cảnh báo

// Buffers của indicator
double VWAP_Buffer[];
double BB_Upper_Buffer[];
double BB_Middle_Buffer[];
double BB_Lower_Buffer[];
double Buy_Signal_Buffer[];
double Sell_Signal_Buffer[];
double RSI_Histogram_Buffer[];
double RSI_Color_Buffer[];

// Handles của các indicator
int RSI_Handle;
int BB_Handle;
int OBV_Handle;
int VWAP_Handle;   // Handle cho VWAP indicator
int ATR_Handle;    // Handle cho ATR indicator
int ATR_Base_Handle; // Handle cho ATR Base (có thể sử dụng chu kỳ khác)

// Biến toàn cục
datetime lastAlertTime = 0;
datetime lastBuySignalTime = 0;
datetime lastSellSignalTime = 0;

//+------------------------------------------------------------------+
//| Cấu trúc lưu trữ các giá trị indicator đã tính                  |
//+------------------------------------------------------------------+
struct IndicatorValues
{
   double rsi;           // Giá trị RSI hiện tại
   double vwap;          // Giá trị VWAP
   double bb_upper;      // Bollinger Band trên
   double bb_middle;     // Bollinger Band giữa
   double bb_lower;      // Bollinger Band dưới
   double obv;           // Giá trị OBV hiện tại
   double obv_prev;      // Giá trị OBV trước đó
   double atr;           // ATR
   double atr_base;      // ATR Base (chu kỳ dài hơn)
   bool values_loaded;   // Cờ đánh dấu đã tải giá trị
   
   // Constructor
   IndicatorValues()
   {
      rsi = 0.0;
      vwap = 0.0;
      bb_upper = 0.0;
      bb_middle = 0.0;
      bb_lower = 0.0;
      obv = 0.0;
      obv_prev = 0.0;
      atr = 0.0;
      atr_base = 0.0;
      values_loaded = false;
   }
};

// Biến toàn cục để lưu trữ các giá trị indicator cho chu kỳ hiện tại
IndicatorValues cached_values;

//+------------------------------------------------------------------+
//| Hàm khởi tạo RSI Handle với chuyển đổi kiểu rõ ràng            |
//+------------------------------------------------------------------+
int CreateRSIHandle()
{
   // Đảm bảo các tham số đúng kiểu
   int period = (int)RSI_Period;
   
   // Kiểm tra tính hợp lệ của các tham số
   if(period <= 0)
   {
      Print("Lỗi: RSI_Period phải lớn hơn 0! Giá trị hiện tại: ", period);
      return INVALID_HANDLE;
   }
   
   // Log các giá trị để kiểm tra
   Print("Creating RSI Handle with: Period=", period);
   
   // Khai báo tất cả các tham số với kiểu dữ liệu chính xác
   string symbol = _Symbol;
   ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT;
   int rsi_period = period;
   ENUM_APPLIED_PRICE applied_price = PRICE_CLOSE;
   
   // Tạo handle với các tham số đã được khai báo đúng kiểu
   int handle = iRSI(symbol, timeframe, rsi_period, applied_price);
   
   // Kiểm tra kết quả
   if(handle == INVALID_HANDLE)
   {
      Print("Lỗi khi tạo RSI Handle: ", GetLastError());
   }
   
   return handle;
}

//+------------------------------------------------------------------+
//| Hàm khởi tạo ATR Handle với chuyển đổi kiểu rõ ràng             |
//+------------------------------------------------------------------+
int CreateATRHandle(int atr_period)
{
   // Đảm bảo các tham số đúng kiểu
   int period = (int)atr_period;
   
   // Kiểm tra tính hợp lệ của các tham số
   if(period <= 0)
   {
      Print("Lỗi: ATR_Period phải lớn hơn 0! Giá trị hiện tại: ", period);
      return INVALID_HANDLE;
   }
   
   // Log các giá trị để kiểm tra
   Print("Creating ATR Handle with: Period=", period);
   
   // Khai báo tất cả các tham số với kiểu dữ liệu chính xác
   string symbol = _Symbol;
   ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT;
   int atr_period_param = period;
   
   // Tạo handle với các tham số đã được khai báo đúng kiểu
   int handle = iATR(symbol, timeframe, atr_period_param);
   
   // Kiểm tra kết quả
   if(handle == INVALID_HANDLE)
   {
      Print("Lỗi khi tạo ATR Handle: ", GetLastError());
   }
   
   return handle;
}

//+------------------------------------------------------------------+
//| Hàm khởi tạo OBV Handle với chuyển đổi kiểu rõ ràng             |
//+------------------------------------------------------------------+
int CreateOBVHandle()
{
   // Log thông tin
   Print("Creating OBV Handle");
   
   // Khai báo tất cả các tham số với kiểu dữ liệu chính xác
   string symbol = _Symbol;
   ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT;
   ENUM_APPLIED_VOLUME applied_volume = VOLUME_TICK;
   
   // Tạo handle với các tham số đã được khai báo đúng kiểu
   int handle = iOBV(symbol, timeframe, applied_volume);
   
   // Kiểm tra kết quả
   if(handle == INVALID_HANDLE)
   {
      Print("Lỗi khi tạo OBV Handle: ", GetLastError());
   }
   
   return handle;
}

//+------------------------------------------------------------------+
//| Hàm khởi tạo Bollinger Bands Handle với chuyển đổi kiểu rõ ràng |
//+------------------------------------------------------------------+
int CreateBollingerBandsHandle()
{
   // Đảm bảo các tham số đúng kiểu
   int period = (int)BB_Period;
   double deviation = (double)BB_Deviation;
   
   // Kiểm tra tính hợp lệ của các tham số
   if(period <= 0)
   {
      Print("Lỗi: BB_Period phải lớn hơn 0! Giá trị hiện tại: ", period);
      return INVALID_HANDLE;
   }
   
   if(deviation <= 0.0)
   {
      Print("Lỗi: BB_Deviation phải lớn hơn 0! Giá trị hiện tại: ", deviation);
      return INVALID_HANDLE;
   }
   
   // Log các giá trị để kiểm tra
   Print("Creating BB Handle with: Period=", period, ", Deviation=", deviation);
   
   // Khai báo tất cả các tham số với kiểu dữ liệu chính xác
   string symbol = _Symbol;
   ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT;
   int bands_period = period;
   double bands_deviation = deviation;
   int bands_shift = 0;
   ENUM_APPLIED_PRICE applied_price = PRICE_CLOSE;
   
   // Tạo handle với các tham số đã được khai báo đúng kiểu
   int handle = iBands(symbol, timeframe, bands_period, bands_deviation, bands_shift, applied_price);
   
   // Kiểm tra kết quả
   if(handle == INVALID_HANDLE)
   {
      Print("Lỗi khi tạo BB Handle: ", GetLastError());
   }
   
   return handle;
}

//+------------------------------------------------------------------+
//| Hàm khởi tạo indicator                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // Thêm logging chi tiết cho việc debug
   Print("======= OnInit started: Checking parameters... =======");
   
   // Kiểm tra tham số đầu vào
   if(BB_Period <= 0 || RSI_Period <= 0 || VWAP_Period <= 0)
   {
      Print("Lỗi nghiêm trọng: Tham số chu kỳ không hợp lệ! BB_Period=", BB_Period, 
            ", RSI_Period=", RSI_Period, ", VWAP_Period=", VWAP_Period);
      return(INIT_PARAMETERS_INCORRECT);
   }

   // Kiểm tra BB_Deviation
   if(BB_Deviation <= 0)
   {
      Print("Lỗi nghiêm trọng: Độ lệch BB phải lớn hơn 0! BB_Deviation=", BB_Deviation);
      return(INIT_PARAMETERS_INCORRECT);
   }

   Print("Các tham số hợp lệ. Thiết lập index buffers...");

   // Thiết lập các buffer của indicator
   if(!SetIndexBuffer(0, VWAP_Buffer, INDICATOR_DATA) ||
      !SetIndexBuffer(1, BB_Upper_Buffer, INDICATOR_DATA) ||
      !SetIndexBuffer(2, BB_Middle_Buffer, INDICATOR_DATA) ||
      !SetIndexBuffer(3, BB_Lower_Buffer, INDICATOR_DATA) ||
      !SetIndexBuffer(4, Buy_Signal_Buffer, INDICATOR_DATA) ||
      !SetIndexBuffer(5, Sell_Signal_Buffer, INDICATOR_DATA) ||
      !SetIndexBuffer(6, RSI_Histogram_Buffer, INDICATOR_DATA) ||
      !SetIndexBuffer(7, RSI_Color_Buffer, INDICATOR_COLOR_INDEX))
   {
      int error = GetLastError();
      Print("Lỗi nghiêm trọng khi thiết lập buffer indicator: ", error);
      return(INIT_FAILED);
   }
   
   Print("Index buffers đã được thiết lập thành công. Thiết lập mã mũi tên...");
   
   // Thiết lập mã mũi tên cho tín hiệu
   PlotIndexSetInteger(4, PLOT_ARROW, 233); // Mũi tên cho tín hiệu mua
   PlotIndexSetInteger(5, PLOT_ARROW, 234); // Mũi tên cho tín hiệu bán
   
   Print("Mã mũi tên đã được thiết lập. Khởi tạo các buffer...");
   
   // Khởi tạo các buffer với giá trị rỗng
   ArrayInitialize(VWAP_Buffer, EMPTY_VALUE);
   ArrayInitialize(BB_Upper_Buffer, EMPTY_VALUE);
   ArrayInitialize(BB_Middle_Buffer, EMPTY_VALUE);
   ArrayInitialize(BB_Lower_Buffer, EMPTY_VALUE);
   ArrayInitialize(Buy_Signal_Buffer, EMPTY_VALUE);
   ArrayInitialize(Sell_Signal_Buffer, EMPTY_VALUE);
   ArrayInitialize(RSI_Histogram_Buffer, EMPTY_VALUE);
   ArrayInitialize(RSI_Color_Buffer, EMPTY_VALUE);
   
   Print("Các buffer đã được khởi tạo. Bắt đầu tạo indicator handles...");
   
   // Tạo từng handle riêng biệt và kiểm tra kết quả sau mỗi lần tạo
   Print("Tạo RSI Handle với chu kỳ ", RSI_Period, "...");
   RSI_Handle = CreateRSIHandle();
   if(RSI_Handle == INVALID_HANDLE)
   {
      Print("Lỗi nghiêm trọng: Không thể tạo RSI Handle!");
      return(INIT_FAILED);
   }
   
   Print("Tạo Bollinger Bands Handle với chu kỳ ", BB_Period, ", độ lệch ", BB_Deviation, "...");
   BB_Handle = CreateBollingerBandsHandle();
   if(BB_Handle == INVALID_HANDLE)
   {
      Print("Lỗi nghiêm trọng: Không thể tạo Bollinger Bands Handle!");
      IndicatorRelease(RSI_Handle); // Giải phóng handle đã tạo trước đó
      return(INIT_FAILED);
   }
   
   Print("Tạo OBV Handle...");
   OBV_Handle = CreateOBVHandle();
   if(OBV_Handle == INVALID_HANDLE)
   {
      Print("Lỗi nghiêm trọng: Không thể tạo OBV Handle!");
      // Giải phóng handles đã tạo
      IndicatorRelease(RSI_Handle);
      IndicatorRelease(BB_Handle);
      return(INIT_FAILED);
   }
   
   Print("Tạo ATR Handle với chu kỳ ", ATR_Period, "...");
   ATR_Handle = CreateATRHandle(ATR_Period);
   if(ATR_Handle == INVALID_HANDLE)
   {
      Print("Lỗi nghiêm trọng: Không thể tạo ATR Handle!");
      // Giải phóng handles đã tạo
      IndicatorRelease(RSI_Handle);
      IndicatorRelease(BB_Handle);
      IndicatorRelease(OBV_Handle);
      return(INIT_FAILED);
   }
   
   Print("Tạo ATR Base Handle với chu kỳ ", ATR_Base_Period, "...");
   ATR_Base_Handle = CreateATRHandle(ATR_Base_Period);
   if(ATR_Base_Handle == INVALID_HANDLE)
   {
      Print("Lỗi nghiêm trọng: Không thể tạo ATR Base Handle!");
      // Giải phóng handles đã tạo
      IndicatorRelease(RSI_Handle);
      IndicatorRelease(BB_Handle);
      IndicatorRelease(OBV_Handle);
      IndicatorRelease(ATR_Handle);
      return(INIT_FAILED);
   }
   
   // Kiểm tra lại tất cả handles đã được tạo thành công
   Print("Tất cả handles đã được tạo thành công!");
   
   // Thiết lập tên ngắn của indicator
   string short_name = "Triple Confirmation (VWAP, RSI, BB)";
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   
   // Khởi tạo thành công
   Print("======= OnInit hoàn tất thành công! =======");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Hàm dọn dẹp indicator                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Giải phóng handle của indicator
   if(RSI_Handle != INVALID_HANDLE)
      IndicatorRelease(RSI_Handle);
      
   if(BB_Handle != INVALID_HANDLE)
      IndicatorRelease(BB_Handle);
      
   if(OBV_Handle != INVALID_HANDLE)
      IndicatorRelease(OBV_Handle);
      
   if(ATR_Handle != INVALID_HANDLE)
      IndicatorRelease(ATR_Handle);
      
   if(ATR_Base_Handle != INVALID_HANDLE)
      IndicatorRelease(ATR_Base_Handle);
}

//+------------------------------------------------------------------+
//| Hàm tải tất cả giá trị indicator cần thiết cho 1 chu kỳ          |
//+------------------------------------------------------------------+
bool LoadIndicatorValues(const double &close[], int idx, int buffer_size)
{
   // Reset cờ đánh dấu
   cached_values.values_loaded = false;
   
   // Kiểm tra tính hợp lệ của chỉ số
   if(idx < 0)
   {
      Print("Lỗi LoadIndicatorValues: chỉ số (", idx, ") không hợp lệ");
      return false;
   }
   
   // Kiểm tra tính hợp lệ của handles
   if(RSI_Handle == INVALID_HANDLE || BB_Handle == INVALID_HANDLE || 
      OBV_Handle == INVALID_HANDLE || ATR_Handle == INVALID_HANDLE || 
      ATR_Base_Handle == INVALID_HANDLE)
   {
      // Thử khôi phục các handles không hợp lệ
      if(RSI_Handle == INVALID_HANDLE)
         RSI_Handle = CreateRSIHandle();
         
      if(BB_Handle == INVALID_HANDLE)
         BB_Handle = CreateBollingerBandsHandle();
         
      if(OBV_Handle == INVALID_HANDLE)
         OBV_Handle = CreateOBVHandle();
         
      if(ATR_Handle == INVALID_HANDLE)
         ATR_Handle = CreateATRHandle(ATR_Period);
         
      if(ATR_Base_Handle == INVALID_HANDLE)
         ATR_Base_Handle = CreateATRHandle(ATR_Base_Period);
      
      // Kiểm tra lại sau khi khôi phục
      if(RSI_Handle == INVALID_HANDLE || BB_Handle == INVALID_HANDLE || 
         OBV_Handle == INVALID_HANDLE || ATR_Handle == INVALID_HANDLE || 
         ATR_Base_Handle == INVALID_HANDLE)
      {
         Print("Lỗi LoadIndicatorValues: không thể khôi phục handles không hợp lệ");
         return false;
      }
   }
   
   // Chuẩn bị mảng tạm thời - sử dụng biến static để tránh cấp phát bộ nhớ liên tục
   static double rsi_buffer[];
   static double bb_upper_buffer[];
   static double bb_middle_buffer[];
   static double bb_lower_buffer[];
   static double obv_buffer[];
   static double atr_buffer[];
   static double atr_base_buffer[];
   
   // Thiết lập chế độ series
   ArraySetAsSeries(rsi_buffer, true);
   ArraySetAsSeries(bb_upper_buffer, true);
   ArraySetAsSeries(bb_middle_buffer, true);
   ArraySetAsSeries(bb_lower_buffer, true);
   ArraySetAsSeries(obv_buffer, true);
   ArraySetAsSeries(atr_buffer, true);
   ArraySetAsSeries(atr_base_buffer, true);
   
   // Cấp phát bộ nhớ - chỉ cần lấy 2 phần tử để kiểm tra hiện tại và trước đó
   if(!ArrayResize(rsi_buffer, 1) ||
      !ArrayResize(bb_upper_buffer, 1) ||
      !ArrayResize(bb_middle_buffer, 1) ||
      !ArrayResize(bb_lower_buffer, 1) ||
      !ArrayResize(obv_buffer, 2) ||       // Cần 2 phần tử để so sánh hiện tại và trước đó
      !ArrayResize(atr_buffer, 1) ||
      !ArrayResize(atr_base_buffer, 1))
   {
      int error = GetLastError();
      Print("Lỗi cấp phát bộ nhớ cho mảng tạm thời: ", error);
      return false;
   }
   
   // Sao chép giá trị từ các handle với logging chi tiết
   bool success = true;
   int error = 0;
   
   // Lấy RSI
   if(CopyBuffer(RSI_Handle, 0, idx, 1, rsi_buffer) <= 0)
   {
      error = GetLastError();
      Print("Lỗi khi sao chép RSI buffer (idx=", idx, "): ", error);
      success = false;
   }
   
   // Lấy BB Upper
   if(CopyBuffer(BB_Handle, 1, idx, 1, bb_upper_buffer) <= 0)
   {
      error = GetLastError();
      Print("Lỗi khi sao chép BB Upper buffer (idx=", idx, "): ", error);
      success = false;
   }
   
   // Lấy BB Middle
   if(CopyBuffer(BB_Handle, 0, idx, 1, bb_middle_buffer) <= 0)
   {
      error = GetLastError();
      Print("Lỗi khi sao chép BB Middle buffer (idx=", idx, "): ", error);
      success = false;
   }
   
   // Lấy BB Lower
   if(CopyBuffer(BB_Handle, 2, idx, 1, bb_lower_buffer) <= 0)
   {
      error = GetLastError();
      Print("Lỗi khi sao chép BB Lower buffer (idx=", idx, "): ", error);
      success = false;
   }
   
   // Lấy OBV - cần 2 phần tử cho hiện tại và trước đó
   if(CopyBuffer(OBV_Handle, 0, idx, 2, obv_buffer) <= 0)
   {
      error = GetLastError();
      Print("Lỗi khi sao chép OBV buffer (idx=", idx, "): ", error);
      success = false;
   }
   
   // Lấy ATR
   if(CopyBuffer(ATR_Handle, 0, idx, 1, atr_buffer) <= 0)
   {
      error = GetLastError();
      Print("Lỗi khi sao chép ATR buffer (idx=", idx, "): ", error);
      success = false;
   }
   
   // Lấy ATR Base
   if(CopyBuffer(ATR_Base_Handle, 0, idx, 1, atr_base_buffer) <= 0)
   {
      error = GetLastError();
      Print("Lỗi khi sao chép ATR Base buffer (idx=", idx, "): ", error);
      success = false;
   }
   
   if(!success)
   {
      Print("Một số buffer không thể sao chép, kiểm tra lỗi ở trên");
      return false;
   }
   
   // Lưu trữ giá trị đã tính
   cached_values.rsi = rsi_buffer[0];
   cached_values.bb_upper = bb_upper_buffer[0];
   cached_values.bb_middle = bb_middle_buffer[0];
   cached_values.bb_lower = bb_lower_buffer[0];
   cached_values.obv = obv_buffer[0];
   cached_values.obv_prev = (ArraySize(obv_buffer) > 1) ? obv_buffer[1] : 0.0;
   cached_values.atr = atr_buffer[0];
   cached_values.atr_base = atr_base_buffer[0];
   
   // VWAP tính trực tiếp (thay thế bằng handle VWAP_Handle nếu có)
   cached_values.vwap = 0.0; // Sẽ được tính bởi hàm CalculateVWAP
   
   // Log các giá trị đã tải để debug
   if(MQLInfoInteger(MQL_DEBUG))
   {
      string debug_info = StringFormat(
         "LoadIndicatorValues (idx=%d): RSI=%.2f, BB_Upper=%.4f, BB_Lower=%.4f, OBV=%.2f, OBV_prev=%.2f, ATR=%.4f",
         idx, cached_values.rsi, cached_values.bb_upper, cached_values.bb_lower, cached_values.obv, cached_values.obv_prev, cached_values.atr
      );
      Print(debug_info);
   }
   
   // Đánh dấu đã tải giá trị thành công
   cached_values.values_loaded = true;
   
   return true;
}

//+------------------------------------------------------------------+
//| Tính VWAP (Volume Weighted Average Price)                       |
//+------------------------------------------------------------------+
double CalculateVWAP(int period, int shift, const double &high[], const double &low[], 
                     const double &close[], const long &tick_volume[])
{
   double sum_pv = 0.0;   // Tổng Price * Volume
   double sum_v = 0.0;    // Tổng Volume
   
   // Log debug thông tin đầu vào
   if(MQLInfoInteger(MQL_DEBUG))
   {
      Print("CalculateVWAP: period=", period, ", shift=", shift, ", ArraySize(close)=", ArraySize(close));
   }
   
   // Đảm bảo không vượt quá giới hạn mảng và period > 0
   if(period <= 0 || shift < 0 || ArraySize(close) == 0)
   {
      Print("CalculateVWAP: Tham số không hợp lệ: period=", period, ", shift=", shift, ", ArraySize(close)=", ArraySize(close));
      return 0.0;
   }
   
   int count = 0;
   int bars_to_process = MathMin(period, ArraySize(close) - shift);
   
   if(bars_to_process <= 0)
   {
      Print("CalculateVWAP: Không đủ dữ liệu: bars_to_process=", bars_to_process);
      return 0.0;
   }
   
   // Cảnh báo nếu có thể xảy ra tràn bộ nhớ với volume quá lớn
   if(MQLInfoInteger(MQL_DEBUG))
   {
      bool has_large_volume = false;
      for(int i = shift; i < shift + bars_to_process; i++)
      {
         if(tick_volume[i] > 100000000) // 100 triệu
         {
            has_large_volume = true;
            break;
         }
      }
      
      if(has_large_volume)
      {
         Print("Cảnh báo: Phát hiện volume rất lớn trong dữ liệu VWAP");
      }
   }
   
   // Xử lý từng nến
   for(int i = shift; i < shift + bars_to_process; i++)
   {
      double typical_price = (high[i] + low[i] + close[i]) / 3.0;
      
      if(tick_volume[i] > 0)
      {
         double volume_value = 0.0;
         
         // Phương pháp an toàn để chuyển đổi long -> double với volume lớn
         if(tick_volume[i] > 1000000000L) // Chỉ định rõ là hằng số Long (> 1 tỷ)
         {
            // Phân tách thành các phần nhỏ để duy trì độ chính xác
            long billions = tick_volume[i] / 1000000000L;
            long millions = (tick_volume[i] % 1000000000L) / 1000000L;
            long remainder = tick_volume[i] % 1000000L;
            
            // Chuyển đổi và kết hợp
            volume_value = ((double)billions * 1000000000.0) + 
                           ((double)millions * 1000000.0) + 
                           (double)remainder;
            
            if(MQLInfoInteger(MQL_DEBUG))
            {
               Print("Volume lớn xử lý: ", tick_volume[i], " -> ", volume_value,
                     " (billions=", billions, ", millions=", millions, ", remainder=", remainder, ")");
            }
         }
         else
         {
            // Chuyển đổi trực tiếp với volume nhỏ hơn
            volume_value = (double)tick_volume[i];
         }
         
         // Sử dụng giá trị đã chuyển đổi
         sum_pv += typical_price * volume_value;
         sum_v += volume_value;
      }
      
      count++;
   }
   
   // Kiểm tra an toàn trước khi chia
   if(MathAbs(sum_v) < 0.000001 || count == 0)
   {
      if(MQLInfoInteger(MQL_DEBUG))
      {
         Print("CalculateVWAP: Không thể tính VWAP, sum_v=", sum_v, ", count=", count);
      }
      return 0.0;
   }
   
   double vwap = sum_pv / sum_v;
   
   // Log giá trị VWAP cho debug
   if(MQLInfoInteger(MQL_DEBUG) && MathMod(shift, 50) == 0) // Chỉ log mỗi 50 nến để tránh quá nhiều log
   {
      Print("CalculateVWAP (shift=", shift, "): vwap=", vwap, ", sum_pv=", sum_pv, ", sum_v=", sum_v, ", count=", count);
   }
   
   return vwap;
}

//+------------------------------------------------------------------+
//| Hàm tính toán indicator                                         |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Log thông tin về phiên tính toán
   if(prev_calculated == 0)
   {
      LogDebugInfo("OnCalculate: Đang khởi tạo lần đầu tiên. rates_total=" + IntegerToString(rates_total));
   }
   else if(MathMod(prev_calculated, 100) == 0) // Log mỗi 100 lần tính toán để tránh quá nhiều log
   {
      LogDebugInfo("OnCalculate: prev_calculated=" + IntegerToString(prev_calculated) + 
                   ", rates_total=" + IntegerToString(rates_total));
   }
      
   // Kiểm tra input không hợp lệ
   if(rates_total <= 0)
   {
      LogDebugInfo("OnCalculate: rates_total không hợp lệ (" + IntegerToString(rates_total) + ")");
      return(0);
   }
      
   // Thiết lập dữ liệu mảng về chế độ series trước khi sử dụng
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(tick_volume, true);
   ArraySetAsSeries(volume, true);
   
   // Kiểm tra đủ dữ liệu để tính toán
   int required_bars = MathMax(MathMax(VWAP_Period, BB_Period), RSI_Period);
   if(rates_total < required_bars)
   {
      LogDebugInfo("OnCalculate: Không đủ dữ liệu. rates_total=" + IntegerToString(rates_total) + 
                   ", required_bars=" + IntegerToString(required_bars));
      return(0);
   }
      
   // Xác định điểm bắt đầu tính toán
   int start;
   if(prev_calculated == 0)
   {
      start = required_bars + 10; // Bắt đầu với một số lệch để indicator tính toán chính xác
      LogDebugInfo("OnCalculate: Bắt đầu từ đầu tại vị trí " + IntegerToString(start));
   }
   else
   {
      start = prev_calculated - 1;
      LogDebugInfo("OnCalculate: Tiếp tục tính toán từ vị trí " + IntegerToString(start));
   }
      
   // Giới hạn điểm bắt đầu để đảm bảo đủ dữ liệu
   if(start < required_bars)
   {
      start = required_bars;
      LogDebugInfo("OnCalculate: Điều chỉnh vị trí bắt đầu thành " + IntegerToString(start));
   }
      
   // Quản lý bộ nhớ tốt hơn, chỉ lấy số lượng nến cần thiết
   int buffer_size = MathMin(rates_total, 1000); // Chỉ lấy 1000 nến gần nhất
   buffer_size = MathMax(buffer_size, required_bars + 10); // Đảm bảo đủ dữ liệu
   
   // Phòng tránh buffer_size quá lớn gây tràn bộ nhớ
   if(buffer_size > 10000)
   {
      LogDebugInfo("Cảnh báo: buffer_size quá lớn (" + IntegerToString(buffer_size) + 
                   "), giới hạn xuống 10000");
      buffer_size = 10000;
   }
   
   // Kiểm tra xem có đủ bộ nhớ cho các mảng không
   double rsi_values[];
   double bb_upper[];
   double bb_middle[];
   double bb_lower[];
   double obv_values[];
   
   // Cấp phát bộ nhớ cho các mảng và thiết lập chế độ series
   ArraySetAsSeries(rsi_values, true);
   ArraySetAsSeries(bb_upper, true);
   ArraySetAsSeries(bb_middle, true);
   ArraySetAsSeries(bb_lower, true);
   ArraySetAsSeries(obv_values, true);
   
   if(!ArrayResize(rsi_values, buffer_size) ||
      !ArrayResize(bb_upper, buffer_size) ||
      !ArrayResize(bb_middle, buffer_size) ||
      !ArrayResize(bb_lower, buffer_size) ||
      !ArrayResize(obv_values, buffer_size))
   {
      int error = GetLastError();
      LogDebugInfo("Lỗi cấp phát bộ nhớ cho mảng: " + IntegerToString(error));
      return(0);
   }
   
   // Sao chép giá trị của các indicator
   bool indicators_copied = true;
   int error = 0;
   
   if(CopyBuffer(RSI_Handle, 0, 0, buffer_size, rsi_values) <= 0)
   {
      error = GetLastError();
      LogDebugInfo("Lỗi sao chép RSI buffer: " + IntegerToString(error));
      indicators_copied = false;
   }
   
   if(CopyBuffer(BB_Handle, 0, 0, buffer_size, bb_middle) <= 0)
   {
      error = GetLastError();
      LogDebugInfo("Lỗi sao chép BB_Middle buffer: " + IntegerToString(error));
      indicators_copied = false;
   }
   
   if(CopyBuffer(BB_Handle, 1, 0, buffer_size, bb_upper) <= 0)
   {
      error = GetLastError();
      LogDebugInfo("Lỗi sao chép BB_Upper buffer: " + IntegerToString(error));
      indicators_copied = false;
   }
   
   if(CopyBuffer(BB_Handle, 2, 0, buffer_size, bb_lower) <= 0)
   {
      error = GetLastError();
      LogDebugInfo("Lỗi sao chép BB_Lower buffer: " + IntegerToString(error));
      indicators_copied = false;
   }
   
   if(CopyBuffer(OBV_Handle, 0, 0, buffer_size, obv_values) <= 0)
   {
      error = GetLastError();
      LogDebugInfo("Lỗi sao chép OBV buffer: " + IntegerToString(error));
      indicators_copied = false;
   }
   
   if(!indicators_copied)
   {
      // Log thêm thông tin hữu ích cho debugging
      LogDebugInfo("Thông tin thêm: Buffer size=" + IntegerToString(buffer_size) + 
                   ", Rates total=" + IntegerToString(rates_total), true);
      
      // Khôi phục các indicator handle nếu chúng không hợp lệ
      bool handles_recovered = false;
      
      if(RSI_Handle == INVALID_HANDLE)
      {
         RSI_Handle = CreateRSIHandle();
         if(RSI_Handle != INVALID_HANDLE)
         {
            LogDebugInfo("RSI handle đã được khôi phục");
            handles_recovered = true;
         }
      }
      
      if(BB_Handle == INVALID_HANDLE)
      {
         BB_Handle = CreateBollingerBandsHandle();
         if(BB_Handle != INVALID_HANDLE)
         {
            LogDebugInfo("BB handle đã được khôi phục");
            handles_recovered = true;
         }
      }
      
      if(OBV_Handle == INVALID_HANDLE)
      {
         OBV_Handle = CreateOBVHandle();
         if(OBV_Handle != INVALID_HANDLE)
         {
            LogDebugInfo("OBV handle đã được khôi phục");
            handles_recovered = true;
         }
      }
      
      if(ATR_Handle == INVALID_HANDLE)
      {
         ATR_Handle = CreateATRHandle(ATR_Period);
         if(ATR_Handle != INVALID_HANDLE)
         {
            LogDebugInfo("ATR handle đã được khôi phục");
            handles_recovered = true;
         }
      }
      
      if(ATR_Base_Handle == INVALID_HANDLE)
      {
         ATR_Base_Handle = CreateATRHandle(ATR_Base_Period);
         if(ATR_Base_Handle != INVALID_HANDLE)
         {
            LogDebugInfo("ATR_Base handle đã được khôi phục");
            handles_recovered = true;
         }
      }
      
      // Nếu đã khôi phục handle, thử tính toán lại ở lần gọi tiếp theo
      if(handles_recovered)
      {
         LogDebugInfo("Đã khôi phục một số handles, sẽ thử lại ở lần gọi OnCalculate tiếp theo");
         return(prev_calculated);
      }
      
      return(0);
   }
   
   // Vòng lặp tính toán chính
   for(int i = start; i < rates_total; i++)
   {
      // Tính VWAP
      VWAP_Buffer[i] = CalculateVWAP(VWAP_Period, i, high, low, close, tick_volume);
      
      // Tối ưu vòng lặp bằng cách tính idx một lần
      int idx = rates_total - i - 1;
      if(idx < 0 || idx >= buffer_size)
      {
         if(MathMod(i, 1000) == 0) // Chỉ log mỗi 1000 lần để tránh quá nhiều log
         {
            LogDebugInfo("Cảnh báo: Chỉ số idx không hợp lệ: idx=" + IntegerToString(idx) + 
                         ", i=" + IntegerToString(i) + ", rates_total=" + IntegerToString(rates_total) + 
                         ", buffer_size=" + IntegerToString(buffer_size));
         }
         continue; // Tránh truy cập ngoài phạm vi
      }
      
      // Tải tất cả giá trị indicator cho chu kỳ hiện tại
      bool indicators_loaded = LoadIndicatorValues(close, idx, buffer_size);
      
      // Cập nhật VWAP vào cache
      cached_values.vwap = VWAP_Buffer[i];
      
      // Sao chép giá trị BB vào buffer hiển thị
      BB_Upper_Buffer[i] = bb_upper[idx];
      BB_Middle_Buffer[i] = bb_middle[idx];
      BB_Lower_Buffer[i] = bb_lower[idx];
      
      // Tính histogram RSI để hiển thị
      RSI_Histogram_Buffer[i] = rsi_values[idx] - 50; // Căn giữa ở mức 50
      
      // Xác định màu cho RSI: 0 = Quá bán (xanh lá), 1 = Trung tính (xám), 2 = Quá mua (đỏ)
      if(indicators_loaded)
      {
         if(cached_values.rsi < RSI_Oversold)
            RSI_Color_Buffer[i] = 0; // Quá bán
         else if(cached_values.rsi > RSI_Overbought)
            RSI_Color_Buffer[i] = 2; // Quá mua
         else
            RSI_Color_Buffer[i] = 1; // Trung tính
         
         // Kiểm tra tín hiệu mua - sử dụng giá trị đã cache
         if(close[i] < cached_values.vwap && 
            cached_values.rsi < RSI_Oversold && 
            close[i] < cached_values.bb_lower && 
            cached_values.obv > cached_values.obv_prev &&
            (i == rates_total - 1 || time[i] != lastBuySignalTime)) // Fix lỗi logic
         {
            Buy_Signal_Buffer[i] = low[i] - 10 * _Point; // Đặt bên dưới nến
            lastBuySignalTime = time[i];
            
            // Hiển thị cảnh báo nếu được bật
            if(ShowAlerts && i == rates_total - 1 && TimeCurrent() - lastAlertTime > 300) // Giới hạn 1 cảnh báo mỗi 5 phút
            {
               string alertText = _Symbol + " " + EnumToString(PERIOD_CURRENT) + ": Tín hiệu MUA Triple Confirmation";
               Alert(alertText);
               lastAlertTime = TimeCurrent();
               
               // Log thông tin chi tiết về tín hiệu
               LogDebugInfo("TÍN HIỆU MUA được phát hiện tại giá " + DoubleToString(close[i], _Digits), true);
            }
         }
         else
         {
            Buy_Signal_Buffer[i] = EMPTY_VALUE;
         }
         
         // Kiểm tra tín hiệu bán - sử dụng giá trị đã cache
         if(close[i] > cached_values.vwap && 
            cached_values.rsi > RSI_Overbought && 
            close[i] > cached_values.bb_upper && 
            cached_values.obv < cached_values.obv_prev &&
            (i == rates_total - 1 || time[i] != lastSellSignalTime)) // Fix lỗi logic
         {
            Sell_Signal_Buffer[i] = high[i] + 10 * _Point; // Đặt bên trên nến
            lastSellSignalTime = time[i];
            
            // Hiển thị cảnh báo nếu được bật
            if(ShowAlerts && i == rates_total - 1 && TimeCurrent() - lastAlertTime > 300) // Giới hạn 1 cảnh báo mỗi 5 phút
            {
               string alertText = _Symbol + " " + EnumToString(PERIOD_CURRENT) + ": Tín hiệu BÁN Triple Confirmation";
               Alert(alertText);
               lastAlertTime = TimeCurrent();
               
               // Log thông tin chi tiết về tín hiệu
               LogDebugInfo("TÍN HIỆU BÁN được phát hiện tại giá " + DoubleToString(close[i], _Digits), true);
            }
         }
         else
         {
            Sell_Signal_Buffer[i] = EMPTY_VALUE;
         }
      }
      else
      {
         // Fallback khi không load được indicator values - sử dụng mảng đã copy
         if(rsi_values[idx] < RSI_Oversold)
            RSI_Color_Buffer[i] = 0; // Quá bán
         else if(rsi_values[idx] > RSI_Overbought)
            RSI_Color_Buffer[i] = 2; // Quá mua
         else
            RSI_Color_Buffer[i] = 1; // Trung tính
         
         // Fallback cho tín hiệu mua/bán sử dụng giá trị từ mảng
         // (giữ lại code cũ như là fallback)
         if(close[i] < VWAP_Buffer[i] && 
            idx < ArraySize(rsi_values) && rsi_values[idx] < RSI_Oversold && 
            close[i] < BB_Lower_Buffer[i] && 
            idx < ArraySize(obv_values) - 1 && obv_values[idx] > obv_values[idx+1] &&
            (i == rates_total - 1 || time[i] != lastBuySignalTime))
         {
            Buy_Signal_Buffer[i] = low[i] - 10 * _Point;
            lastBuySignalTime = time[i];
            
            if(ShowAlerts && i == rates_total - 1 && TimeCurrent() - lastAlertTime > 300)
            {
               string alertText = _Symbol + " " + EnumToString(PERIOD_CURRENT) + ": Tín hiệu MUA Triple Confirmation";
               Alert(alertText);
               lastAlertTime = TimeCurrent();
               
               // Log chi tiết về việc sử dụng fallback
               LogDebugInfo("FALLBACK: TÍN HIỆU MUA được phát hiện với phương thức dự phòng");
            }
         }
         else
         {
            Buy_Signal_Buffer[i] = EMPTY_VALUE;
         }
         
         if(close[i] > VWAP_Buffer[i] && 
            idx < ArraySize(rsi_values) && rsi_values[idx] > RSI_Overbought && 
            close[i] > BB_Upper_Buffer[i] && 
            idx < ArraySize(obv_values) - 1 && obv_values[idx] < obv_values[idx+1] &&
            (i == rates_total - 1 || time[i] != lastSellSignalTime))
         {
            Sell_Signal_Buffer[i] = high[i] + 10 * _Point;
            lastSellSignalTime = time[i];
            
            if(ShowAlerts && i == rates_total - 1 && TimeCurrent() - lastAlertTime > 300)
            {
               string alertText = _Symbol + " " + EnumToString(PERIOD_CURRENT) + ": Tín hiệu BÁN Triple Confirmation";
               Alert(alertText);
               lastAlertTime = TimeCurrent();
               
               // Log chi tiết về việc sử dụng fallback
               LogDebugInfo("FALLBACK: TÍN HIỆU BÁN được phát hiện với phương thức dự phòng");
            }
         }
         else
         {
            Sell_Signal_Buffer[i] = EMPTY_VALUE;
         }
      }
   }
   
   // Log kết quả tính toán nếu đang ở chế độ debug và đây là nến mới nhất
   if(MQLInfoInteger(MQL_DEBUG) && rates_total > 0)
   {
      int last_idx = rates_total - 1;
      if(Buy_Signal_Buffer[last_idx] != EMPTY_VALUE || Sell_Signal_Buffer[last_idx] != EMPTY_VALUE)
      {
         string signal_type = (Buy_Signal_Buffer[last_idx] != EMPTY_VALUE) ? "MUA" : "BÁN";
         LogDebugInfo("Kết quả tính toán: Phát hiện tín hiệu " + signal_type + " tại nến cuối cùng", true);
      }
      else if(MathMod(rates_total, 100) == 0) // Log định kỳ
      {
         LogDebugInfo("Kết quả tính toán: Đã xử lý " + IntegerToString(rates_total) + " nến, không có tín hiệu mới");
      }
   }
   
   // Trả về giá trị prev_calculated cho lần gọi tiếp theo
   return(rates_total);
}

// Hàm GetErrorDescription đã được xóa vì gây ra lỗi biên dịch
// End of indicator

//+------------------------------------------------------------------+
//| Hàm log thông tin debug chi tiết                                |
//+------------------------------------------------------------------+
void LogDebugInfo(string message, bool includeIndicatorValues = false)
{
   // Chỉ log khi ở chế độ debug
   if(!MQLInfoInteger(MQL_DEBUG))
      return;
      
   string log_message = TimeToString(TimeCurrent()) + ": " + message;
   
   // Thêm thông tin về các giá trị indicator hiện tại
   if(includeIndicatorValues && cached_values.values_loaded)
   {
      log_message += StringFormat(
         "\nRSI: %.2f | VWAP: %.4f | BB Upper: %.4f | BB Middle: %.4f | BB Lower: %.4f | OBV: %.2f | OBV_prev: %.2f | ATR: %.4f",
         cached_values.rsi,
         cached_values.vwap,
         cached_values.bb_upper,
         cached_values.bb_middle,
         cached_values.bb_lower,
         cached_values.obv,
         cached_values.obv_prev,
         cached_values.atr
      );
   }
   
   // Kiểm tra các handles
   if(includeIndicatorValues)
   {
      log_message += "\nHandle Status: ";
      log_message += (RSI_Handle != INVALID_HANDLE) ? "RSI(valid) " : "RSI(INVALID) ";
      log_message += (BB_Handle != INVALID_HANDLE) ? "BB(valid) " : "BB(INVALID) ";
      log_message += (OBV_Handle != INVALID_HANDLE) ? "OBV(valid) " : "OBV(INVALID) ";
      log_message += (ATR_Handle != INVALID_HANDLE) ? "ATR(valid) " : "ATR(INVALID) ";
      log_message += (ATR_Base_Handle != INVALID_HANDLE) ? "ATR_Base(valid)" : "ATR_Base(INVALID)";
   }
   
   Print(log_message);
   
   // Có thể thêm code ghi ra file log nếu cần
   // FileWrite(log_handle, log_message);
}