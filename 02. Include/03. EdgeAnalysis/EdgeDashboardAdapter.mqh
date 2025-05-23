//+------------------------------------------------------------------+
//|                                      EdgeDashboardAdapter.mqh |
//|                        Copyright 2025, Your Company               |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"

// Include files
#include "CommonDefinitions.mqh"
#include "Dashboard.mqh"
#include "TradeManager.mqh"  // Thêm trực tiếp include cho TradeManager

// Cấu trúc kết quả hiệu suất được định nghĩa ở đây
struct STradeRecord
{
   ulong    ticket;
   datetime openTime;
   datetime closeTime;
   string   symbol;
   int      type;
   double   profit;
   double   pips;
   double   riskReward;
   string   exitReason;
   int      setupQuality;
   int      duration;
};

// Sử dụng cấu trúc riêng cho hiệu suất edge để tránh xung đột
struct SEdgePerformanceResultLocal
{
   int      sampleSize;
   double   winRate;
   double   profitFactor;
   double   expectancy;
   double   avgWin;
   double   avgLoss;
   double   maxDrawdown;
   int      maxConsecutiveLosses;
   double   sharpeRatio;
   double   edgeRatio;
};

// Class EdgeTracker (đơn giản hóa)
class CEdgeTracker
{
public:
   string GetStrategyName() { return ""; }
   int GetMarketCondition() { return 0; }
   SEdgePerformanceResultLocal GetCurrentPerformance(int count) 
   { 
      SEdgePerformanceResultLocal result;
      ZeroMemory(result);
      return result; 
   }
};

// Class kết nối giữa EdgeTracker và Dashboard
class CEdgeDashboardAdapter
{
private:
   CDashboard*       m_dashboard;
   CEAPanel*         m_eaPanel;
   CEdgeTracker*     m_edgeTracker;
   
   // Số lượng giao dịch để phân tích Edge hiện tại
   int               m_recentTradesCount;
   
   // Thời gian cập nhật gần nhất
   datetime          m_lastUpdateTime;
   
   // Giao dịch theo dõi thông số
   struct TradeStats
   {
      int            totalTrades;
      int            winTrades;
      int            lossTrades;
      double         avgWin;
      double         avgLoss;
      double         maxDrawdown;
      int            consecutiveLosses;
      double         profitFactor;
      double         expectancy;
      double         winRate;
   };
   
   TradeStats        m_stats;

public:
   // Constructor
   CEdgeDashboardAdapter()
   {
      m_dashboard = NULL;
      m_eaPanel = NULL;
      m_edgeTracker = NULL;
      m_recentTradesCount = 30;
      m_lastUpdateTime = 0;
      
      ZeroMemory(m_stats);
   }
   
   // Destructor
   ~CEdgeDashboardAdapter()
   {
      if(m_dashboard != NULL)
         delete m_dashboard;
         
      if(m_eaPanel != NULL)
         delete m_eaPanel;
   }
   
   // Khởi tạo
   bool Init(CEdgeTracker* edgeTracker, string eaName = "Triple Confirmation")
   {
      if(edgeTracker == NULL)
      {
         Print("EdgeTracker is NULL");
         return false;
      }
      
      m_edgeTracker = edgeTracker;
      
      // Khởi tạo Dashboard
      m_dashboard = new CDashboard();
      if(m_dashboard == NULL)
      {
         Print("Failed to create Dashboard");
         return false;
      }
      
      if(!m_dashboard.Init("Global"))
      {
         Print("Failed to initialize Dashboard");
         return false;
      }
      
      // Khởi tạo EAPanel
      m_eaPanel = new CEAPanel();
      if(m_eaPanel == NULL)
      {
         Print("Failed to create EAPanel");
         return false;
      }
      
      if(!m_eaPanel.Init(eaName, 220, 10))
      {
         Print("Failed to initialize EAPanel");
         return false;
      }
      
      return true;
   }
   
   // Cập nhật Dashboard từ dữ liệu EdgeTracker
   void Update(bool forceUpdate = false)
   {
      // Cập nhật mỗi 60 giây hoặc khi yêu cầu cập nhật
      datetime currentTime = TimeCurrent();
      if(!forceUpdate && currentTime - m_lastUpdateTime < 60)
         return;
         
      m_lastUpdateTime = currentTime;
      
      // Cập nhật thống kê từ EdgeTracker
      UpdateStatistics();
      
      // Cập nhật Dashboard chung
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double profit = equity - balance;
      
      m_dashboard.Update(balance, equity, profit, 
                         m_stats.winRate, 
                         m_stats.expectancy, 
                         m_stats.profitFactor);
      
      // Cập nhật EAPanel - Đảm bảo ép kiểu về ENUM_MARKET_CONDITION
      int marketConditionInt = m_edgeTracker.GetMarketCondition();
      ENUM_MARKET_CONDITION marketCondition = (ENUM_MARKET_CONDITION)marketConditionInt;
      
      m_eaPanel.Update(m_edgeTracker.GetStrategyName(), 
                       marketCondition,
                       m_stats.winRate, 
                       m_stats.avgWin, 
                       m_stats.avgLoss, 
                       m_stats.expectancy,
                       m_stats.maxDrawdown, 
                       m_stats.consecutiveLosses);
   }
   
   // Cập nhật Panel khi có tín hiệu mới
   void UpdateSignal(string signal, ENUM_SETUP_QUALITY quality)
   {
      if(m_eaPanel != NULL)
         m_eaPanel.UpdateLastSignal(signal, quality);
   }
   
   // Cập nhật Panel khi điều kiện thị trường thay đổi
   void UpdateMarketCondition(ENUM_MARKET_CONDITION marketCondition)
   {
      if(m_eaPanel != NULL)
         m_eaPanel.UpdateMarketCondition(marketCondition);
   }
   
   // Lấy thống kê từ EdgeTracker
   void UpdateStatistics()
   {
      // Lấy dữ liệu hiệu suất hiện tại từ EdgeTracker
      SEdgePerformanceResultLocal performance = m_edgeTracker.GetCurrentPerformance(m_recentTradesCount);
      
      if(performance.sampleSize > 0)
      {
         m_stats.totalTrades = performance.sampleSize;
         m_stats.winTrades = (int)(performance.sampleSize * performance.winRate);
         m_stats.lossTrades = performance.sampleSize - m_stats.winTrades;
         m_stats.avgWin = performance.avgWin;
         m_stats.avgLoss = performance.avgLoss;
         m_stats.maxDrawdown = performance.maxDrawdown;
         m_stats.consecutiveLosses = performance.maxConsecutiveLosses;
         m_stats.profitFactor = performance.profitFactor;
         m_stats.expectancy = performance.expectancy;
         m_stats.winRate = performance.winRate;
      }
   }
   
   // Dọn dẹp
   void Deinit()
   {
      if(m_dashboard != NULL)
         m_dashboard.Deinit();
         
      if(m_eaPanel != NULL)
         m_eaPanel.Deinit();
   }
};