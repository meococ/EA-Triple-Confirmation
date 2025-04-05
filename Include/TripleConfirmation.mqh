//+------------------------------------------------------------------+
//|                                      TripleConfirmation.mq5 |
//+------------------------------------------------------------------+
//|                                      TripleConfirmation.mq5 |
//|                        Copyright 2025, Your Company               |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   7

// Buffer indices for indicator plots
#property indicator_label1  "VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "BB Upper"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

#property indicator_label3  "BB Middle"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

#property indicator_label4  "BB Lower"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrRed
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

#property indicator_label5  "Buy Signal"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrLimeGreen
#property indicator_width5  3

#property indicator_label6  "Sell Signal"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrCrimson
#property indicator_width6  3

#property indicator_label7  "RSI Level"
#property indicator_type7   DRAW_COLOR_HISTOGRAM
#property indicator_color7  clrGreen,clrGray,clrRed
#property indicator_style7  STYLE_SOLID
#property indicator_width7  2

// Indicator input parameters
input int      VWAP_Period = 20;           // VWAP Period
input int      RSI_Period = 9;             // RSI Period
input int      RSI_Oversold = 35;          // RSI Oversold Level
input int      RSI_Overbought = 65;        // RSI Overbought Level
input int      BB_Period = 20;             // Bollinger Bands Period
input double   BB_Deviation = 2.0;         // Bollinger Bands Deviation

// Indicator buffers
double VWAP_Buffer[];
double BB_Upper_Buffer[];
double BB_Middle_Buffer[];
double BB_Lower_Buffer[];
double Buy_Signal_Buffer[];
double Sell_Signal_Buffer[];
double RSI_Histogram_Buffer[];
double RSI_Color_Buffer[];

// Indicator handles
int RSI_Handle;
int BB_Handle;
int OBV_Handle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator buffers
   SetIndexBuffer(0, VWAP_Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, BB_Upper_Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, BB_Middle_Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, BB_Lower_Buffer, INDICATOR_DATA);
   SetIndexBuffer(4, Buy_Signal_Buffer, INDICATOR_DATA);
   SetIndexBuffer(5, Sell_Signal_Buffer, INDICATOR_DATA);
   SetIndexBuffer(6, RSI_Histogram_Buffer, INDICATOR_DATA);
   SetIndexBuffer(7, RSI_Color_Buffer, INDICATOR_COLOR_INDEX);
   
   // Set arrow codes for signals
   PlotIndexSetInteger(4, PLOT_ARROW, 233); // Buy signal arrow
   PlotIndexSetInteger(5, PLOT_ARROW, 234); // Sell signal arrow
   
   // Initialize buffers with empty values
   ArrayInitialize(VWAP_Buffer, EMPTY_VALUE);
   ArrayInitialize(BB_Upper_Buffer, EMPTY_VALUE);
   ArrayInitialize(BB_Middle_Buffer, EMPTY_VALUE);
   ArrayInitialize(BB_Lower_Buffer, EMPTY_VALUE);
   ArrayInitialize(Buy_Signal_Buffer, EMPTY_VALUE);
   ArrayInitialize(Sell_Signal_Buffer, EMPTY_VALUE);
   ArrayInitialize(RSI_Histogram_Buffer, EMPTY_VALUE);
   ArrayInitialize(RSI_Color_Buffer, EMPTY_VALUE);
   
   // Get handles for indicators
   RSI_Handle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   BB_Handle = iBands(_Symbol, PERIOD_CURRENT, BB_Period, BB_Deviation, 0, PRICE_CLOSE);
   OBV_Handle = iOBV(_Symbol, PERIOD_CURRENT, VOLUME_TICK);
   
   // Check if indicators are created successfully
   if(RSI_Handle == INVALID_HANDLE || BB_Handle == INVALID_HANDLE || OBV_Handle == INVALID_HANDLE)
   {
      Print("Error creating indicators: ", GetLastError());
      return(INIT_FAILED);
   }
   
   // Set indicator name and short name
   string short_name = "Triple Confirmation (VWAP, RSI, BB)";
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(RSI_Handle != INVALID_HANDLE)
      IndicatorRelease(RSI_Handle);
      
   if(BB_Handle != INVALID_HANDLE)
      IndicatorRelease(BB_Handle);
      
   if(OBV_Handle != INVALID_HANDLE)
      IndicatorRelease(OBV_Handle);
}

