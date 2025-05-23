//+------------------------------------------------------------------+
//|                                                 Dashboard.mqh |
//|                        Copyright 2025, Your Company               |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"

// Include các thư viện cần thiết
#include <Trade\Trade.mqh>  // Thư viện giao dịch cơ bản
#include "TradeManager.mqh" // Thư viện quản lý giao dịch

// Class cơ sở cho tất cả các dashboard
class CDashboardBase
{
protected:
   string            m_name;
   int               m_x;
   int               m_y;
   
public:
   CDashboardBase() { m_name = "Dashboard"; m_x = 10; m_y = 10; }
   
   virtual bool Init(string name, int x, int y)
   {
      m_name = name;
      m_x = x;
      m_y = y;
      return true;
   }
   
   virtual void Deinit() {}
   virtual void Update() {}
};

// MQL5 có sẵn các enum cho style
// - OBJPROP_STYLE chỉ dùng cho các line, không dùng cho font (STYLE_SOLID(0), STYLE_DASH(1)...)
// - Để làm font in đậm, ta tăng font size thay vì dùng style
// Lưu ý: Trong MQL4/MQL5, các hằng số style cho font và line là khác nhau

// Class hiển thị dashboard tổng quan cho tất cả EA
class CDashboard
{
private:
   string            m_name;
   int               m_x;
   int               m_y;
   int               m_width;
   int               m_height;
   color             m_textColor;
   color             m_bgColor;
   color             m_borderColor;
   color             m_profitColor;
   color             m_lossColor;
   int               m_fontSize;
   string            m_objNamePrefix;
   
   // Tạo đối tượng text trên chart
   bool CreateLabel(string name, string text, int x, int y, color textColor, int fontSize, bool bold = false)
   {
      if(ObjectFind(0, name) >= 0)
         ObjectDelete(0, name);
      
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
      {
         Print("Failed to create label: ", name, " Error: ", GetLastError());
         return false;
      }
      
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      
      // Thay đổi cách xử lý chữ in đậm
      if(bold)
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize + 1); // Tăng font size thay vì dùng bold
      else
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
         
      // Sử dụng OBJPROP_STYLE để thiết lập kiểu đường (không phải font style)
      ObjectSetInteger(0, name, OBJPROP_STYLE, 0); // 0 = STYLE_SOLID
      
      return true;
   }
   
   // Tạo đối tượng hình chữ nhật trên chart
   bool CreateRectangle(string name, int x1, int y1, int x2, int y2, color bgColor, color borderColor, int width = 1)
   {
      if(ObjectFind(0, name) >= 0)
         ObjectDelete(0, name);
      
      if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
      {
         Print("Failed to create rectangle: ", name, " Error: ", GetLastError());
         return false;
      }
      
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x1);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y1);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, x2 - x1);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, y2 - y1);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
      ObjectSetInteger(0, name, OBJPROP_COLOR, borderColor);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
      
      return true;
   }

