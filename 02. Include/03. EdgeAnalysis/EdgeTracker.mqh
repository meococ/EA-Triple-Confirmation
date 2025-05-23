//+------------------------------------------------------------------+
//|                                             EdgeTracker.mqh      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"

#include "CommonDefinitions.mqh"

// Định nghĩa các hằng số nếu chưa được định nghĩa
#ifndef MODE_MAIN
#define MODE_MAIN 0  // Mode chính cho iADX
#endif

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
      // Tạo handle cho các indicator
      int adxHandle_local = iADX(_Symbol, PERIOD_CURRENT, m_adxPeriod);
      int atrHandle_local = iATR(_Symbol, PERIOD_CURRENT, 14);
      int atr50Handle_local = iATR(_Symbol, PERIOD_CURRENT, 50);
      
      if(adxHandle_local == INVALID_HANDLE || atrHandle_local == INVALID_HANDLE || atr50Handle_local == INVALID_HANDLE)
      {
         Print("Error creating indicator handles");
         return MARKET_CONDITION_UNDEFINED;
      }
      
      // Copy buffer data
      double adxBuffer[], atrBuffer[], atr50Buffer[];
      ArraySetAsSeries(adxBuffer, true);
      ArraySetAsSeries(atrBuffer, true);
      ArraySetAsSeries(atr50Buffer, true);
      
      if(CopyBuffer(adxHandle_local, 0, 0, 1, adxBuffer) <= 0 ||
         CopyBuffer(atrHandle_local, 0, 0, 1, atrBuffer) <= 0 ||
         CopyBuffer(atr50Handle_local, 0, 0, 1, atr50Buffer) <= 0)
      {
         Print("Error copying indicator buffers");
         
         // Giải phóng handles
         IndicatorRelease(adxHandle_local);
         IndicatorRelease(atrHandle_local);
         IndicatorRelease(atr50Handle_local);
         
         return MARKET_CONDITION_UNDEFINED;
      }
      
      // Lấy giá trị từ buffer
      double adx = adxBuffer[0];
      double atr = atrBuffer[0];
      double atr50 = atr50Buffer[0];
      
      // Giải phóng handles sau khi sử dụng
      IndicatorRelease(adxHandle_local);
      IndicatorRelease(atrHandle_local);
      IndicatorRelease(atr50Handle_local);
      
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
      
      // Tính Z-score cho sự khác biệt về Win Rate
      double zScore = CalculateWinRateZScore(
         m_baselinePerformance.winRate, m_baselinePerformance.totalTrades,
         recentPerf.winRate, recentPerf.totalTrades
      );
      
      // So sánh với baseline
      double winRateDegradation = 0.0;
      if(m_baselinePerformance.winRate > 0.001)
         winRateDegradation = (m_baselinePerformance.winRate - recentPerf.winRate) / m_baselinePerformance.winRate;
      
      double expectancyDegradation = 0.0;
      if(MathAbs(m_baselinePerformance.expectancy) > 0.001)
         expectancyDegradation = (m_baselinePerformance.expectancy - recentPerf.expectancy) / MathAbs(m_baselinePerformance.expectancy);
      
      double pfDegradation = 0.0;
      if(m_baselinePerformance.profitFactor > 0.001)
         pfDegradation = (m_baselinePerformance.profitFactor - recentPerf.profitFactor) / m_baselinePerformance.profitFactor;
      
      // Đánh giá mức độ suy giảm theo tiêu chuẩn trong sách trắng phần 3.4.2
      int degradationLevel = 0; // 0: Không, 1: Nhẹ, 2: Trung bình, 3: Nghiêm trọng
      
      bool isSignificant = zScore > 1.96; // 95% confidence level
      bool isNegative = recentPerf.winRate < m_baselinePerformance.winRate;
      
      if(isSignificant && isNegative)
      {
         degradationLevel = MathMax(degradationLevel, 2);
      }
      
      if(winRateDegradation > 0.25 || expectancyDegradation > 0.30 || pfDegradation > 0.35)
      {
         degradationLevel = 3; // Severe Decay
      }
      else if(winRateDegradation > 0.15 || expectancyDegradation > 0.20 || pfDegradation > 0.25)
      {
         degradationLevel = 2; // Moderate Decay
      }
      else if(winRateDegradation > 0.10 || expectancyDegradation > 0.15 || pfDegradation > 0.15)
      {
         degradationLevel = 1; // Minor Decay
      }
      
      // Tổng hợp kết quả
      if(degradationLevel > 0)
      {
         result.hasDegradation = true;
         result.degradationPercent = MathMax(winRateDegradation, MathMax(expectancyDegradation, pfDegradation)) * 100.0;
         
         // Thông báo và khuyến nghị theo mức độ suy giảm
         string winRateStr = DoubleToString(winRateDegradation * 100, 1);
         string expectancyStr = DoubleToString(expectancyDegradation * 100, 1);
         string pfStr = DoubleToString(pfDegradation * 100, 1);
         
         switch(degradationLevel)
         {
            case 1: // Minor Decay
               result.messages = "Phát hiện suy giảm Edge nhẹ. Win Rate giảm " + winRateStr + "%, Expectancy giảm " + expectancyStr + "%.";
               result.recommendations = "Tiếp tục theo dõi hiệu suất sát sao. Ghi chép chi tiết hơn về điều kiện thị trường.";
               break;
               
            case 2: // Moderate Decay
               result.messages = "Phát hiện suy giảm Edge trung bình. Win Rate giảm " + winRateStr + "%, Expectancy giảm " + expectancyStr + "%, Profit Factor giảm " + pfStr + "%.";
               result.recommendations = "Giảm kích thước vị thế xuống 50-75%. Chỉ giao dịch setup A+ cho đến khi hiệu suất cải thiện. Kiểm tra lại các tham số chiến lược.";
               break;
               
            case 3: // Severe Decay
               result.messages = "Phát hiện suy giảm Edge nghiêm trọng! Win Rate giảm " + winRateStr + "%, Expectancy giảm " + expectancyStr + "%, Profit Factor giảm " + pfStr + "%.";
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
   
   // Tính Z-score cho win rate
   double CalculateWinRateZScore(double baselineWR, int baselineTrades, double currentWR, int currentTrades)
   {
      // Tính pooled proportion
      double pooledProportion = (baselineWR * baselineTrades + currentWR * currentTrades) / (baselineTrades + currentTrades);
      
      // Tính standard error
      double standardError = MathSqrt(pooledProportion * (1 - pooledProportion) * (1.0/baselineTrades + 1.0/currentTrades));
      
      // Tính Z-score
      if(standardError > 0)
         return MathAbs((baselineWR - currentWR) / standardError);
      
      return 0;
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
   
   // Cập nhật hiệu suất theo điều kiện thị trường
   void UpdateMarketConditionPerformance(ENUM_MARKET_CONDITION condition, bool isWin)
   {
      switch(condition)
      {
         case MARKET_CONDITION_TRENDING:
            m_trendingTrades++;
            if(isWin) m_trendingWins++;
            break;
         case MARKET_CONDITION_RANGING:
            m_rangingTrades++;
            if(isWin) m_rangingWins++;
            break;
         case MARKET_CONDITION_VOLATILE:
            m_volatileTrades++;
            if(isWin) m_volatileWins++;
            break;
      }
   }
   
   // Phân tích xu hướng Edge
   void AnalyzeEdgeTrend(int windowSize = 20, int steps = 5)
   {
      if(m_totalTrades < windowSize * steps)
      {
         Print("Không đủ dữ liệu để phân tích xu hướng Edge");
         return;
      }
      
      double winRates[];
      ArrayResize(winRates, steps);
      
      for(int i = 0; i < steps; i++)
      {
         int startIdx = m_totalTrades - windowSize * (steps - i);
         int endIdx = startIdx + windowSize;
         
         // Tính win rate cho window này
         int wins = 0;
         for(int j = startIdx; j < endIdx; j++)
         {
            if(j >= 0 && j < m_recentTradeCount)
            {
               // Giả định m_recentTrades có trường để kiểm tra thắng/thua
               if(m_recentTrades[j].profit > 0)
                  wins++;
            }
         }
         
         winRates[i] = (double)wins / windowSize;
      }
      
      // Tính slope của linear regression
      double slope = CalculateSlope(winRates);
      
      if(slope > 0.01)
         Print("Edge đang cải thiện: Slope = ", DoubleToString(slope, 4));
      else if(slope < -0.01)
         Print("Edge đang suy giảm: Slope = ", DoubleToString(slope, 4));
      else
         Print("Edge ổn định: Slope = ", DoubleToString(slope, 4));
   }
   
   // Hàm tính slope của linear regression
   double CalculateSlope(double &values[])
   {
      int n = ArraySize(values);
      if(n < 2)
         return 0;
      
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      
      for(int i = 0; i < n; i++)
      {
         double x = i + 1;
         double y = values[i];
         
         sumX += x;
         sumY += y;
         sumXY += x * y;
         sumX2 += x * x;
      }
      
      // Công thức tính slope: (n*sumXY - sumX*sumY) / (n*sumX2 - sumX*sumX)
      return (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
   }
};