//+------------------------------------------------------------------+
//| Calculate VWAP (Volume Weighted Average Price)                   |
//+------------------------------------------------------------------+
double CalculateVWAP(int period, int shift)
{
   double sum_pv = 0;   // Sum of Price * Volume
   double sum_v = 0;    // Sum of Volume
   
   for(int i = shift; i < shift + period; i++)
   {
      double typical_price = (High[i] + Low[i] + Close[i]) / 3;
      double volume = Volume[i];
      
      sum_pv += typical_price * volume;
      sum_v += volume;
   }
   
   if(sum_v == 0)
      return 0;
      
   return sum_pv / sum_v;
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   // Check if there's enough data to calculate
   if(rates_total < VWAP_Period || rates_total < BB_Period || rates_total < RSI_Period)
      return(0);
      
   // Define calculation start point
   int start;
   if(prev_calculated == 0)
      start = VWAP_Period + 10; // Start with some offset for indicators to calculate properly
   else
      start = prev_calculated - 1;
      
   // Limit start to ensure we have enough data
   if(start < VWAP_Period)
      start = VWAP_Period;
      
   // Prepare arrays for indicators
   double rsi_values[];
   double bb_upper[];
   double bb_middle[];
   double bb_lower[];
   double obv_values[];
   double obv_prev_values[];
   
   // Allocate memory for arrays
   ArraySetAsSeries(rsi_values, true);
   ArraySetAsSeries(bb_upper, true);
   ArraySetAsSeries(bb_middle, true);
   ArraySetAsSeries(bb_lower, true);
   ArraySetAsSeries(obv_values, true);
   ArraySetAsSeries(obv_prev_values, true);
   
   ArrayResize(rsi_values, rates_total);
   ArrayResize(bb_upper, rates_total);
   ArrayResize(bb_middle, rates_total);
   ArrayResize(bb_lower, rates_total);
   ArrayResize(obv_values, rates_total);
   ArrayResize(obv_prev_values, rates_total);
   
   // Copy indicator values
   if(CopyBuffer(RSI_Handle, 0, 0, rates_total, rsi_values) <= 0 ||
      CopyBuffer(BB_Handle, 0, 0, rates_total, bb_middle) <= 0 ||
      CopyBuffer(BB_Handle, 1, 0, rates_total, bb_upper) <= 0 ||
      CopyBuffer(BB_Handle, 2, 0, rates_total, bb_lower) <= 0 ||
      CopyBuffer(OBV_Handle, 0, 0, rates_total, obv_values) <= 0 ||
      CopyBuffer(OBV_Handle, 0, 1, rates_total, obv_prev_values) <= 0)
   {
      Print("Error copying indicator buffers: ", GetLastError());
      return(0);
   }
   
   // Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      // Calculate VWAP
      VWAP_Buffer[i] = CalculateVWAP(VWAP_Period, i);
      
      // Copy BB values
      BB_Upper_Buffer[i] = bb_upper[rates_total - i - 1];
      BB_Middle_Buffer[i] = bb_middle[rates_total - i - 1];
      BB_Lower_Buffer[i] = bb_lower[rates_total - i - 1];
      
      // Calculate RSI histogram for RSI visualization
      RSI_Histogram_Buffer[i] = rsi_values[rates_total - i - 1] - 50; // Center at 50
      
      // Set RSI color: 0 = Oversold (green), 1 = Neutral (gray), 2 = Overbought (red)
      if(rsi_values[rates_total - i - 1] < RSI_Oversold)
         RSI_Color_Buffer[i] = 0; // Oversold
      else if(rsi_values[rates_total - i - 1] > RSI_Overbought)
         RSI_Color_Buffer[i] = 2; // Overbought
      else
         RSI_Color_Buffer[i] = 1; // Neutral
      
      // Check for buy signal
      if(close[i] < VWAP_Buffer[i] && 
         rsi_values[rates_total - i - 1] < RSI_Oversold && 
         close[i] < BB_Lower_Buffer[i] && 
         obv_values[rates_total - i - 1] > obv_prev_values[rates_total - i - 1] &&
         (i == rates_total - 1 || Buy_Signal_Buffer[i-1] == EMPTY_VALUE)) // Avoid duplicate signals
      {
         Buy_Signal_Buffer[i] = low[i] - 10 * Point(); // Place below candle
      }
      else
      {
         Buy_Signal_Buffer[i] = EMPTY_VALUE;
      }
      
      // Check for sell signal
      if(close[i] > VWAP_Buffer[i] && 
         rsi_values[rates_total - i - 1] > RSI_Overbought && 
         close[i] > BB_Upper_Buffer[i] && 
         obv_values[rates_total - i - 1] < obv_prev_values[rates_total - i - 1] &&
         (i == rates_total - 1 || Sell_Signal_Buffer[i-1] == EMPTY_VALUE)) // Avoid duplicate signals
      {
         Sell_Signal_Buffer[i] = high[i] + 10 * Point(); // Place above candle
      }
      else
      {
         Sell_Signal_Buffer[i] = EMPTY_VALUE;
      }
   }
   
   // Return value of prev_calculated for next call
   return(rates_total);
}