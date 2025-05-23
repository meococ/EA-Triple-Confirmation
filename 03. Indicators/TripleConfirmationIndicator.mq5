//+------------------------------------------------------------------+
//|                 TripleConfirmationIndicator.mq5        |
//|                        Copyright 2025, Your Company              |
//|                                            https://yoursite.com  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"
#property version   "2.00" // Phiên bản cải tiến cho v2.0
#property indicator_chart_window
#property indicator_buffers 10 // Tăng lên 10 để thêm buffer chất lượng setup
#property indicator_plots   8  // Giữ nguyên 8 plots vì buffer mới không cần hiển thị

// --- Cài đặt hiển thị của indicator ---
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

// Plot 8 (index 7) cấu hình cho ATR, không hiển thị trực quan
#property indicator_label8  "ATR Data"
#property indicator_type8   DRAW_NONE

// --- Tham số đầu vào của indicator ---
input int    VWAP_Period     = 20;    // Chu kỳ VWAP
input int    RSI_Period      = 14;    // Chu kỳ RSI
input double RSI_Lower       = 30;    // Ngưỡng quá bán RSI
input double RSI_Upper       = 70;    // Ngưỡng quá mua RSI
input int    BB_Period       = 20;    // Chu kỳ Bollinger Bands
input double BB_Deviation    = 2.0;   // Độ lệch chuẩn BB
input int    ATR_Period      = 14;    // Chu kỳ ATR
input bool   ShowAlerts      = false; // Hiển thị cảnh báo
input double VWAP_Min_Distance = 0.5; // Khoảng cách VWAP tối thiểu (ATR) - Thêm mới từ v2.0

// Định nghĩa enum cho chất lượng setup - Phù hợp với EA
enum ENUM_SETUP_QUALITY {
   SETUP_QUALITY_NONE = 0,  // Không có setup
   SETUP_QUALITY_C    = 1,  // Setup chất lượng C
   SETUP_QUALITY_B    = 2,  // Setup chất lượng B
   SETUP_QUALITY_A    = 3,  // Setup chất lượng A
   SETUP_QUALITY_A_PLUS = 4 // Setup chất lượng A+
};

// --- Buffers của indicator ---
double VWAP_Buffer[];           // Buffer 0
double BB_Upper_Buffer[];       // Buffer 1
double BB_Middle_Buffer[];      // Buffer 2
double BB_Lower_Buffer[];       // Buffer 3
double Buy_Signal_Buffer[];     // Buffer 4 (Cho EA)
double Sell_Signal_Buffer[];    // Buffer 5 (Cho EA)
double RSI_Histogram_Buffer[];  // Buffer 6
double RSI_Color_Buffer[];      // Buffer 7
double ATR_Buffer[];            // Buffer 8 (Cho EA)
double Setup_Quality_Buffer[];  // Buffer 9 (Mới: Cho EA lấy chất lượng setup)

// --- Handles của các indicator ---
int RSI_Handle = INVALID_HANDLE;
int BB_Handle = INVALID_HANDLE;
int OBV_Handle = INVALID_HANDLE;
int ATR_Handle = INVALID_HANDLE;

// --- Biến toàn cục ---
datetime lastAlertTime = 0;
datetime lastBuySignalTime = 0;
datetime lastSellSignalTime = 0;

