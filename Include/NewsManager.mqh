//+------------------------------------------------------------------+
//|                                                NewsManager.mqh |
//|                        Copyright 2025, Your Company               |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"

class CNewsManager
{
private:
   bool              m_enabled;           // Trạng thái bật/tắt
   datetime          m_newsTime[];        // Mảng thời gian tin tức
   string            m_newsTitle[];       // Mảng tiêu đề tin tức
   ENUM_NEWS_IMPACT  m_newsImpact[];      // Mảng mức độ ảnh hưởng
   int               m_newsCount;         // Số lượng tin tức
   datetime          m_lastUpdate;        // Thời gian cập nhật cuối
   int               m_minutesBefore;     // Số phút tránh trước tin
   int               m_minutesAfter;      // Số phút tránh sau tin

public:
   // Constructor
   CNewsManager() 
   {
      m_enabled = false;
      m_newsCount = 0;
      m_lastUpdate = 0;
      m_minutesBefore = 30;   // Mặc định: tránh 30 phút trước tin
      m_minutesAfter = 30;    // Mặc định: tránh 30 phút sau tin
   }
   
   // Destructor
   ~CNewsManager() { }
   
   // Hàm khởi tạo
   bool Init(bool enabled, int minutesBefore = 30, int minutesAfter = 30)
   {
      m_enabled = enabled;
      m_minutesBefore = minutesBefore;
      m_minutesAfter = minutesAfter;
      
      if(m_enabled)
      {
         // Cập nhật dữ liệu tin tức ngay từ đầu
         return UpdateNewsData();
      }
      
      return true;
   }
   
   // Hàm dọn dẹp
   void Deinit()
   {
      ArrayFree(m_newsTime);
      ArrayFree(m_newsTitle);
      ArrayFree(m_newsImpact);
      m_newsCount = 0;
   }
   
   // Cập nhật dữ liệu tin tức
   bool UpdateNewsData()
   {
      if(!m_enabled)
         return false;
         
      // Trong môi trường thực, bạn sẽ lấy dữ liệu từ API hoặc từ tệp
      // Đây là mã mẫu để mô phỏng
      
      // Xóa dữ liệu cũ
      ArrayFree(m_newsTime);
      ArrayFree(m_newsTitle);
      ArrayFree(m_newsImpact);
      
      // Lấy dữ liệu tin tức mới (ví dụ từ tệp hoặc API)
      // Đoạn này cần được triển khai theo nguồn dữ liệu cụ thể
      
      // Mô phỏng: Thêm một số tin tức mẫu cho 2 ngày
      datetime currentTime = TimeCurrent();
      datetime today = currentTime - TimeSeconds(currentTime);
      datetime tomorrow = today + 86400; // Thêm 1 ngày
      
      // Thêm các tin tức mẫu
      AddNews(today + 10*3600, "Non-Farm Payroll", NEWS_IMPACT_HIGH);
      AddNews(today + 14*3600, "FOMC Statement", NEWS_IMPACT_HIGH);
      AddNews(today + 16*3600, "Unemployment Rate", NEWS_IMPACT_MEDIUM);
      AddNews(tomorrow + 8*3600, "GDP", NEWS_IMPACT_HIGH);
      AddNews(tomorrow + 12*3600, "Retail Sales", NEWS_IMPACT_MEDIUM);
      
      m_lastUpdate = TimeCurrent();
      return true;
   }
   
   // Thêm tin tức vào mảng
   void AddNews(datetime time, string title, ENUM_NEWS_IMPACT impact)
   {
      m_newsCount++;
      ArrayResize(m_newsTime, m_newsCount);
      ArrayResize(m_newsTitle, m_newsCount);
      ArrayResize(m_newsImpact, m_newsCount);
      
      m_newsTime[m_newsCount-1] = time;
      m_newsTitle[m_newsCount-1] = title;
      m_newsImpact[m_newsCount-1] = impact;
   }
   
   // Kiểm tra xem hiện tại có tin tức quan trọng không
   bool IsHighImpactNews()
   {
      if(!m_enabled)
         return false;
         
      // Cập nhật dữ liệu tin tức nếu đã quá 12 giờ
      if(TimeCurrent() - m_lastUpdate > 12*3600)
         UpdateNewsData();
         
      datetime currentTime = TimeCurrent();
      
      for(int i = 0; i < m_newsCount; i++)
      {
         // Chỉ quan tâm tin tức có mức độ ảnh hưởng cao
         if(m_newsImpact[i] == NEWS_IMPACT_HIGH)
         {
            // Kiểm tra xem thời gian hiện tại có nằm trong khoảng cần tránh
            if(currentTime >= m_newsTime[i] - m_minutesBefore*60 && 
               currentTime <= m_newsTime[i] + m_minutesAfter*60)
            {
               return true;
            }
         }
      }
      
      return false;
   }
   
   // Lấy thông tin tin tức sắp diễn ra
   string GetUpcomingNewsInfo()
   {
      if(!m_enabled)
         return "News filter disabled";
         
      string info = "";
      datetime currentTime = TimeCurrent();
      bool hasUpcoming = false;
      
      for(int i = 0; i < m_newsCount; i++)
      {
         // Chỉ hiển thị tin trong 24 giờ tới
         if(m_newsTime[i] > currentTime && m_newsTime[i] - currentTime < 24*3600)
         {
            string impactStr = "";
            switch(m_newsImpact[i])
            {
               case NEWS_IMPACT_LOW: impactStr = "Low"; break;
               case NEWS_IMPACT_MEDIUM: impactStr = "Medium"; break;
               case NEWS_IMPACT_HIGH: impactStr = "High"; break;
            }
            
            info += TimeToString(m_newsTime[i], TIME_DATE|TIME_MINUTES) + 
                   " - " + m_newsTitle[i] + " (" + impactStr + ")\n";
            hasUpcoming = true;
         }
      }
      
      if(!hasUpcoming)
         info = "No upcoming high-impact news";
         
      return info;
   }
};