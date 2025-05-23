//+------------------------------------------------------------------+
//|                                      TripleConfirmPanel.mqh      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"

#include "Dashboard.mqh"
#include "CommonDefinitions.mqh"

class CTripleConfirmPanel : public CDashboardBase
{
private:
   double            m_balance;
   double            m_equity;
   double            m_profit;
   ENUM_MARKET_CONDITION m_marketCondition;
   double            m_winRate;
   double            m_expectancy;
   double            m_profitFactor;
   
public:
   CTripleConfirmPanel() : CDashboardBase() 
   {
      m_balance = 0.0;
      m_equity = 0.0;
      m_profit = 0.0;
      m_marketCondition = MARKET_CONDITION_UNDEFINED;
      m_winRate = 0.0;
      m_expectancy = 0.0;
      m_profitFactor = 0.0;
   }
   
   virtual bool Init(string name, int x, int y) override
   {
      // Gọi phương thức Init của lớp cha
      if(!CDashboardBase::Init(name, x, y))
         return false;
         
      // Thiết lập các giá trị mặc định cho panel
      m_name = "Triple Confirmation Panel";
      CreatePanel();
      
      return true;
   }
   
   void Update(double balance, double equity, double profit, 
               ENUM_MARKET_CONDITION marketCondition, 
               double winRate, double expectancy, double profitFactor)
   {
      m_balance = balance;
      m_equity = equity;
      m_profit = profit;
      m_marketCondition = marketCondition;
      m_winRate = winRate;
      m_expectancy = expectancy;
      m_profitFactor = profitFactor;
      
      // Cập nhật hiển thị
      UpdateDisplay();
   }
   
