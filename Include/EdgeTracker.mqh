//+------------------------------------------------------------------+
//|                                             EdgeTracker.mqh      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"

#include "CommonDefinitions.mqh"

class CEdgeTracker
{
private:
   string            m_name;
   int               m_adxPeriod;
   int               m_adxTrendingThreshold;
   int               m_adxRangingThreshold;
   int               m_totalTrades;
   int               m_wins;
   int               m_losses;
   double            m_totalProfit;
   double            m_totalLoss;
   double            m_maxDrawdown;
   double            m_currentDrawdown;
   double            m_peakEquity;
   
   // Hiệu suất theo chất lượng setup
   int               m_setupAPlusTrades;
   int               m_setupAPlusWins;
   int               m_setupATrades;
   int               m_setupAWins;
   int               m_setupBTrades;
   int               m_setupBWins;
   
   // Hiệu suất theo điều kiện thị trường
   int               m_trendingTrades;
   int               m_trendingWins;
   int               m_rangingTrades;
   int               m_rangingWins;
   int               m_volatileTrades;
   int               m_volatileWins;
   
   // Lưu trữ các giao dịch gần đây để phân tích
   STradeResult      m_recentTrades[100];
   int               m_recentTradeCount;
   
   // Hiệu suất cơ sở (baseline) để so sánh
   SEdgePerformanceResult m_baselinePerformance;
   bool              m_hasBaselineSet;
   
public:
   // Constructor
   CEdgeTracker()
   {
      m_name = "EdgeTracker";
      m_adxPeriod = 14;
      m_adxTrendingThreshold = 25;
      m_adxRangingThreshold = 20;
      m_totalTrades = 0;
      m_wins = 0;
      m_losses = 0;
      m_totalProfit = 0.0;
      m_totalLoss = 0.0;
      m_maxDrawdown = 0.0;
      m_currentDrawdown = 0.0;
      m_peakEquity = 0.0;
      
      m_setupAPlusTrades = 0;
      m_setupAPlusWins = 0;
      m_setupATrades = 0;
      m_setupAWins = 0;
      m_setupBTrades = 0;
      m_setupBWins = 0;
      
      m_trendingTrades = 0;
      m_trendingWins = 0;
      m_rangingTrades = 0;
      m_rangingWins = 0;
      m_volatileTrades = 0;
      m_volatileWins = 0;
      
      m_recentTradeCount = 0;
      m_hasBaselineSet = false;
      
      // Khởi tạo baseline performance
      ResetPerformanceData(m_baselinePerformance);
   }
   
   // Khởi tạo tracker
   bool Init(string name)
   {
      m_name = name;
      m_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      return true;
   }
   
   // Giải phóng resource
   void Deinit()
   {
      // Không cần xử lý đặc biệt
   }
   
   // Thiết lập tham số ADX
   void SetADXParameters(int period, int trendingThreshold, int rangingThreshold = 20)
   {
      m_adxPeriod = period;
      m_adxTrendingThreshold = trendingThreshold;
      m_adxRangingThreshold = rangingThreshold;
   }
   
   // Xác định điều kiện thị trường
   ENUM_MARKET_CONDITION GetMarketCondition()
   {
      double adx = iADX(_Symbol, PERIOD_CURRENT, m_adxPeriod, PRICE_CLOSE, MODE_MAIN, 0);
      double atr = iATR(_Symbol, PERIOD_CURRENT, 14, 0);
      double atr50 = iATR(_Symbol, PERIOD_CURRENT, 50, 0);
      
      // Kiểm tra biến động
      bool isVolatile = atr > atr50 * 1.5;
      
      if(isVolatile && adx < m_adxRangingThreshold)
         return MARKET_CONDITION_VOLATILE;
      else if(adx > m_adxTrendingThreshold)
         return MARKET_CONDITION_TRENDING;
      else if(adx < m_adxRangingThreshold)
         return MARKET_CONDITION_RANGING;
      else
         return MARKET_CONDITION_TRANSITION;
   }
   
