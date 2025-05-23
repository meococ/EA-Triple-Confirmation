//+------------------------------------------------------------------+
//|                                           EdgeCalculator.mqh |
//|                        Copyright 2025, Your Company               |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"

#include "CommonDefinitions.mqh"

// Cấu trúc lưu thông tin hiệu suất
struct SPerformanceStats
{
   int      totalTrades;
   int      winTrades;
   int      lossTrades;
   double   winRate;
   double   avgWin;
   double   avgLoss;
   double   expectancy;
   double   profitFactor;
   double   maxDrawdown;
   double   sharpeRatio;
};

// Cấu trúc lưu thông tin suy giảm Edge - Sử dụng local version khác với CommonDefinitions
struct SEdgeDegradationLocal
{
   bool     hasDegradation;
   int      degradationLevel;  // 1: Nhẹ, 2: Trung bình, 3: Nghiêm trọng
   string   message;
   double   winRateChange;
   double   expectancyChange;
   double   profitFactorChange;
};

// Cấu trúc lưu kết quả giao dịch - Sử dụng local version khác với CommonDefinitions
struct STradeResultLocal
{
   double   profit;      // Lợi nhuận
   double   pips;        // Số pip
   datetime openTime;    // Thời gian mở lệnh
   datetime closeTime;   // Thời gian đóng lệnh
   string   symbol;      // Cặp tiền
   int      type;        // Loại lệnh (BUY/SELL)
};

class CEdgeCalculator
{
private:
   string            m_eaName;
   int               m_baselineTrades;
   int               m_currentTrades;
   SPerformanceStats m_baselinePerformance;
   SPerformanceStats m_currentPerformance;
   double            m_profits[];
   double            m_losses[];
   
   // Tính độ lệch chuẩn
   double CalculateStdDev(double &array[], double mean, int count)
   {
      if(count < 2)
         return 0.0;
         
      double sumSqDiff = 0;
      for(int i = 0; i < count; i++)
      {
         sumSqDiff += MathPow(array[i] - mean, 2);
      }
      
      return MathSqrt(sumSqDiff / (count - 1));
   }
   
   // Tính Sharpe Ratio
   double CalculateSharpeRatio(double &array[], int count)
   {
      if(count < 2)
         return 0.0;
         
      double sum = 0;
      for(int i = 0; i < count; i++)
      {
         sum += array[i];
      }
      
      double mean = sum / count;
      double stdDev = CalculateStdDev(array, mean, count);
      
      if(stdDev == 0)
         return 0.0;
         
      return mean / stdDev;
   }
   
   // Tính max drawdown
   double CalculateMaxDrawdown(double &profits[], double &losses[], int profitCount, int lossCount)
   {
      int totalTrades = profitCount + lossCount;
      
      if(totalTrades < 2)
         return 0.0;
         
      // Tạo mảng P&L tích lũy
      double cumulative[];
      ArrayResize(cumulative, totalTrades);
      
      // Sắp xếp các giao dịch theo thứ tự (giả định)
      double tradeResults[];
      ArrayResize(tradeResults, totalTrades);
      
      // Tạo mảng kết quả trade (đơn giản hóa)
      for(int i = 0; i < profitCount; i++)
         tradeResults[i] = profits[i];
         
      for(int i = 0; i < lossCount; i++)
         tradeResults[profitCount + i] = -losses[i];
      
      // Tính P&L tích lũy
      cumulative[0] = tradeResults[0];
      double peak = MathMax(0, cumulative[0]);
      double maxDD = 0;
      
      for(int i = 1; i < totalTrades; i++)
      {
         cumulative[i] = cumulative[i-1] + tradeResults[i];
         
         peak = MathMax(peak, cumulative[i]);
         double drawdown = (peak - cumulative[i]) / peak;
         maxDD = MathMax(maxDD, drawdown);
      }
      
      return maxDD;
   }

public:
   // Constructor
   CEdgeCalculator()
   {
      m_eaName = "EA";
      m_baselineTrades = 0;
      m_currentTrades = 0;
   }
   
   // Destructor
   ~CEdgeCalculator() { }
   
   // Khởi tạo
   bool Init(string eaName)
   {
      m_eaName = eaName;
      
      // Khởi tạo các mảng
      ArrayFree(m_profits);
      ArrayFree(m_losses);
      
      // Reset thông tin hiệu suất
      m_baselinePerformance.totalTrades = 0;
      m_baselinePerformance.winTrades = 0;
      m_baselinePerformance.lossTrades = 0;
      m_baselinePerformance.winRate = 0;
      m_baselinePerformance.avgWin = 0;
      m_baselinePerformance.avgLoss = 0;
      m_baselinePerformance.expectancy = 0;
      m_baselinePerformance.profitFactor = 0;
      m_baselinePerformance.maxDrawdown = 0;
      
      m_currentPerformance = m_baselinePerformance;
      
      return true;
   }
   
   // Dọn dẹp
   void Deinit()
   {
      ArrayFree(m_profits);
      ArrayFree(m_losses);
   }
   