//+------------------------------------------------------------------+
//| Hàm tạo Handle với kiểm tra và logging                          |
//+------------------------------------------------------------------+
int CreateIndicatorHandle(string funcName, int handleType, int period1, double period2 = 0)
{
   Print("CreateHandle: Attempting to create ", funcName, " handle...");
   int handle = INVALID_HANDLE;
   string symbol = _Symbol;
   ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT;

   // Kiểm tra tham số cơ bản
   if(handleType != 1 && period1 <= 0)
   {
      Print("CreateHandle Error: ", funcName, " period (", period1, ") must be greater than 0!");
      return INVALID_HANDLE;
   }
   if(handleType == 2 && period2 <= 0.0) // Check deviation for BBands
   {
      Print("CreateHandle Error: ", funcName, " deviation (", period2, ") must be greater than 0!");
      return INVALID_HANDLE;
   }

   // Tạo handle dựa trên loại indicator
   switch(handleType)
   {
      case 0: // RSI
         Print("Creating RSI Handle with: Period=", period1);
         handle = iRSI(symbol, timeframe, period1, PRICE_CLOSE);
         break;
      case 1: // OBV
         Print("Creating OBV Handle");
         handle = iOBV(symbol, timeframe, VOLUME_TICK);
         break;
      case 2: // Bollinger Bands
         Print("Creating BB Handle with: Period=", period1, ", Deviation=", period2);
         handle = iBands(symbol, timeframe, period1, 0, period2, PRICE_CLOSE);
         break;
      case 3: // ATR
         Print("Creating ATR Handle with: Period=", period1);
         handle = iATR(symbol, timeframe, period1);
         break;
      default:
         Print("CreateHandle Error: Unknown handle type!");
         return INVALID_HANDLE;
   }

   // Kiểm tra kết quả
   if(handle == INVALID_HANDLE)
   {
      int error_code = GetLastError();
      Print("CreateHandle Error: Failed to create ", funcName, " Handle. Error: ", error_code);
      // Có thể thêm switch(error_code) để diễn giải lỗi nếu cần
   }
   else
   {
      Print("CreateHandle Success: ", funcName, " Handle created: ", handle);
   }
   return handle;
}

//+------------------------------------------------------------------+
//| Xác định chất lượng setup                                        |
//+------------------------------------------------------------------+
ENUM_SETUP_QUALITY DetermineSetupQuality(bool isBuy, double price, double vwap, double rsi, 
                                        double bbUpper, double bbLower, double obv, 
                                        double obvPrev, double atr)
{
   int confirmationCount = 0;
   
   if(isBuy) 
   {
      // VWAP xác nhận - sử dụng VWAP_Min_Distance
      double vwapDistance = MathAbs(price - vwap) / atr;
      if(vwapDistance > VWAP_Min_Distance) confirmationCount++;
      
      // RSI xác nhận mạnh
      if(rsi < 30) confirmationCount++;
      
      // BB xác nhận mạnh
      double bbDistance = MathAbs(price - bbLower) / atr;
      if(bbDistance > 0.3) confirmationCount++;
      
      // OBV xác nhận mạnh
      double obvChange = (obv - obvPrev) / (obvPrev != 0 ? obvPrev : 1) * 100;
      if(obvChange > 1.0) confirmationCount++;
   }
   else // Sell
   {
      // VWAP xác nhận - sử dụng VWAP_Min_Distance
      double vwapDistance = MathAbs(price - vwap) / atr;
      if(vwapDistance > VWAP_Min_Distance) confirmationCount++;
      
      // RSI xác nhận mạnh
      if(rsi > 70) confirmationCount++;
      
      // BB xác nhận mạnh
      double bbDistance = MathAbs(price - bbUpper) / atr;
      if(bbDistance > 0.3) confirmationCount++;
      
      // OBV xác nhận mạnh
      double obvChange = (obvPrev - obv) / (obvPrev != 0 ? obvPrev : 1) * 100;
      if(obvChange > 1.0) confirmationCount++;
   }
   
   // Xếp loại setup dựa trên số lượng xác nhận
   if(confirmationCount >= 4)
      return SETUP_QUALITY_A_PLUS;
   else if(confirmationCount == 3)
      return SETUP_QUALITY_A;
   else if(confirmationCount == 2)
      return SETUP_QUALITY_B;
   else if(confirmationCount == 1)
      return SETUP_QUALITY_C;
   else
      return SETUP_QUALITY_NONE;
}