   // Thêm kết quả giao dịch mới
   void AddTradeResult(const STradeResult &result)
   {
      m_totalTrades++;
      
      // Cập nhật thống kê chung
      if(result.profit > 0)
      {
         m_wins++;
         m_totalProfit += result.profit;
      }
      else
      {
         m_losses++;
         m_totalLoss += MathAbs(result.profit);
      }
      
      // Cập nhật theo chất lượng setup
      switch(result.setupQuality)
      {
         case SETUP_QUALITY_A_PLUS:
            m_setupAPlusTrades++;
            if(result.profit > 0) m_setupAPlusWins++;
            break;
         case SETUP_QUALITY_A:
            m_setupATrades++;
            if(result.profit > 0) m_setupAWins++;
            break;
         case SETUP_QUALITY_B:
            m_setupBTrades++;
            if(result.profit > 0) m_setupBWins++;
            break;
      }
      
      // Lưu vào danh sách giao dịch gần đây
      if(m_recentTradeCount < 100)
      {
         m_recentTrades[m_recentTradeCount] = result;
         m_recentTradeCount++;
      }
      else
      {
         // Dịch chuyển mảng để xóa bỏ giao dịch cũ nhất
         for(int i = 0; i < 99; i++)
            m_recentTrades[i] = m_recentTrades[i + 1];
         
         m_recentTrades[99] = result;
      }
      
      // Cập nhật drawdown
      double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(currentEquity > m_peakEquity)
         m_peakEquity = currentEquity;
      
      m_currentDrawdown = (m_peakEquity - currentEquity) / m_peakEquity;
      if(m_currentDrawdown > m_maxDrawdown)
         m_maxDrawdown = m_currentDrawdown;
      
      // Thiết lập baseline nếu đủ dữ liệu và chưa có
      if(!m_hasBaselineSet && m_totalTrades >= 30)
      {
         SetBaselinePerformance();
      }
   }
   
   // Thiết lập hiệu suất cơ sở (baseline)
   void SetBaselinePerformance()
   {
      SEdgePerformanceResult performance;
      
      performance.totalTrades = m_totalTrades;
      performance.winRate = m_totalTrades > 0 ? (double)m_wins / m_totalTrades : 0;
      
      performance.averageWin = m_wins > 0 ? m_totalProfit / m_wins : 0;
      performance.averageLoss = m_losses > 0 ? m_totalLoss / m_losses : 0;
      
      performance.expectancy = performance.winRate * performance.averageWin - 
                             (1 - performance.winRate) * performance.averageLoss;
                             
      performance.profitFactor = m_totalLoss > 0 ? m_totalProfit / m_totalLoss : 0;
      
      performance.maxDrawdown = m_maxDrawdown;
      
      m_baselinePerformance = performance;
      m_hasBaselineSet = true;
   }
   
   // Lấy kết quả hiệu suất hiện tại
   SEdgePerformanceResult GetCurrentPerformance()
   {
      SEdgePerformanceResult performance;
      
      performance.totalTrades = m_totalTrades;
      performance.winRate = m_totalTrades > 0 ? (double)m_wins / m_totalTrades : 0;
      
      performance.averageWin = m_wins > 0 ? m_totalProfit / m_wins : 0;
      performance.averageLoss = m_losses > 0 ? m_totalLoss / m_losses : 0;
      
      performance.expectancy = performance.winRate * performance.averageWin - 
                             (1 - performance.winRate) * performance.averageLoss;
                             
      performance.profitFactor = m_totalLoss > 0 ? m_totalProfit / m_totalLoss : 0;
      
      performance.maxDrawdown = m_maxDrawdown;
      
      return performance;
   }
   