   // Thêm kết quả giao dịch
   void AddTradeResult(STradeResultLocal& result)
   {
      // Tăng số lượng giao dịch
      m_currentTrades++;
      
      // Thêm vào mảng thích hợp
      if(result.profit > 0)
      {
         int size = ArraySize(m_profits);
         ArrayResize(m_profits, size + 1);
         m_profits[size] = result.profit;
      }
      else if(result.profit < 0)
      {
         int size = ArraySize(m_losses);
         ArrayResize(m_losses, size + 1);
         m_losses[size] = MathAbs(result.profit);
      }
      
      // Cập nhật hiệu suất hiện tại
      UpdatePerformanceStats();
      
      // Thiết lập baseline nếu đủ dữ liệu
      if(m_baselineTrades == 0 && m_currentTrades >= 30)
      {
         SetBaseline();
      }
   }
   
   // Cập nhật thống kê hiệu suất
   void UpdatePerformanceStats()
   {
      int winCount = ArraySize(m_profits);
      int lossCount = ArraySize(m_losses);
      int totalTrades = winCount + lossCount;
      
      if(totalTrades == 0)
         return;
      
      m_currentPerformance.totalTrades = totalTrades;
      m_currentPerformance.winTrades = winCount;
      m_currentPerformance.lossTrades = lossCount;
      m_currentPerformance.winRate = (double)winCount / totalTrades;
      
      // Tính toán các chỉ số khác
      double totalProfit = 0;
      double totalLoss = 0;
      
      for(int i = 0; i < winCount; i++)
         totalProfit += m_profits[i];
         
      for(int i = 0; i < lossCount; i++)
         totalLoss += m_losses[i];
      
      m_currentPerformance.avgWin = winCount > 0 ? totalProfit / winCount : 0;
      m_currentPerformance.avgLoss = lossCount > 0 ? totalLoss / lossCount : 0;
      
      m_currentPerformance.expectancy = m_currentPerformance.winRate * m_currentPerformance.avgWin - 
                                      (1 - m_currentPerformance.winRate) * m_currentPerformance.avgLoss;
      
      m_currentPerformance.profitFactor = totalLoss > 0 ? totalProfit / totalLoss : totalProfit > 0 ? 100 : 0;
      
      // Tính max drawdown
      m_currentPerformance.maxDrawdown = CalculateMaxDrawdown(m_profits, m_losses, winCount, lossCount);
      
      // Tính Sharpe Ratio - đơn giản hóa
      double allTrades[];
      ArrayResize(allTrades, totalTrades);
      
      for(int i = 0; i < winCount; i++)
         allTrades[i] = m_profits[i];
         
      for(int i = 0; i < lossCount; i++)
         allTrades[winCount + i] = -m_losses[i];
      
      m_currentPerformance.sharpeRatio = CalculateSharpeRatio(allTrades, totalTrades);
   }
   
   // Thiết lập hiệu suất baseline
   void SetBaseline()
   {
      m_baselineTrades = m_currentTrades;
      m_baselinePerformance = m_currentPerformance;
   }
   
   // Kiểm tra suy giảm Edge
   SEdgeDegradationLocal CheckEdgeDegradation()
   {
      SEdgeDegradationLocal result;
      result.hasDegradation = false;
      result.degradationLevel = 0;
      result.message = "";
      
      // Kiểm tra xem có đủ dữ liệu cho baseline không
      if(m_baselineTrades < 30)
      {
         result.message = "Không đủ dữ liệu baseline để đánh giá";
         return result;
      }
      
      // Kiểm tra xem có đủ dữ liệu hiện tại không
      if(m_currentTrades - m_baselineTrades < 20)
      {
         result.message = "Cần ít nhất 20 giao dịch mới để đánh giá suy giảm Edge";
         return result;
      }
      
      // Tính toán sự thay đổi
      result.winRateChange = m_currentPerformance.winRate - m_baselinePerformance.winRate;
      result.expectancyChange = (m_currentPerformance.expectancy - m_baselinePerformance.expectancy) / 
                               MathAbs(m_baselinePerformance.expectancy);
      result.profitFactorChange = (m_currentPerformance.profitFactor - m_baselinePerformance.profitFactor) / 
                                 m_baselinePerformance.profitFactor;
      
      // Đánh giá mức độ suy giảm
      if(result.winRateChange < -0.1 || 
         result.expectancyChange < -0.2 || 
         result.profitFactorChange < -0.25)
      {
         result.hasDegradation = true;
         
         // Xác định mức độ
         if(result.winRateChange < -0.15 || 
            result.expectancyChange < -0.3 || 
            result.profitFactorChange < -0.4)
         {
            result.degradationLevel = 3;  // Nghiêm trọng
            result.message = "Suy giảm Edge nghiêm trọng: Cân nhắc tạm dừng giao dịch và đánh giá lại chiến lược";
         }
         else if(result.winRateChange < -0.12 || 
                result.expectancyChange < -0.25 || 
                result.profitFactorChange < -0.3)
         {
            result.degradationLevel = 2;  // Trung bình
            result.message = "Suy giảm Edge trung bình: Giảm size xuống 50%, chỉ giao dịch setup A+";
         }
         else
         {
            result.degradationLevel = 1;  // Nhẹ
            result.message = "Suy giảm Edge nhẹ: Theo dõi sát hiệu suất trong 10 giao dịch tiếp theo";
         }
      }
      
      return result;
   }
   
   // Lấy số giao dịch tổng cộng
   int GetTotalTrades()
   {
      return m_currentTrades;
   }
   
   // Lấy thông tin hiệu suất hiện tại
   SPerformanceStats GetCurrentPerformance()
   {
      return m_currentPerformance;
   }
};