//+------------------------------------------------------------------+
//| Hàm khởi tạo indicator                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("======= OnInit started: Checking parameters... =======");

   // Kiểm tra tham số đầu vào
   if(BB_Period <= 0 || RSI_Period <= 0 || VWAP_Period <= 0 || ATR_Period <= 0)
   {
      Print("Lỗi nghiêm trọng: Tham số chu kỳ không hợp lệ!");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(BB_Deviation <= 0)
   {
      Print("Lỗi nghiêm trọng: Độ lệch BB phải lớn hơn 0!");
      return(INIT_PARAMETERS_INCORRECT);
   }

   Print("Các tham số hợp lệ. Thiết lập index buffers...");

   // Thiết lập các buffer của indicator
   if(!SetIndexBuffer(0, VWAP_Buffer, INDICATOR_DATA) ||
      !SetIndexBuffer(1, BB_Upper_Buffer, INDICATOR_DATA) ||
      !SetIndexBuffer(2, BB_Middle_Buffer, INDICATOR_DATA) ||
      !SetIndexBuffer(3, BB_Lower_Buffer, INDICATOR_DATA) ||
      !SetIndexBuffer(4, Buy_Signal_Buffer, INDICATOR_DATA) ||    // Buffer tín hiệu Mua cho EA
      !SetIndexBuffer(5, Sell_Signal_Buffer, INDICATOR_DATA) ||   // Buffer tín hiệu Bán cho EA
      !SetIndexBuffer(6, RSI_Histogram_Buffer, INDICATOR_DATA) || // Buffer dữ liệu histogram RSI
      !SetIndexBuffer(7, RSI_Color_Buffer, INDICATOR_COLOR_INDEX) || // Buffer màu cho histogram RSI
      !SetIndexBuffer(8, ATR_Buffer, INDICATOR_DATA) ||           // Buffer dữ liệu ATR cho EA
      !SetIndexBuffer(9, Setup_Quality_Buffer, INDICATOR_DATA))   // Buffer mới: Chất lượng setup
   {
      int error = GetLastError();
      Print("Lỗi nghiêm trọng khi thiết lập buffer indicator: ", error);
      return(INIT_FAILED);
   }
   Print("Index buffers đã được thiết lập thành công. Thiết lập thuộc tính plot...");

   // --- Thiết lập thuộc tính cho các plot ---
   // Plot 0: VWAP (Đã định nghĩa trong #property)
   PlotIndexSetString(0, PLOT_LABEL, "VWAP");

   // Plot 1-3: Bollinger Bands (Đã định nghĩa trong #property)
   PlotIndexSetString(1, PLOT_LABEL, "BB Upper");
   PlotIndexSetString(2, PLOT_LABEL, "BB Middle");
   PlotIndexSetString(3, PLOT_LABEL, "BB Lower");

   // Plot 4: Buy Signal Arrow (Đã định nghĩa trong #property)
   PlotIndexSetInteger(4, PLOT_ARROW, 233); // Mũi tên lên
   PlotIndexSetInteger(4, PLOT_DRAW_BEGIN, MathMax(MathMax(VWAP_Period, BB_Period), RSI_Period));
   PlotIndexSetString(4, PLOT_LABEL, "Buy Signal");
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // Plot 5: Sell Signal Arrow (Đã định nghĩa trong #property)
   PlotIndexSetInteger(5, PLOT_ARROW, 234); // Mũi tên xuống
   PlotIndexSetInteger(5, PLOT_DRAW_BEGIN, MathMax(MathMax(VWAP_Period, BB_Period), RSI_Period));
   PlotIndexSetString(5, PLOT_LABEL, "Sell Signal");
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // Plot 6: RSI Histogram (Đã định nghĩa trong #property)
   PlotIndexSetString(6, PLOT_LABEL, "RSI Level");
   PlotIndexSetInteger(6, PLOT_DRAW_BEGIN, RSI_Period);

   // Plot 7: Buffer màu cho RSI Histogram (Không vẽ)

   // Plot 8 (index 7): Buffer dữ liệu ATR (Không vẽ)
   PlotIndexSetInteger(7, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetInteger(7, PLOT_DRAW_BEGIN, ATR_Period);
   PlotIndexSetString(7, PLOT_LABEL, "ATR Data");

   // Buffer 9: Chất lượng Setup (Không cần hiển thị)
   SetIndexBuffer(9, Setup_Quality_Buffer, INDICATOR_DATA);
   PlotIndexSetDouble(9, PLOT_EMPTY_VALUE, 0); // 0 = SETUP_QUALITY_NONE

   Print("Thuộc tính plot đã được thiết lập. Khởi tạo các buffer...");

   // Khởi tạo các buffer với giá trị rỗng
   ArrayInitialize(VWAP_Buffer, EMPTY_VALUE);
   ArrayInitialize(BB_Upper_Buffer, EMPTY_VALUE);
   ArrayInitialize(BB_Middle_Buffer, EMPTY_VALUE);
   ArrayInitialize(BB_Lower_Buffer, EMPTY_VALUE);
   ArrayInitialize(Buy_Signal_Buffer, EMPTY_VALUE);
   ArrayInitialize(Sell_Signal_Buffer, EMPTY_VALUE);
   ArrayInitialize(RSI_Histogram_Buffer, EMPTY_VALUE);
   ArrayInitialize(RSI_Color_Buffer, EMPTY_VALUE);
   ArrayInitialize(ATR_Buffer, EMPTY_VALUE);
   ArrayInitialize(Setup_Quality_Buffer, 0); // 0 = SETUP_QUALITY_NONE

   Print("Các buffer đã được khởi tạo. Bắt đầu tạo indicator handles...");

   // --- Tạo các indicator handles ---
   RSI_Handle = CreateIndicatorHandle("RSI", 0, RSI_Period);
   if(RSI_Handle == INVALID_HANDLE)
      return(INIT_FAILED);

   BB_Handle = CreateIndicatorHandle("Bollinger Bands", 2, BB_Period, BB_Deviation);
   if(BB_Handle == INVALID_HANDLE)
   {
      IndicatorRelease(RSI_Handle);
      return(INIT_FAILED);
   }

   OBV_Handle = CreateIndicatorHandle("OBV", 1, 0); // Period không dùng cho OBV
   if(OBV_Handle == INVALID_HANDLE)
   {
      IndicatorRelease(RSI_Handle);
      IndicatorRelease(BB_Handle);
      return(INIT_FAILED);
   }

   ATR_Handle = CreateIndicatorHandle("ATR", 3, ATR_Period);
   if(ATR_Handle == INVALID_HANDLE)
   {
      IndicatorRelease(RSI_Handle);
      IndicatorRelease(BB_Handle);
      IndicatorRelease(OBV_Handle);
      return(INIT_FAILED);
   }

   Print("Tất cả handles đã được tạo thành công!");

   // Thiết lập tên ngắn của indicator
   string short_name = "Triple Confirmation v2.0";
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
   Print("OnDeinit: Releasing handles...");
   // Giải phóng handle của indicator
   if(RSI_Handle != INVALID_HANDLE)
      IndicatorRelease(RSI_Handle);
   if(BB_Handle != INVALID_HANDLE)
      IndicatorRelease(BB_Handle);
   if(OBV_Handle != INVALID_HANDLE)
      IndicatorRelease(OBV_Handle);
   if(ATR_Handle != INVALID_HANDLE)
      IndicatorRelease(ATR_Handle);
   Print("OnDeinit: Handles released.");
}

//+------------------------------------------------------------------+
//| Tính VWAP (Volume Weighted Average Price)                      |
//+------------------------------------------------------------------+
double CalculateVWAP(int period, int shift, const double &high[], const double &low[],
                     const double &close[], const long &tick_volume[])
{
   double sum_pv = 0.0; // Tổng Price * Volume
   double sum_v = 0.0;  // Tổng Volume

   // Kiểm tra tham số và dữ liệu đầu vào
   if(period <= 0 || shift < 0 || ArraySize(close) == 0)
      return 0.0;

   int bars_to_process = MathMin(period, ArraySize(close) - shift);
   if(bars_to_process <= 0)
      return 0.0;

   // Xử lý từng nến
   for(int i = shift; i < shift + bars_to_process; i++)
   {
      // Kiểm tra index hợp lệ (mặc dù vòng lặp đã giới hạn)
      if(i >= ArraySize(close))
         continue;

      double typicalPrice = (high[i] + low[i] + close[i]) / 3.0;

      if(tick_volume[i] > 0)
      {
         double volume_value = (double)tick_volume[i]; // Chuyển đổi cơ bản, đủ dùng trong hầu hết trường hợp
         // Có thể thêm xử lý volume cực lớn như phiên bản trước nếu cần

         sum_pv += typicalPrice * volume_value;
         sum_v += volume_value;
      }
   }

   // Kiểm tra an toàn trước khi chia
   if(MathAbs(sum_v) < 0.000001)
      return 0.0; // Tránh chia cho 0

   return sum_pv / sum_v;
}

//+------------------------------------------------------------------+
//| Hàm tính toán indicator                                          |
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
   // --- 1. Kiểm tra dữ liệu đầu vào ---
   if(rates_total <= 0)
      return(0);

   // Kiểm tra handles hợp lệ, thử tạo lại nếu cần
   if(RSI_Handle == INVALID_HANDLE || BB_Handle == INVALID_HANDLE || OBV_Handle == INVALID_HANDLE || ATR_Handle == INVALID_HANDLE)
   {
      Print("OnCalculate Warning: Invalid handle detected, attempting to recreate...");
      OnInit(); // Thử gọi lại OnInit để tạo lại handles
      // Kiểm tra lại sau khi gọi OnInit
      if(RSI_Handle == INVALID_HANDLE || BB_Handle == INVALID_HANDLE || OBV_Handle == INVALID_HANDLE || ATR_Handle == INVALID_HANDLE)
      {
         Print("OnCalculate Error: Failed to recreate handles. Calculation stopped.");
         return 0; // Không thể tiếp tục nếu handle không hợp lệ
      }
   }

   // --- 2. Xác định phạm vi tính toán ---
   int required_bars = MathMax(MathMax(VWAP_Period, BB_Period), MathMax(RSI_Period, ATR_Period));
   if(rates_total < required_bars)
   {
      // Print("OnCalculate: Not enough bars for calculation. rates_total=", rates_total, ", required=", required_bars);
      return(0);
   }

   int start_bar; // Vị trí bắt đầu tính toán trong mảng rates (0 là nến mới nhất)
   if(prev_calculated == 0)
   {
      start_bar = rates_total - required_bars - 1; // Tính toán đủ số nến cần thiết ban đầu
      Print("OnCalculate: First calculation, starting from bar index ", start_bar);
   }
   else
   {
      start_bar = rates_total - prev_calculated; // Chỉ tính toán các nến mới hoặc thay đổi
   }
   // Đảm bảo không tính toán index âm
   start_bar = MathMax(0, start_bar);

   // --- 3. Sao chép dữ liệu từ indicator chuẩn (CopyBuffer) ---
   // Chỉ sao chép phần dữ liệu cần thiết để tính toán
   int bars_to_copy = rates_total - start_bar;
   // Thêm một số nến dự phòng cho các phép tính cần giá trị trước đó (như OBV)
   int copy_start_pos = start_bar;
   int copy_count = bars_to_copy + 1; // +1 để lấy giá trị OBV[i+1]

   // Đảm bảo không copy quá số lượng nến hiện có
   if(copy_start_pos + copy_count > rates_total)
   {
      copy_count = rates_total - copy_start_pos;
   }
   if(copy_count <= 0)  // Không có gì để copy
   {
      // Print("OnCalculate: No bars to copy. start_bar=", start_bar, ", rates_total=", rates_total);
      return rates_total; // Trả về rates_total vì không có lỗi nhưng không có gì mới
   }

   // Mảng tạm để lưu trữ dữ liệu sao chép
   double rsi_values[];
   double bb_upper[];
   double bb_middle[];
   double bb_lower[];
   double obv_values[];
   double atr_values[];

   // Cấp phát bộ nhớ và đặt chế độ series cho mảng tạm
   // Lưu ý: Dữ liệu từ CopyBuffer trả về theo thứ tự thông thường (0 là index xa nhất)
   ArraySetAsSeries(rsi_values, false);
   ArraySetAsSeries(bb_upper, false);
   ArraySetAsSeries(bb_middle, false);
   ArraySetAsSeries(bb_lower, false);
   ArraySetAsSeries(obv_values, false);
   ArraySetAsSeries(atr_values, false);

   if(!ArrayResize(rsi_values, copy_count) ||
      !ArrayResize(bb_upper, copy_count) ||
      !ArrayResize(bb_middle, copy_count) ||
      !ArrayResize(bb_lower, copy_count) ||
      !ArrayResize(obv_values, copy_count) || // Cần copy_count để lấy obv[idx+1]
      !ArrayResize(atr_values, copy_count))
   {
      Print("OnCalculate Error: Failed to resize temporary arrays. Error: ", GetLastError());
      return(0);
   }

   // Thực hiện sao chép
   bool copy_ok = true;
   if(CopyBuffer(RSI_Handle, 0, copy_start_pos, copy_count, rsi_values) <= 0)
      copy_ok = false;
   if(CopyBuffer(BB_Handle, 1, copy_start_pos, copy_count, bb_upper) <= 0)
      copy_ok = false; // Upper band is index 1
   if(CopyBuffer(BB_Handle, 0, copy_start_pos, copy_count, bb_middle) <= 0)
      copy_ok = false; // Middle band is index 0
   if(CopyBuffer(BB_Handle, 2, copy_start_pos, copy_count, bb_lower) <= 0)
      copy_ok = false; // Lower band is index 2
   if(CopyBuffer(OBV_Handle, 0, copy_start_pos, copy_count, obv_values) <= 0)
      copy_ok = false;
   if(CopyBuffer(ATR_Handle, 0, copy_start_pos, copy_count, atr_values) <= 0)
      copy_ok = false;

   if(!copy_ok)
   {
      Print("OnCalculate Error: Failed to copy indicator buffers. Error: ", GetLastError());
      // Có thể thử khôi phục handle ở đây nếu muốn, nhưng đơn giản là thoát
      return(0);
   }

   // --- 4. Vòng lặp tính toán chính ---
   // Lặp qua các nến cần tính toán (từ cũ đến mới)
   for(int i = start_bar; i < rates_total; i++)
   {
      // Tính VWAP cho nến i (VWAP cần dữ liệu quá khứ)
      // Lưu ý: Hàm CalculateVWAP cần index 'shift' là vị trí bắt đầu trong mảng gốc (0 là mới nhất)
      // Do đó, shift = rates_total - 1 - i
      int vwap_shift = rates_total - 1 - i;
      VWAP_Buffer[i] = CalculateVWAP(VWAP_Period, vwap_shift, high, low, close, tick_volume);

      // Lấy index tương ứng trong các mảng tạm đã copy (0 là index đầu tiên đã copy)
      int idx = i - start_bar;

      // Kiểm tra idx hợp lệ (dù không cần thiết nếu copy_count đúng)
      if(idx < 0 || idx >= copy_count)
         continue;

      // Lấy giá trị từ mảng tạm
      double rsi = rsi_values[idx];
      double bbUpper = bb_upper[idx];
      double bbMiddle = bb_middle[idx];
      double bbLower = bb_lower[idx];
      double obv = obv_values[idx];
      double obvPrev = (idx > 0) ? obv_values[idx - 1] : 0.0; // Lấy giá trị OBV trước đó từ mảng tạm
      double atr = atr_values[idx];

      // Gán giá trị cho các buffer hiển thị/dữ liệu
      BB_Upper_Buffer[i] = bbUpper;
      BB_Middle_Buffer[i] = bbMiddle;
      BB_Lower_Buffer[i] = bbLower;
      ATR_Buffer[i] = atr; // Gán giá trị ATR vào buffer 8

      // Tính histogram RSI để hiển thị
      RSI_Histogram_Buffer[i] = rsi - 50; // Căn giữa ở mức 50

      // Xác định màu cho RSI
      if(rsi < RSI_Lower)
         RSI_Color_Buffer[i] = 0; // Quá bán (Green)
      else
         if(rsi > RSI_Upper)
            RSI_Color_Buffer[i] = 2; // Quá mua (Red)
         else
            RSI_Color_Buffer[i] = 1; // Trung tính (Gray)

      // --- Logic kiểm tra tín hiệu Mua/Bán ---
      bool buy_condition = close[i] < VWAP_Buffer[i] &&
                           rsi < RSI_Lower &&
                           close[i] < bbLower &&
                           obv > obvPrev;

      bool sell_condition = close[i] > VWAP_Buffer[i] &&
                            rsi > RSI_Upper &&
                            close[i] > bbUpper &&
                            obv < obvPrev;

      // Đặt giá trị mặc định cho setup quality
      Setup_Quality_Buffer[i] = SETUP_QUALITY_NONE;
                            
      // Gán tín hiệu Mua (Buffer 4) và Tính chất lượng setup (Buffer 9)
      if(buy_condition)
      {
         // Chỉ đặt tín hiệu nếu nến trước đó không có tín hiệu (tránh lặp lại)
         // Hoặc nếu là nến hiện tại đang hình thành (i == rates_total - 1)
         if(i == 0 || Buy_Signal_Buffer[i-1] == EMPTY_VALUE || i == rates_total - 1)
         {
            // Đặt tín hiệu mua
            Buy_Signal_Buffer[i] = low[i] - 10 * _Point; // Đặt bên dưới nến
            
            // Đánh giá chất lượng setup cho MUA
            Setup_Quality_Buffer[i] = (double)DetermineSetupQuality(true, close[i], VWAP_Buffer[i], 
                                                            rsi, bbUpper, bbLower, obv, obvPrev, atr);
            
            // Cập nhật thời gian tín hiệu chỉ khi là nến mới nhất
            if(i == rates_total - 1)
               lastBuySignalTime = time[i];

            // Hiển thị cảnh báo nếu được bật và là nến mới nhất
            if(ShowAlerts && i == rates_total - 1 && TimeCurrent() - lastAlertTime > 300)
            {
               string setupQuality = "";
               switch((int)Setup_Quality_Buffer[i])
               {
                  case SETUP_QUALITY_A_PLUS: setupQuality = "A+"; break;
                  case SETUP_QUALITY_A: setupQuality = "A"; break;
                  case SETUP_QUALITY_B: setupQuality = "B"; break;
                  case SETUP_QUALITY_C: setupQuality = "C"; break;
                  default: setupQuality = "Unknown";
               }
               
               string alertText = _Symbol + " " + EnumToString(PERIOD_CURRENT) + 
                                ": Tín hiệu MUA Triple Confirmation (Chất lượng: " + setupQuality + ")";
               Alert(alertText);
               lastAlertTime = TimeCurrent();
            }
         }
         else
         {
            Buy_Signal_Buffer[i] = EMPTY_VALUE;
         }
      }
      else
      {
         Buy_Signal_Buffer[i] = EMPTY_VALUE;
      }

      // Gán tín hiệu Bán (Buffer 5) và Tính chất lượng setup (Buffer 9)
      if(sell_condition)
      {
         if(i == 0 || Sell_Signal_Buffer[i-1] == EMPTY_VALUE || i == rates_total - 1)
         {
            // Đặt tín hiệu bán
            Sell_Signal_Buffer[i] = high[i] + 10 * _Point; // Đặt bên trên nến
            
            // Đánh giá chất lượng setup cho BÁN
            Setup_Quality_Buffer[i] = (double)DetermineSetupQuality(false, close[i], VWAP_Buffer[i], 
                                                            rsi, bbUpper, bbLower, obv, obvPrev, atr);
            
            if(i == rates_total - 1)
               lastSellSignalTime = time[i];

            // Hiển thị cảnh báo nếu được bật và là nến mới nhất
            if(ShowAlerts && i == rates_total - 1 && TimeCurrent() - lastAlertTime > 300)
            {
               string setupQuality = "";
               switch((int)Setup_Quality_Buffer[i])
               {
                  case SETUP_QUALITY_A_PLUS: setupQuality = "A+"; break;
                  case SETUP_QUALITY_A: setupQuality = "A"; break;
                  case SETUP_QUALITY_B: setupQuality = "B"; break;
                  case SETUP_QUALITY_C: setupQuality = "C"; break;
                  default: setupQuality = "Unknown";
               }
               
               string alertText = _Symbol + " " + EnumToString(PERIOD_CURRENT) + 
                                ": Tín hiệu BÁN Triple Confirmation (Chất lượng: " + setupQuality + ")";
               Alert(alertText);
               lastAlertTime = TimeCurrent();
            }
         }
         else
         {
            Sell_Signal_Buffer[i] = EMPTY_VALUE;
         }
      }
      else
      {
         Sell_Signal_Buffer[i] = EMPTY_VALUE;
      }
   }

   // --- 5. Trả về số lượng thanh đã tính toán ---
   return(rates_total);
}
//+------------------------------------------------------------------+