   // Lấy hiệu suất của 30 giao dịch gần nhất
   SEdgePerformanceResult GetRecentPerformance(int count = 30)
   {
      SEdgePerformanceResult performance;
      ResetPerformanceData(performance);
      
      if(m_recentTradeCount == 0)
         return performance;
      
      int trades = MathMin(count, m_recentTradeCount);
      int wins = 0;
      double totalProfit = 0.0;
      double totalLoss = 0.0;
      
      for(int i = m_recentTradeCount - trades; i < m_recentTradeCount; i++)
      {
         if(i < 0) continue;
         
         if(m_recentTrades[i].profit > 0)
         {
            wins++;
            totalProfit += m_recentTrades[i].profit;
         }
         else
         {
            totalLoss += MathAbs(m_recentTrades[i].profit);
         }
      }
      
      performance.totalTrades = trades;
      performance.winRate = trades > 0 ? (double)wins / trades : 0;
      
      int losses = trades - wins;
      performance.averageWin = wins > 0 ? totalProfit / wins : 0;
      performance.averageLoss = losses > 0 ? totalLoss / losses : 0;
      
      performance.expectancy = performance.winRate * performance.averageWin - 
                             (1 - performance.winRate) * performance.averageLoss;
                             
      performance.profitFactor = totalLoss > 0 ? totalProfit / totalLoss : 0;
      
      // Tính maxDrawdown đơn giản
      double peak = 0.0;
      double currentBalance = 0.0;
      double maxDD = 0.0;
      
      for(int i = m_recentTradeCount - trades; i < m_recentTradeCount; i++)
      {
         if(i < 0) continue;
         
         currentBalance += m_recentTrades[i].profit;
         if(currentBalance > peak) peak = currentBalance;
         
         double dd = (peak - currentBalance) / (peak > 0 ? peak : 1);
         if(dd > maxDD) maxDD = dd;
      }
      
      performance.maxDrawdown = maxDD;
      
      return performance;
   }
   
   // Kiểm tra suy giảm Edge
   SEdgeDegradation CheckEdgeDegradation()
   {
      SEdgeDegradation result;
      result.hasDegradation = false;
      result.degradationPercent = 0.0;
      result.messages = "";
      result.recommendations = "";
      
      // Cần có baseline và ít nhất 30 giao dịch gần đây để đánh giá
      if(!m_hasBaselineSet || m_recentTradeCount < 30)
      {
         result.messages = "Chưa đủ dữ liệu để đánh giá suy giảm Edge";
         return result;
      }
      
      // Lấy hiệu suất 30 giao dịch gần nhất
      SEdgePerformanceResult recentPerf = GetRecentPerformance(30);
      
      // So sánh với baseline
      double winRateDegradation = (m_baselinePerformance.winRate - recentPerf.winRate) / m_baselinePerformance.winRate;
      double expectancyDegradation = (m_baselinePerformance.expectancy - recentPerf.expectancy) / 
                                    (MathAbs(m_baselinePerformance.expectancy) > 0.001 ? m_baselinePerformance.expectancy : 0.001);
      double pfDegradation = (m_baselinePerformance.profitFactor - recentPerf.profitFactor) / 
                            (m_baselinePerformance.profitFactor > 0.001 ? m_baselinePerformance.profitFactor : 0.001);
      
      // Đánh giá mức độ suy giảm
      int degradationLevel = 0; // 0: Không, 1: Nhẹ, 2: Trung bình, 3: Nghiêm trọng
      
      if(winRateDegradation > 0.25 || expectancyDegradation > 0.30 || pfDegradation > 0.35)
      {
         degradationLevel = 3; // Nghiêm trọng
      }
      else if(winRateDegradation > 0.15 || expectancyDegradation > 0.20 || pfDegradation > 0.25)
      {
         degradationLevel = 2; // Trung bình
      }
      else if(winRateDegradation > 0.10 || expectancyDegradation > 0.15 || pfDegradation > 0.15)
      {
         degradationLevel = 1; // Nhẹ
      }
      
      // Tổng hợp kết quả
      if(degradationLevel > 0)
      {
         result.hasDegradation = true;
         result.degradationPercent = MathMax(winRateDegradation, MathMax(expectancyDegradation, pfDegradation)) * 100.0;
         
         // Thông báo
         switch(degradationLevel)
         {
            case 1:
               result.messages = "Phát hiện suy giảm Edge nhẹ. Win Rate giảm " + 
                               DoubleToString(winRateDegradation * 100, 1) + "%, Expectancy giảm " + 
                               DoubleToString(expectancyDegradation * 100, 1) + "%.";
               result.recommendations = "Tiếp tục theo dõi hiệu suất sát sao. Ghi chép chi tiết hơn về điều kiện thị trường.";
               break;
            case 2:
               result.messages = "Phát hiện suy giảm Edge trung bình. Win Rate giảm " + 
                               DoubleToString(winRateDegradation * 100, 1) + "%, Expectancy giảm " + 
                               DoubleToString(expectancyDegradation * 100, 1) + "%, Profit Factor giảm " +
                               DoubleToString(pfDegradation * 100, 1) + "%.";
               result.recommendations = "Giảm kích thước vị thế xuống 50-75%. Chỉ giao dịch setup A+ cho đến khi hiệu suất cải thiện. Kiểm tra lại các tham số chiến lược.";
               break;
            case 3:
               result.messages = "Phát hiện suy giảm Edge nghiêm trọng! Win Rate giảm " + 
                               DoubleToString(winRateDegradation * 100, 1) + "%, Expectancy giảm " + 
                               DoubleToString(expectancyDegradation * 100, 1) + "%, Profit Factor giảm " +
                               DoubleToString(pfDegradation * 100, 1) + "%.";
               result.recommendations = "Tạm dừng giao dịch chiến lược này. Tiến hành kiểm tra toàn diện chiến lược. Đánh giá sự thay đổi trong điều kiện thị trường. Cân nhắc điều chỉnh đáng kể hoặc chuyển sang chiến lược khác.";
               break;
         }
      }
      else
      {
         result.messages = "Edge vẫn ổn định. Không phát hiện suy giảm đáng kể.";
         result.recommendations = "Tiếp tục chiến lược hiện tại.";
      }
      
      return result;
   }
   