public:
   // Constructor
   CDashboard()
   {
      m_name = "Dashboard";
      m_x = 10;
      m_y = 10;
      m_width = 200;
      m_height = 150;
      m_textColor = clrWhite;
      m_bgColor = clrDarkSlateGray;
      m_borderColor = clrSilver;
      m_profitColor = clrLimeGreen;
      m_lossColor = clrCrimson;
      m_fontSize = 9;
      m_objNamePrefix = "DashboardGlobal_";
   }
   
   // Destructor
   ~CDashboard() { }
   
   // Khởi tạo
   bool Init(string name = "Dashboard", int x = 10, int y = 10)
   {
      m_name = name;
      m_x = x;
      m_y = y;
      m_objNamePrefix = "Dashboard_" + m_name + "_";
      
      // Tạo panel nền
      if(!CreateRectangle(m_objNamePrefix + "BG", m_x, m_y, m_x + m_width, m_y + m_height, m_bgColor, m_borderColor))
         return false;
         
      // Tạo tiêu đề
      if(!CreateLabel(m_objNamePrefix + "Title", "TRADING DASHBOARD", m_x + 10, m_y + 5, m_textColor, m_fontSize + 1, true))
         return false;
         
      // Tạo các label cơ bản
      if(!CreateLabel(m_objNamePrefix + "BalanceLabel", "Balance:", m_x + 10, m_y + 30, m_textColor, m_fontSize))
         return false;
         
      if(!CreateLabel(m_objNamePrefix + "EquityLabel", "Equity:", m_x + 10, m_y + 50, m_textColor, m_fontSize))
         return false;
         
      if(!CreateLabel(m_objNamePrefix + "ProfitLabel", "Daily P/L:", m_x + 10, m_y + 70, m_textColor, m_fontSize))
         return false;
         
      if(!CreateLabel(m_objNamePrefix + "WinRateLabel", "Win Rate:", m_x + 10, m_y + 90, m_textColor, m_fontSize))
         return false;
         
      if(!CreateLabel(m_objNamePrefix + "ExpectancyLabel", "Expectancy:", m_x + 10, m_y + 110, m_textColor, m_fontSize))
         return false;
         
      if(!CreateLabel(m_objNamePrefix + "ProfitFactorLabel", "Profit Factor:", m_x + 10, m_y + 130, m_textColor, m_fontSize))
         return false;
         
      // Các giá trị
      if(!CreateLabel(m_objNamePrefix + "BalanceValue", "0.00", m_x + 120, m_y + 30, m_textColor, m_fontSize))
         return false;
         
      if(!CreateLabel(m_objNamePrefix + "EquityValue", "0.00", m_x + 120, m_y + 50, m_textColor, m_fontSize))
         return false;
         
      if(!CreateLabel(m_objNamePrefix + "ProfitValue", "0.00", m_x + 120, m_y + 70, m_textColor, m_fontSize))
         return false;
         
      if(!CreateLabel(m_objNamePrefix + "WinRateValue", "0.0%", m_x + 120, m_y + 90, m_textColor, m_fontSize))
         return false;
         
      if(!CreateLabel(m_objNamePrefix + "ExpectancyValue", "0.00", m_x + 120, m_y + 110, m_textColor, m_fontSize))
         return false;
         
      if(!CreateLabel(m_objNamePrefix + "ProfitFactorValue", "0.00", m_x + 120, m_y + 130, m_textColor, m_fontSize))
         return false;
      
      return true;
   }
   
   // Dọn dẹp
   void Deinit()
   {
      // Xóa tất cả các đối tượng Dashboard
      for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
      {
         string objName = ObjectName(0, i);
         if(StringFind(objName, m_objNamePrefix) == 0)
            ObjectDelete(0, objName);
      }
   }
   
   // Cập nhật thông tin
   void Update(double balance, double equity, double profit, double winRate, double expectancy, double profitFactor)
   {
      // Cập nhật các giá trị
      ObjectSetString(0, m_objNamePrefix + "BalanceValue", OBJPROP_TEXT, DoubleToString(balance, 2));
      ObjectSetString(0, m_objNamePrefix + "EquityValue", OBJPROP_TEXT, DoubleToString(equity, 2));
      
      // Thiết lập màu cho profit/loss
      color profitColor = profit >= 0 ? m_profitColor : m_lossColor;
      ObjectSetString(0, m_objNamePrefix + "ProfitValue", OBJPROP_TEXT, DoubleToString(profit, 2));
      ObjectSetInteger(0, m_objNamePrefix + "ProfitValue", OBJPROP_COLOR, profitColor);
      
      ObjectSetString(0, m_objNamePrefix + "WinRateValue", OBJPROP_TEXT, DoubleToString(winRate * 100, 1) + "%");
      ObjectSetString(0, m_objNamePrefix + "ExpectancyValue", OBJPROP_TEXT, DoubleToString(expectancy, 2));
      ObjectSetString(0, m_objNamePrefix + "ProfitFactorValue", OBJPROP_TEXT, DoubleToString(profitFactor, 2));
      
      // Cập nhật chart
      ChartRedraw(0);
   }
};

//+------------------------------------------------------------------+
//|                                                   EAPanel.mqh |
//|                        Copyright 2025, Your Company               |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"

// Class hiển thị panel riêng cho từng EA
class CEAPanel
{
private:
   string            m_eaName;
   int               m_x;
   int               m_y;
   int               m_width;
   int               m_height;
   color             m_textColor;
   color             m_bgColor;
   color             m_borderColor;
   color             m_profitColor;
   color             m_lossColor;
   color             m_signalColor;
   int               m_fontSize;
   string            m_objNamePrefix;
   
   // Tạo đối tượng text trên chart
   bool CreateLabel(string name, string text, int x, int y, color textColor, int fontSize, bool bold = false)
   {
      if(ObjectFind(0, name) >= 0)
         ObjectDelete(0, name);
      
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
      {
         Print("Failed to create label: ", name, " Error: ", GetLastError());
         return false;
      }
      
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      
      // Thay đổi cách xử lý chữ in đậm
      if(bold)
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize + 1); // Tăng font size thay vì dùng bold
      else
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
         
      // Sử dụng OBJPROP_STYLE để thiết lập kiểu đường (không phải font style)
      ObjectSetInteger(0, name, OBJPROP_STYLE, 0); // 0 = STYLE_SOLID
      