   void UpdateMarketCondition(ENUM_MARKET_CONDITION condition)
   {
      m_marketCondition = condition;
      // Cập nhật phần hiển thị điều kiện thị trường
      UpdateMarketConditionDisplay();
   }
   
private:
   void CreatePanel()
   {
      // Tạo panel nền
      ObjectCreate(0, "TripleConfirmPanel_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "TripleConfirmPanel_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "TripleConfirmPanel_BG", OBJPROP_XDISTANCE, m_x);
      ObjectSetInteger(0, "TripleConfirmPanel_BG", OBJPROP_YDISTANCE, m_y);
      ObjectSetInteger(0, "TripleConfirmPanel_BG", OBJPROP_XSIZE, 200);
      ObjectSetInteger(0, "TripleConfirmPanel_BG", OBJPROP_YSIZE, 200);
      ObjectSetInteger(0, "TripleConfirmPanel_BG", OBJPROP_BGCOLOR, clrWhiteSmoke);
      ObjectSetInteger(0, "TripleConfirmPanel_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, "TripleConfirmPanel_BG", OBJPROP_COLOR, clrBlack);
      
      // Tạo tiêu đề panel
      CreateLabel("TripleConfirmPanel_Title", "TRIPLE CONFIRMATION", m_x + 5, m_y + 5, clrNavy, 10, true);
      
      // Tạo các label hiển thị thông tin
      CreateLabel("TripleConfirmPanel_BalanceLabel", "Balance:", m_x + 5, m_y + 30, clrBlack);
      CreateLabel("TripleConfirmPanel_BalanceValue", "0.00", m_x + 100, m_y + 30, clrBlack);
      
      CreateLabel("TripleConfirmPanel_EquityLabel", "Equity:", m_x + 5, m_y + 50, clrBlack);
      CreateLabel("TripleConfirmPanel_EquityValue", "0.00", m_x + 100, m_y + 50, clrBlack);
      
      CreateLabel("TripleConfirmPanel_ProfitLabel", "Profit:", m_x + 5, m_y + 70, clrBlack);
      CreateLabel("TripleConfirmPanel_ProfitValue", "0.00", m_x + 100, m_y + 70, clrBlack);
      
      CreateLabel("TripleConfirmPanel_ConditionLabel", "Market:", m_x + 5, m_y + 90, clrBlack);
      CreateLabel("TripleConfirmPanel_ConditionValue", "Undefined", m_x + 100, m_y + 90, clrBlack);
      
      CreateLabel("TripleConfirmPanel_WinRateLabel", "Win Rate:", m_x + 5, m_y + 110, clrBlack);
      CreateLabel("TripleConfirmPanel_WinRateValue", "0.0%", m_x + 100, m_y + 110, clrBlack);
      
      CreateLabel("TripleConfirmPanel_ExpectancyLabel", "Expectancy:", m_x + 5, m_y + 130, clrBlack);
      CreateLabel("TripleConfirmPanel_ExpectancyValue", "0.00", m_x + 100, m_y + 130, clrBlack);
      
      CreateLabel("TripleConfirmPanel_PFLabel", "PF:", m_x + 5, m_y + 150, clrBlack);
      CreateLabel("TripleConfirmPanel_PFValue", "0.00", m_x + 100, m_y + 150, clrBlack);
   }
   
   void CreateLabel(string name, string text, int x, int y, color textColor, int fontSize = 8, bool isBold = false)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
      ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
      
      if(isBold)
      {
         // Thay vì sử dụng OBJPROP_FONTWEIGHT, tăng kích thước font để làm nổi bật
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize + 2);
      }
   }
   
   void UpdateDisplay()
   {
      // Cập nhật các giá trị
      ObjectSetString(0, "TripleConfirmPanel_BalanceValue", OBJPROP_TEXT, DoubleToString(m_balance, 2));
      ObjectSetString(0, "TripleConfirmPanel_EquityValue", OBJPROP_TEXT, DoubleToString(m_equity, 2));
      
      string profitText = (m_profit >= 0 ? "+" : "") + DoubleToString(m_profit, 2);
      color profitColor = m_profit >= 0 ? clrGreen : clrRed;
      ObjectSetString(0, "TripleConfirmPanel_ProfitValue", OBJPROP_TEXT, profitText);
      ObjectSetInteger(0, "TripleConfirmPanel_ProfitValue", OBJPROP_COLOR, profitColor);
      
      ObjectSetString(0, "TripleConfirmPanel_WinRateValue", OBJPROP_TEXT, DoubleToString(m_winRate * 100.0, 1) + "%");
      ObjectSetString(0, "TripleConfirmPanel_ExpectancyValue", OBJPROP_TEXT, DoubleToString(m_expectancy, 2));
      ObjectSetString(0, "TripleConfirmPanel_PFValue", OBJPROP_TEXT, DoubleToString(m_profitFactor, 2));
      
      // Cập nhật điều kiện thị trường
      UpdateMarketConditionDisplay();
      
      // Force redraw
      ChartRedraw(0);
   }
   
   void UpdateMarketConditionDisplay()
   {
      string conditionText = "";
      color conditionColor = clrBlack;
      
      switch(m_marketCondition)
      {
         case MARKET_CONDITION_TRENDING:
            conditionText = "Trending";
            conditionColor = clrBlue;
            break;
            
         case MARKET_CONDITION_RANGING:
            conditionText = "Ranging";
            conditionColor = clrGreen;
            break;
            
         case MARKET_CONDITION_VOLATILE:
            conditionText = "Volatile";
            conditionColor = clrRed;
            break;
            
         case MARKET_CONDITION_TRANSITION:
            conditionText = "Transition";
            conditionColor = clrOrange;
            break;
            
         default:
            conditionText = "Undefined";
            conditionColor = clrGray;
            break;
      }
      
      ObjectSetString(0, "TripleConfirmPanel_ConditionValue", OBJPROP_TEXT, conditionText);
      ObjectSetInteger(0, "TripleConfirmPanel_ConditionValue", OBJPROP_COLOR, conditionColor);
   }
};