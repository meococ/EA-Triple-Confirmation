//+------------------------------------------------------------------+
//|                                           EdgeDisplay.mqh        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"

// Defines cho font styles nếu chưa được định nghĩa
#ifndef OBJPROP_FONTWEIGHT
#define OBJPROP_FONTWEIGHT 1020
#endif

#ifndef FONT_BOLD
#define FONT_BOLD 1
#endif

#include "EdgeTracker.mqh"

class CEdgeDisplay
{
private:
   CEdgeTracker*     m_edgeTracker;
   int               m_x;
   int               m_y;
   string            m_lastSignalType;
   ENUM_SETUP_QUALITY m_lastSetupQuality;
   string            m_panelPrefix;
   color             m_backgroundColor;
   color             m_textColor;
   color             m_titleColor;
   color             m_warningColor;
   int               m_labelWidth;
   int               m_rowHeight;
   
public:
   // Constructor
   CEdgeDisplay()
   {
      m_edgeTracker = NULL;
      m_x = 10;
      m_y = 10;
      m_lastSignalType = "";
      m_lastSetupQuality = SETUP_QUALITY_NONE;
      m_panelPrefix = "EdgePanel_";
      m_backgroundColor = clrWhiteSmoke;
      m_textColor = clrBlack;
      m_titleColor = clrNavy;
      m_warningColor = clrDarkRed;
      m_labelWidth = 200;
      m_rowHeight = 20;
   }
   
   // Khởi tạo
   bool Init(CEdgeTracker* tracker, int x, int y)
   {
      if(tracker == NULL)
         return false;
         
      m_edgeTracker = tracker;
      m_x = x;
      m_y = y;
      
      // Tạo panel lần đầu
      CreatePanel();
      
      return true;
   }
   
   // Deinitialize
   void Deinit()
   {
      // Xóa tất cả các object hiển thị
      ObjectsDeleteAll(0, m_panelPrefix);
   }
   
   // Cập nhật hiển thị
   void Update()
   {
      if(m_edgeTracker == NULL)
         return;
         
      // Lấy dữ liệu từ EdgeTracker - Sử dụng toán tử . thay vì -> cho truy cập con trỏ
      SEdgePerformanceResult performance;
      
      // Sử dụng toán tử . thay vì -> theo cách MQL5 xử lý con trỏ
      performance = m_edgeTracker.GetCurrentPerformance();
      
      // Cập nhật hiệu suất hiện tại
      UpdatePerformanceDisplay(performance);
      
      // Kiểm tra Edge decay mỗi lần cập nhật
      int totalTrades = m_edgeTracker.GetTotalTrades();
      if(totalTrades >= 30)
      {
         SEdgeDegradation decay = m_edgeTracker.CheckEdgeDegradation();
         if(decay.hasDegradation)
         {
            UpdateDecayWarning(decay);
         }
         else
         {
            ClearDecayWarning();
         }
      }
   }
   