      return true;
   }
   
   // Tạo đối tượng hình chữ nhật trên chart
   bool CreateRectangle(string name, int x1, int y1, int x2, int y2, color bgColor, color borderColor, int width = 1)
   {
      if(ObjectFind(0, name) >= 0)
         ObjectDelete(0, name);
      
      if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
      {
         Print("Failed to create rectangle: ", name, " Error: ", GetLastError());
         return false;
      }
      
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x1);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y1);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, x2 - x1);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, y2 - y1);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
      ObjectSetInteger(0, name, OBJPROP_COLOR, borderColor);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
      
      return true;
   }

public:
   // Constructor
   CEAPanel()
   {
      m_eaName = "EA";
      m_x = 220;
      m_y = 10;
      m_width = 200;
      m_height = 230;
      m_textColor = clrWhite;
      m_bgColor = clrDarkSlateBlue;
      m_borderColor = clrSilver;
      m_profitColor = clrLimeGreen;
      m_lossColor = clrCrimson;
      m_signalColor = clrGold;
      m_fontSize = 9;
      m_objNamePrefix = "EAPanel_";
   }
   
   // Destructor
   ~CEAPanel() { }
   
   // Khởi tạo
   bool Init(string eaName = "EA", int x = 220, int y = 10)
   {
      m_eaName = eaName;
      m_x = x;
      m_y = y;
      m_objNamePrefix = "EAPanel_" + m_eaName + "_";
      
      // Tạo panel nền
      if(!CreateRectangle(m_objNamePrefix + "BG", m_x, m_y, m_x + m_width, m_y + m_height, m_bgColor, m_borderColor))
         return false;
         
      // Tạo tiêu đề
      if(!CreateLabel(m_objNamePrefix + "Title", m_eaName + " PANEL", m_x + 10, m_y + 5, m_textColor, m_fontSize + 1, true))
         return false;
         
      // Tạo các label cơ bản
      int yPos = m_y + 30;
      int yStep = 20;
      
      if(!CreateLabel(m_objNamePrefix + "StrategyLabel", "Strategy:", m_x + 10, yPos, m_textColor, m_fontSize))
         return false;
      if(!CreateLabel(m_objNamePrefix + "StrategyValue", m_eaName, m_x + 120, yPos, m_textColor, m_fontSize))
         return false;
      yPos += yStep;
      
      if(!CreateLabel(m_objNamePrefix + "MarketLabel", "Market Condition:", m_x + 10, yPos, m_textColor, m_fontSize))
         return false;
      if(!CreateLabel(m_objNamePrefix + "MarketValue", "UNDEFINED", m_x + 120, yPos, m_textColor, m_fontSize))
         return false;
      yPos += yStep;
      
      if(!CreateLabel(m_objNamePrefix + "WinRateLabel", "Win Rate:", m_x + 10, yPos, m_textColor, m_fontSize))
         return false;
      if(!CreateLabel(m_objNamePrefix + "WinRateValue", "0.0%", m_x + 120, yPos, m_textColor, m_fontSize))
         return false;
      yPos += yStep;
      
      if(!CreateLabel(m_objNamePrefix + "AvgWinLabel", "Avg Win:", m_x + 10, yPos, m_textColor, m_fontSize))
         return false;
      if(!CreateLabel(m_objNamePrefix + "AvgWinValue", "0.00R", m_x + 120, yPos, m_textColor, m_fontSize))
         return false;
      yPos += yStep;
      
      if(!CreateLabel(m_objNamePrefix + "AvgLossLabel", "Avg Loss:", m_x + 10, yPos, m_textColor, m_fontSize))
         return false;
      if(!CreateLabel(m_objNamePrefix + "AvgLossValue", "0.00R", m_x + 120, yPos, m_textColor, m_fontSize))
         return false;
      yPos += yStep;
      
      if(!CreateLabel(m_objNamePrefix + "ExpectancyLabel", "Expectancy:", m_x + 10, yPos, m_textColor, m_fontSize))
         return false;
      if(!CreateLabel(m_objNamePrefix + "ExpectancyValue", "0.00R", m_x + 120, yPos, m_textColor, m_fontSize))
         return false;
      yPos += yStep;
      
      if(!CreateLabel(m_objNamePrefix + "DDLabel", "Max Drawdown:", m_x + 10, yPos, m_textColor, m_fontSize))
         return false;
      if(!CreateLabel(m_objNamePrefix + "DDValue", "0.0%", m_x + 120, yPos, m_textColor, m_fontSize))
         return false;
      yPos += yStep;
      
      if(!CreateLabel(m_objNamePrefix + "ConsLossLabel", "Consecutive Losses:", m_x + 10, yPos, m_textColor, m_fontSize))
         return false;
      if(!CreateLabel(m_objNamePrefix + "ConsLossValue", "0", m_x + 120, yPos, m_textColor, m_fontSize))
         return false;
      yPos += yStep;
      
      if(!CreateLabel(m_objNamePrefix + "LastSignalLabel", "Last Signal:", m_x + 10, yPos, m_textColor, m_fontSize))
         return false;
      if(!CreateLabel(m_objNamePrefix + "LastSignalValue", "NONE", m_x + 120, yPos, m_textColor, m_fontSize))
         return false;
      yPos += yStep;
      
      if(!CreateLabel(m_objNamePrefix + "SignalQualityLabel", "Signal Quality:", m_x + 10, yPos, m_textColor, m_fontSize))
         return false;
      if(!CreateLabel(m_objNamePrefix + "SignalQualityValue", "NONE", m_x + 120, yPos, m_textColor, m_fontSize))
         return false;
      
      return true;
   }
   
   // Dọn dẹp
   void Deinit()
   {
      // Xóa tất cả các đối tượng EAPanel
      for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
      {
         string objName = ObjectName(0, i);
         if(StringFind(objName, m_objNamePrefix) == 0)
            ObjectDelete(0, objName);
      }
   }
   
   // Cập nhật thông tin
   void Update(string strategyName, ENUM_MARKET_CONDITION marketCondition, 
               double winRate, double avgWin, double avgLoss, double expectancy, 
               double maxDrawdown, int consecutiveLosses)
   {
      // Cập nhật các giá trị
      ObjectSetString(0, m_objNamePrefix + "StrategyValue", OBJPROP_TEXT, strategyName);
      
      string marketStr = "";
      switch(marketCondition)
      {
         case MARKET_CONDITION_TRENDING: marketStr = "TRENDING"; break;
         case MARKET_CONDITION_RANGING: marketStr = "RANGING"; break;
         case MARKET_CONDITION_VOLATILE: marketStr = "VOLATILE"; break;
         case MARKET_CONDITION_TRANSITION: marketStr = "TRANSITION"; break;
         default: marketStr = "UNDEFINED"; break;
      }
      ObjectSetString(0, m_objNamePrefix + "MarketValue", OBJPROP_TEXT, marketStr);
      
      ObjectSetString(0, m_objNamePrefix + "WinRateValue", OBJPROP_TEXT, DoubleToString(winRate * 100, 1) + "%");
      ObjectSetString(0, m_objNamePrefix + "AvgWinValue", OBJPROP_TEXT, DoubleToString(avgWin, 2) + "R");
      ObjectSetString(0, m_objNamePrefix + "AvgLossValue", OBJPROP_TEXT, DoubleToString(avgLoss, 2) + "R");
      ObjectSetString(0, m_objNamePrefix + "ExpectancyValue", OBJPROP_TEXT, DoubleToString(expectancy, 2) + "R");
      ObjectSetString(0, m_objNamePrefix + "DDValue", OBJPROP_TEXT, DoubleToString(maxDrawdown * 100, 1) + "%");
      ObjectSetString(0, m_objNamePrefix + "ConsLossValue", OBJPROP_TEXT, IntegerToString(consecutiveLosses));
      
      // Cập nhật chart
      ChartRedraw(0);
   }
   
   // Cập nhật điều kiện thị trường
   void UpdateMarketCondition(ENUM_MARKET_CONDITION marketCondition)
   {
      string marketStr = "";
      switch(marketCondition)
      {
         case MARKET_CONDITION_TRENDING: marketStr = "TRENDING"; break;
         case MARKET_CONDITION_RANGING: marketStr = "RANGING"; break;
         case MARKET_CONDITION_VOLATILE: marketStr = "VOLATILE"; break;
         case MARKET_CONDITION_TRANSITION: marketStr = "TRANSITION"; break;
         default: marketStr = "UNDEFINED"; break;
      }
      ObjectSetString(0, m_objNamePrefix + "MarketValue", OBJPROP_TEXT, marketStr);
      
      // Cập nhật chart
      ChartRedraw(0);
   }
   
   // Cập nhật tín hiệu mới nhất
   void UpdateLastSignal(string signal, ENUM_SETUP_QUALITY quality)
   {
      ObjectSetString(0, m_objNamePrefix + "LastSignalValue", OBJPROP_TEXT, signal);
      ObjectSetInteger(0, m_objNamePrefix + "LastSignalValue", OBJPROP_COLOR, m_signalColor);
      
      string qualityStr = "";
      switch(quality)
      {
         case SETUP_QUALITY_A_PLUS: qualityStr = "A+"; break;
         case SETUP_QUALITY_A: qualityStr = "A"; break;
         case SETUP_QUALITY_B: qualityStr = "B"; break;
         default: qualityStr = "NONE"; break;
      }
      ObjectSetString(0, m_objNamePrefix + "SignalQualityValue", OBJPROP_TEXT, qualityStr);
      
      // Cập nhật chart
      ChartRedraw(0);
   }
};