   // Lấy tổng số giao dịch đã theo dõi
   int GetTotalTrades() const
   {
      return m_totalTrades;
   }
   
   // Lấy hiệu suất theo chất lượng setup
   double GetWinRateByQuality(ENUM_SETUP_QUALITY quality)
   {
      switch(quality)
      {
         case SETUP_QUALITY_A_PLUS:
            return m_setupAPlusTrades > 0 ? ((double)m_setupAPlusWins / (double)m_setupAPlusTrades) : 0.0;
         case SETUP_QUALITY_A:
            return m_setupATrades > 0 ? ((double)m_setupAWins / (double)m_setupATrades) : 0.0;
         case SETUP_QUALITY_B:
            return m_setupBTrades > 0 ? ((double)m_setupBWins / (double)m_setupBTrades) : 0.0;
         default:
            return 0.0;
      }
   }
   
   // Lấy hiệu suất theo điều kiện thị trường
   double GetWinRateByMarketCondition(ENUM_MARKET_CONDITION condition)
   {
      switch(condition)
      {
         case MARKET_CONDITION_TRENDING:
            return m_trendingTrades > 0 ? ((double)m_trendingWins / (double)m_trendingTrades) : 0.0;
         case MARKET_CONDITION_RANGING:
            return m_rangingTrades > 0 ? ((double)m_rangingWins / (double)m_rangingTrades) : 0.0;
         case MARKET_CONDITION_VOLATILE:
            return m_volatileTrades > 0 ? ((double)m_volatileWins / (double)m_volatileTrades) : 0.0;
         default:
            return 0.0;
      }
   }
   
private:
   // Reset dữ liệu hiệu suất
   void ResetPerformanceData(SEdgePerformanceResult &data)
   {
      data.totalTrades = 0;
      data.winRate = 0.0;
      data.expectancy = 0.0;
      data.profitFactor = 0.0;
      data.averageWin = 0.0;
      data.averageLoss = 0.0;
      data.maxDrawdown = 0.0;
   }
};