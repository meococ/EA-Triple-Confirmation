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
   // Kiểm tra tham số đầu vào
   if(BB_Period <= 0 || RSI_Period <= 0 || VWAP_Period <= 0)
   {
      Print("Tham số chu kỳ không hợp lệ!");
      return(INIT_PARAMETERS_INCORRECT);
   }

   // Kiểm tra BB_Deviation
   if(BB_Deviation <= 0)
   {
      Print("Độ lệch BB phải lớn hơn 0!");
      return(INIT_PARAMETERS_INCORRECT);
   }

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
      Print("Lỗi khi thiết lập buffer indicator: ", GetLastError());
      return(INIT_FAILED);
   }
   
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
      
      if(tick_volume[i] > 0)
      {
         double vol_double = 0.0;
         
         // Sử dụng kỹ thuật chia nhỏ để giữ độ chính xác
         if(tick_volume[i] > 10000000000L) // Chỉ định rõ là hằng số Long
         {
            // Chia thành các phần để tránh mất mát khi chuyển đổi
            long billions = tick_volume[i] / 1000000000;
            long remaining = tick_volume[i] % 1000000000;
            vol_double = (double)billions * 1000000000.0 + (double)remaining;
         }
         else
         {
            vol_double = (double)tick_volume[i];
         }
         
         sum_pv += typical_price * vol_double;
         sum_v += vol_double;
      }
      
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
   // Kiểm tra input không hợp lệ
   if(rates_total <= 0)
      return(0);
      
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
   
   // Cấp phát bộ nhớ cho các mảng và thiết lập chế độ series
   ArraySetAsSeries(rsi_values, true);
   ArraySetAsSeries(bb_upper, true);
   ArraySetAsSeries(bb_middle, true);
   ArraySetAsSeries(bb_lower, true);
   ArraySetAsSeries(obv_values, true);
   
   // Quản lý bộ nhớ tốt hơn, chỉ lấy số lượng nến cần thiết
   int buffer_size = MathMin(rates_total, 1000); // Chỉ lấy 1000 nến gần nhất
   buffer_size = MathMax(buffer_size, VWAP_Period + 10); // Đảm bảo đủ dữ liệu
   
   // Phòng tránh buffer_size quá lớn gây tràn bộ nhớ
   if(buffer_size > 10000)
   {
      Print("Warning: buffer_size quá lớn (", buffer_size, "), giới hạn xuống 10000");
      buffer_size = 10000;
   }
   
   // Kiểm tra xem có đủ bộ nhớ cho các mảng không
   if(!ArrayResize(rsi_values, buffer_size) ||
      !ArrayResize(bb_upper, buffer_size) ||
      !ArrayResize(bb_middle, buffer_size) ||
      !ArrayResize(bb_lower, buffer_size) ||
      !ArrayResize(obv_values, buffer_size))
   {
      Print("Lỗi cấp phát bộ nhớ cho mảng: ", GetLastError());
      return(0);
   }
   
   // Sao chép giá trị của các indicator
   if(CopyBuffer(RSI_Handle, 0, 0, buffer_size, rsi_values) <= 0 ||
      CopyBuffer(BB_Handle, 0, 0, buffer_size, bb_middle) <= 0 ||
      CopyBuffer(BB_Handle, 1, 0, buffer_size, bb_upper) <= 0 ||
      CopyBuffer(BB_Handle, 2, 0, buffer_size, bb_lower) <= 0 ||
      CopyBuffer(OBV_Handle, 0, 0, buffer_size, obv_values) <= 0)
   {
      int error = GetLastError();
      string errorMsg = "Lỗi khi sao chép buffer indicator: " + IntegerToString(error);
      Print(errorMsg);
      
      // Log thêm thông tin hữu ích cho debugging
      Print("Buffer size: ", buffer_size, ", Rates total: ", rates_total);
      
      // Khôi phục các indicator handle nếu chúng không hợp lệ
      if(RSI_Handle == INVALID_HANDLE)
      {
         RSI_Handle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
         if(RSI_Handle != INVALID_HANDLE)
            Print("RSI handle đã được khôi phục");
      }
      
      if(BB_Handle == INVALID_HANDLE)
      {
         BB_Handle = iBands(_Symbol, PERIOD_CURRENT, BB_Period, BB_Deviation, 0, PRICE_CLOSE);
         if(BB_Handle != INVALID_HANDLE)
            Print("BB handle đã được khôi phục");
      }
      
      if(OBV_Handle == INVALID_HANDLE)
      {
         OBV_Handle = iOBV(_Symbol, PERIOD_CURRENT, VOLUME_TICK);
         if(OBV_Handle != INVALID_HANDLE)
            Print("OBV handle đã được khôi phục");
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
         continue; // Tránh truy cập ngoài phạm vi
      
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
         idx < ArraySize(rsi_values) && rsi_values[idx] < RSI_Oversold && 
         close[i] < BB_Lower_Buffer[i] && 
         idx < ArraySize(obv_values) - 1 && obv_values[idx] > obv_values[idx+1] &&
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
         idx < ArraySize(rsi_values) && rsi_values[idx] > RSI_Overbought && 
         close[i] > BB_Upper_Buffer[i] && 
         idx < ArraySize(obv_values) - 1 && obv_values[idx] < obv_values[idx+1] &&
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

// Hàm GetErrorDescription đã được xóa vì gây ra lỗi biên dịch
// End of indicator