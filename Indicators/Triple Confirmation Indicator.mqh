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

// Biến toàn cục
datetime lastAlertTime = 0;
datetime lastBuySignalTime = 0;
datetime lastSellSignalTime = 0;

//+------------------------------------------------------------------+
//| Hàm khởi tạo indicator                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // Thiết lập các buffer của indicator
   SetIndexBuffer(0, VWAP_Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, BB_Upper_Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, BB_Middle_Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, BB_Lower_Buffer, INDICATOR_DATA);
   SetIndexBuffer(4, Buy_Signal_Buffer, INDICATOR_DATA);
   SetIndexBuffer(5, Sell_Signal_Buffer, INDICATOR_DATA);
   SetIndexBuffer(6, RSI_Histogram_Buffer, INDICATOR_DATA);
   SetIndexBuffer(7, RSI_Color_Buffer, INDICATOR_COLOR_INDEX);
   
   // Thiết lập mã mũi tên cho tín hiệu
   PlotIndexSetInteger(4, PLOT_ARROW, 233); // Mũi tên cho tín hiệu mua
   PlotIndexSetInteger(5, PLOT_ARROW, 234); // Mũi tên cho tín hiệu bán
   
   // Khởi tạo các buffer với giá trị rỗng
   ArrayInitialize(VWAP_Buffer, EMPTY_VALUE);
   ArrayInitialize(BB_Upper_Buffer, EMPTY_VALUE);
   ArrayInitialize(BB_Middle_Buffer, EMPTY_VALUE);
   ArrayInitialize(BB_Lower_Buffer, EMPTY_VALUE);
   ArrayInitialize(Buy_Signal_Buffer, EMPTY_VALUE);
   ArrayInitialize(Sell_Signal_Buffer, EMPTY_VALUE);
   ArrayInitialize(RSI_Histogram_Buffer, EMPTY_VALUE);
   ArrayInitialize(RSI_Color_Buffer, EMPTY_VALUE);
   
   // Lấy handle cho các indicator
   RSI_Handle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   BB_Handle = iBands(_Symbol, PERIOD_CURRENT, BB_Period, BB_Deviation, 0, PRICE_CLOSE);
   OBV_Handle = iOBV(_Symbol, PERIOD_CURRENT, VOLUME_TICK);
   
   // Kiểm tra các indicator đã được tạo thành công chưa
   if(RSI_Handle == INVALID_HANDLE || BB_Handle == INVALID_HANDLE || OBV_Handle == INVALID_HANDLE)
   {
      Print("Lỗi khi tạo indicator: ", GetLastError());
      return(INIT_FAILED);
   }
   
   // Thiết lập tên ngắn của indicator
   string short_name = "Triple Confirmation (VWAP, RSI, BB)";
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   
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
}