   // Cập nhật thông tin tín hiệu gần nhất
   void UpdateLastSignal(string signalType, ENUM_SETUP_QUALITY quality)
   {
      m_lastSignalType = signalType;
      m_lastSetupQuality = quality;
      
      string qualityText = "";
      color signalColor = clrBlack;
      
      switch(quality)
      {
         case SETUP_QUALITY_A_PLUS: 
            qualityText = "A+"; 
            signalColor = clrDarkGreen;
            break;
         case SETUP_QUALITY_A: 
            qualityText = "A"; 
            signalColor = clrForestGreen;
            break;
         case SETUP_QUALITY_B: 
            qualityText = "B"; 
            signalColor = clrOrange;
            break;
         default: 
            qualityText = "None"; 
            break;
      }
      
      // Cập nhật hiển thị
      string labelName = m_panelPrefix + "LastSignal";
      if(ObjectFind(0, labelName) < 0)
      {
         CreateLabel(labelName, "Last Signal: ", m_x + 5, m_y + 250, m_textColor);
      }
      
      string valueName = m_panelPrefix + "LastSignalValue";
      if(ObjectFind(0, valueName) < 0)
      {
         CreateLabel(valueName, signalType + " (" + qualityText + ")", m_x + 100, m_y + 250, signalColor);
      }
      else
      {
         ObjectSetString(0, valueName, OBJPROP_TEXT, signalType + " (" + qualityText + ")");
         ObjectSetInteger(0, valueName, OBJPROP_COLOR, signalColor);
      }
      
      // Cập nhật thời gian
      string timeName = m_panelPrefix + "LastSignalTime";
      if(ObjectFind(0, timeName) < 0)
      {
         CreateLabel(timeName, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES), m_x + 5, m_y + 270, m_textColor);
      }
      else
      {
         ObjectSetString(0, timeName, OBJPROP_TEXT, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
      }
      
      // Force redraw
      ChartRedraw(0);
   }
   
private:
   // Tạo panel background
   void CreatePanel()
   {
      // Background panel
      string name = m_panelPrefix + "Background";
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, m_x);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, m_y);
         ObjectSetInteger(0, name, OBJPROP_XSIZE, m_labelWidth);
         ObjectSetInteger(0, name, OBJPROP_YSIZE, 300);
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, m_backgroundColor);
         ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrGray);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
      }
      
      // Tiêu đề
      name = m_panelPrefix + "Title";
      if(ObjectFind(0, name) < 0)
      {
         CreateLabel(name, "EDGE MONITORING", m_x + 5, m_y + 5, m_titleColor, 10, true);
      }
      
      // Tạo các label cố định
      CreateFixedLabels();
   }
   
   // Tạo các label cố định
   void CreateFixedLabels()
   {
      int y = m_y + 30;
      
      // Hiệu suất hiện tại
      CreateLabel(m_panelPrefix + "PerfTitle", "CURRENT PERFORMANCE", m_x + 5, y, m_titleColor, 9, true);
      y += 25;
      
      CreateLabel(m_panelPrefix + "WinRateLabel", "Win Rate:", m_x + 5, y, m_textColor);
      CreateLabel(m_panelPrefix + "WinRateValue", "0.0%", m_x + 100, y, m_textColor);
      y += m_rowHeight;
      
      CreateLabel(m_panelPrefix + "ExpectancyLabel", "Expectancy:", m_x + 5, y, m_textColor);
      CreateLabel(m_panelPrefix + "ExpectancyValue", "0.0", m_x + 100, y, m_textColor);
      y += m_rowHeight;
      
      CreateLabel(m_panelPrefix + "ProfitFactorLabel", "Profit Factor:", m_x + 5, y, m_textColor);
      CreateLabel(m_panelPrefix + "ProfitFactorValue", "0.0", m_x + 100, y, m_textColor);
      y += m_rowHeight;
      
      CreateLabel(m_panelPrefix + "MaxDDLabel", "Max Drawdown:", m_x + 5, y, m_textColor);
      CreateLabel(m_panelPrefix + "MaxDDValue", "0.0%", m_x + 100, y, m_textColor);
      y += m_rowHeight;
      
      CreateLabel(m_panelPrefix + "TotalTradesLabel", "Total Trades:", m_x + 5, y, m_textColor);
      CreateLabel(m_panelPrefix + "TotalTradesValue", "0", m_x + 100, y, m_textColor);
      y += 30;
      
      // Hiệu suất theo setup
      CreateLabel(m_panelPrefix + "SetupTitle", "SETUP PERFORMANCE", m_x + 5, y, m_titleColor, 9, true);
      y += 25;
      
      CreateLabel(m_panelPrefix + "APlusLabel", "A+ Setup:", m_x + 5, y, m_textColor);
      CreateLabel(m_panelPrefix + "APlusValue", "0.0%", m_x + 100, y, m_textColor);
      y += m_rowHeight;
      
      CreateLabel(m_panelPrefix + "ALabel", "A Setup:", m_x + 5, y, m_textColor);
      CreateLabel(m_panelPrefix + "AValue", "0.0%", m_x + 100, y, m_textColor);
      y += m_rowHeight;
      
      CreateLabel(m_panelPrefix + "BLabel", "B Setup:", m_x + 5, y, m_textColor);
      CreateLabel(m_panelPrefix + "BValue", "0.0%", m_x + 100, y, m_textColor);
      y += 30;
      
      // Cảnh báo Edge decay
      CreateLabel(m_panelPrefix + "DecayTitle", "EDGE MONITORING", m_x + 5, y, m_titleColor, 9, true);
      y += 25;
      
      CreateLabel(m_panelPrefix + "DecayStatus", "Status: Normal", m_x + 5, y, clrDarkGreen);
      y += m_rowHeight;
      
      CreateLabel(m_panelPrefix + "DecayMessage", "No degradation detected", m_x + 5, y, m_textColor);
      y += m_rowHeight;
   }
   
   // Tạo text label
   void CreateLabel(string name, string text, int x, int y, color textColor, int fontSize = 8, bool isBold = false)
   {
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
         ObjectSetString(0, name, OBJPROP_TEXT, text);
         ObjectSetString(0, name, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
         ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
         
         if(isBold)
         {
            // Tăng kích cỡ font thay vì sử dụng OBJPROP_FONTWEIGHT
            ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize + 2);
         }
      }
      else
      {
         ObjectSetString(0, name, OBJPROP_TEXT, text);
         ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
      }
   }
   
   // Cập nhật hiển thị thông tin hiệu suất
   void UpdatePerformanceDisplay(const SEdgePerformanceResult &perf)
   {
      // Cập nhật các giá trị
      ObjectSetString(0, m_panelPrefix + "WinRateValue", OBJPROP_TEXT, 
                     DoubleToString(perf.winRate * 100.0, 1) + "%");
      
      ObjectSetString(0, m_panelPrefix + "ExpectancyValue", OBJPROP_TEXT, 
                     DoubleToString(perf.expectancy, 2));
      
      ObjectSetString(0, m_panelPrefix + "ProfitFactorValue", OBJPROP_TEXT, 
                     DoubleToString(perf.profitFactor, 2));
      
      ObjectSetString(0, m_panelPrefix + "MaxDDValue", OBJPROP_TEXT, 
                     DoubleToString(perf.maxDrawdown * 100.0, 1) + "%");
      
      ObjectSetString(0, m_panelPrefix + "TotalTradesValue", OBJPROP_TEXT, 
                     IntegerToString(perf.totalTrades));
      
      // Cập nhật hiệu suất theo setup - sửa truy cập con trỏ
      double aplusWinRate = m_edgeTracker.GetWinRateByQuality(SETUP_QUALITY_A_PLUS);
      double aWinRate = m_edgeTracker.GetWinRateByQuality(SETUP_QUALITY_A);
      double bWinRate = m_edgeTracker.GetWinRateByQuality(SETUP_QUALITY_B);
      
      ObjectSetString(0, m_panelPrefix + "APlusValue", OBJPROP_TEXT, 
                     DoubleToString(aplusWinRate * 100.0, 1) + "%");
      
      ObjectSetString(0, m_panelPrefix + "AValue", OBJPROP_TEXT, 
                     DoubleToString(aWinRate * 100.0, 1) + "%");
      
      ObjectSetString(0, m_panelPrefix + "BValue", OBJPROP_TEXT, 
                     DoubleToString(bWinRate * 100.0, 1) + "%");
      
      // Đặt màu dựa trên giá trị
      color winRateColor = perf.winRate >= 0.55 ? clrDarkGreen : 
                         (perf.winRate >= 0.45 ? clrDarkOrange : clrDarkRed);
                         
      color pfColor = perf.profitFactor >= 1.8 ? clrDarkGreen : 
                    (perf.profitFactor >= 1.3 ? clrDarkOrange : clrDarkRed);
                    
      color expectancyColor = perf.expectancy >= 0.5 ? clrDarkGreen : 
                            (perf.expectancy >= 0.2 ? clrDarkOrange : clrDarkRed);
      
      ObjectSetInteger(0, m_panelPrefix + "WinRateValue", OBJPROP_COLOR, winRateColor);
      ObjectSetInteger(0, m_panelPrefix + "ProfitFactorValue", OBJPROP_COLOR, pfColor);
      ObjectSetInteger(0, m_panelPrefix + "ExpectancyValue", OBJPROP_COLOR, expectancyColor);
      
      // Force redraw
      ChartRedraw(0);
   }
   
   // Cập nhật cảnh báo suy giảm Edge
   void UpdateDecayWarning(const SEdgeDegradation &decay)
   {
      string status = "";
      color statusColor = clrBlack;
      
      if(decay.degradationPercent > 25.0)
      {
         status = "Status: SEVERE DEGRADATION";
         statusColor = clrDarkRed;
      }
      else if(decay.degradationPercent > 15.0)
      {
         status = "Status: MODERATE DEGRADATION";
         statusColor = clrDarkOrange;
      }
      else
      {
         status = "Status: MINOR DEGRADATION";
         statusColor = clrOrange;
      }
      
      ObjectSetString(0, m_panelPrefix + "DecayStatus", OBJPROP_TEXT, status);
      ObjectSetInteger(0, m_panelPrefix + "DecayStatus", OBJPROP_COLOR, statusColor);
      
      ObjectSetString(0, m_panelPrefix + "DecayMessage", OBJPROP_TEXT, decay.messages);
      ObjectSetInteger(0, m_panelPrefix + "DecayMessage", OBJPROP_COLOR, statusColor);
      
      // Thêm label cho khuyến nghị nếu chưa có
      string recName = m_panelPrefix + "DecayRecommend";
      if(ObjectFind(0, recName) < 0)
      {
         CreateLabel(recName, decay.recommendations, m_x + 5, m_y + 230, statusColor);
      }
      else
      {
         ObjectSetString(0, recName, OBJPROP_TEXT, decay.recommendations);
         ObjectSetInteger(0, recName, OBJPROP_COLOR, statusColor);
      }
      
      // Force redraw
      ChartRedraw(0);
   }
   
   // Xóa cảnh báo suy giảm Edge
   void ClearDecayWarning()
   {
      ObjectSetString(0, m_panelPrefix + "DecayStatus", OBJPROP_TEXT, "Status: Normal");
      ObjectSetInteger(0, m_panelPrefix + "DecayStatus", OBJPROP_COLOR, clrDarkGreen);
      
      ObjectSetString(0, m_panelPrefix + "DecayMessage", OBJPROP_TEXT, "No edge degradation detected");
      ObjectSetInteger(0, m_panelPrefix + "DecayMessage", OBJPROP_COLOR, m_textColor);
      
      string recName = m_panelPrefix + "DecayRecommend";
      if(ObjectFind(0, recName) >= 0)
      {
         ObjectSetString(0, recName, OBJPROP_TEXT, "Continue with current strategy");
         ObjectSetInteger(0, recName, OBJPROP_COLOR, clrDarkGreen);
      }
      
      // Force redraw
      ChartRedraw(0);
   }
};