//+------------------------------------------------------------------+
//| Tính VWAP (Volume Weighted Average Price)                       |
//+------------------------------------------------------------------+
double CalculateVWAP(int period, int shift, const double &high[], const double &low[], 
                     const double &close[], const long &tick_volume[])
{
   double sum_pv = 0.0;   // Tổng Price * Volume
   double sum_v = 0.0;    // Tổng Volume
   
   // Đảm bảo không vượt quá giới hạn mảng
   int count = 0;
   for(int i = shift; i < shift + period && i < ArraySize(close); i++)
   {
      double typical_price = (high[i] + low[i] + close[i]) / 3.0;
      
      // Lưu giá trị trung gian với ép kiểu rõ ràng
      double volume = (double)tick_volume[i];  // Cast rõ ràng từ long sang double
      sum_pv += typical_price * volume;
      sum_v += volume;
      
      count++;
   }
   
   if(sum_v < 0.000001 || count == 0) // Sử dụng so sánh số thực an toàn hơn
      return 0.0;
      
   return sum_pv / sum_v;
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
   // Thiết lập dữ liệu mảng về chế độ series trước khi sử dụng
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(tick_volume, true);
   ArraySetAsSeries(volume, true);
   
   // Kiểm tra đủ dữ liệu để tính toán
   if(rates_total < VWAP_Period || rates_total < BB_Period || rates_total < RSI_Period)
      return(0);
      
   // Xác định điểm bắt đầu tính toán
   int start;
   if(prev_calculated == 0)
      start = VWAP_Period + 10; // Bắt đầu với một số lệch để indicator tính toán chính xác
   else
      start = prev_calculated - 1;
      
   // Giới hạn điểm bắt đầu để đảm bảo đủ dữ liệu
   if(start < VWAP_Period)
      start = VWAP_Period;
      
   // Chuẩn bị mảng cho các indicator
   double rsi_values[];
   double bb_upper[];
   double bb_middle[];
   double bb_lower[];
   double obv_values[];
   double obv_prev_values[];
   
   // Cấp phát bộ nhớ cho các mảng và thiết lập chế độ series
   ArraySetAsSeries(rsi_values, true);
   ArraySetAsSeries(bb_upper, true);
   ArraySetAsSeries(bb_middle, true);
   ArraySetAsSeries(bb_lower, true);
   ArraySetAsSeries(obv_values, true);
   ArraySetAsSeries(obv_prev_values, true);
   
   // Quản lý bộ nhớ tốt hơn, chỉ lấy số lượng nến cần thiết
   int buffer_size = MathMin(rates_total, 1000); // Chỉ lấy 1000 nến gần nhất
   
   ArrayResize(rsi_values, buffer_size);
   ArrayResize(bb_upper, buffer_size);
   ArrayResize(bb_middle, buffer_size);
   ArrayResize(bb_lower, buffer_size);
   ArrayResize(obv_values, buffer_size);
   ArrayResize(obv_prev_values, buffer_size);
   
   // Sao chép giá trị của các indicator
   if(CopyBuffer(RSI_Handle, 0, 0, buffer_size, rsi_values) <= 0 ||
      CopyBuffer(BB_Handle, 0, 0, buffer_size, bb_middle) <= 0 ||
      CopyBuffer(BB_Handle, 1, 0, buffer_size, bb_upper) <= 0 ||
      CopyBuffer(BB_Handle, 2, 0, buffer_size, bb_lower) <= 0 ||
      CopyBuffer(OBV_Handle, 0, 0, buffer_size, obv_values) <= 0 ||
      CopyBuffer(OBV_Handle, 0, 1, buffer_size, obv_prev_values) <= 0)
   {
      Print("Lỗi khi sao chép buffer indicator: ", GetLastError());
      return(0);
   }
   
   // Vòng lặp tính toán chính
   for(int i = start; i < rates_total; i++)
   {
      // Tính VWAP
      VWAP_Buffer[i] = CalculateVWAP(VWAP_Period, i, high, low, close, tick_volume);
      
      // Tối ưu vòng lặp bằng cách tính idx một lần
      int idx = rates_total - i - 1;
      
      // Sao chép giá trị BB
      BB_Upper_Buffer[i] = bb_upper[idx];
      BB_Middle_Buffer[i] = bb_middle[idx];
      BB_Lower_Buffer[i] = bb_lower[idx];
      
      // Tính histogram RSI để hiển thị
      RSI_Histogram_Buffer[i] = rsi_values[idx] - 50; // Căn giữa ở mức 50
      
      // Xác định màu cho RSI: 0 = Quá bán (xanh lá), 1 = Trung tính (xám), 2 = Quá mua (đỏ)
      if(rsi_values[idx] < RSI_Oversold)
         RSI_Color_Buffer[i] = 0; // Quá bán
      else if(rsi_values[idx] > RSI_Overbought)
         RSI_Color_Buffer[i] = 2; // Quá mua
      else
         RSI_Color_Buffer[i] = 1; // Trung tính
      
      // Kiểm tra tín hiệu mua - fix lỗi logic khi kiểm tra trùng lặp tín hiệu
      if(close[i] < VWAP_Buffer[i] && 
         rsi_values[idx] < RSI_Oversold && 
         close[i] < BB_Lower_Buffer[i] && 
         obv_values[idx] > obv_prev_values[idx] &&
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
         }
      }
      else
      {
         Buy_Signal_Buffer[i] = EMPTY_VALUE;
      }
      
      // Kiểm tra tín hiệu bán - fix lỗi logic khi kiểm tra trùng lặp tín hiệu
      if(close[i] > VWAP_Buffer[i] && 
         rsi_values[idx] > RSI_Overbought && 
         close[i] > BB_Upper_Buffer[i] && 
         obv_values[idx] < obv_prev_values[idx] &&
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
         }
      }
      else
      {
         Sell_Signal_Buffer[i] = EMPTY_VALUE;
      }
   }
   
   // Trả về giá trị prev_calculated cho lần gọi tiếp theo
   return(rates_total);
}