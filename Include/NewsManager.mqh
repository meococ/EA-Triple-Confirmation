//+------------------------------------------------------------------+
//|                                                NewsManager.mqh |
//|                        Copyright 2025, Your Company               |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"

// Enum cho mức độ ảnh hưởng tin tức
enum ENUM_NEWS_IMPACT
{
   NEWS_IMPACT_LOW,     // Ảnh hưởng thấp
   NEWS_IMPACT_MEDIUM,  // Ảnh hưởng trung bình
   NEWS_IMPACT_HIGH     // Ảnh hưởng cao
};

//+------------------------------------------------------------------+
//| Class quản lý tin tức                                            |
//| Chú ý: Tất cả các biến integer khi sử dụng trong phép nối chuỗi  |
//| đều cần chuyển đổi tường minh bằng IntegerToString() để tránh    |
//| cảnh báo chuyển đổi kiểu ngầm định từ 'int' sang 'string'       |
//+------------------------------------------------------------------+
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

   // Hàm đếm số lần xuất hiện của chuỗi con
   int CountSubstring(string text, string substring)
   {
       int count = 0;
       int pos = 0;
       
       while((pos = StringFind(text, substring, pos)) != -1)
       {
           count++;
           pos += StringLen(substring);
       }
       
       return count;
   }

   // Ánh xạ cặp tiền tới các đồng tiền thành phần
   void GetCurrenciesFromPair(string symbol, string &currencies[])
   {
       ArrayResize(currencies, 2);
       
       // Xử lý cặp tiền chuẩn 6 ký tự
       if(StringLen(symbol) >= 6)
       {
           currencies[0] = StringSubstr(symbol, 0, 3);
           currencies[1] = StringSubstr(symbol, 3, 3);
           return;
       }
       
       // Xử lý trường hợp đặc biệt
       if(StringFind(symbol, "XAU") >= 0) currencies[0] = "XAU";
       if(StringFind(symbol, "USD") >= 0) currencies[1] = "USD";
       // Thêm các trường hợp đặc biệt khác nếu cần
   }
   
   // Lấy mã quốc gia từ đồng tiền
   string GetCountryFromCurrency(string currency)
   {
       if(currency == "USD") return "US";
       if(currency == "EUR") return "EU";
       if(currency == "GBP") return "GB";
       if(currency == "JPY") return "JP";
       if(currency == "AUD") return "AU";
       if(currency == "NZD") return "NZ";
       if(currency == "CAD") return "CA";
       if(currency == "CHF") return "CH";
       // Thêm ánh xạ khác nếu cần
       return "";
   }
   
   // Lấy dữ liệu từ lịch kinh tế MQL5
   bool FetchEconomicCalendarData()
   {
       // MQL5 Economic Calendar API
       string url = "https://www.mql5.com/en/economic-calendar/content";
       string cookies = NULL, headers;
       char post[], result[];
       
       // Lấy ngày hiện tại
       MqlDateTime dt;
       TimeToStruct(TimeCurrent(), dt);
       
       // Tạo request body (lấy tin trong 7 ngày tiếp theo)
       string data = StringFormat("date=%04d-%02d-%02d", dt.year, dt.mon, dt.day);
       StringToCharArray(data, post);
       
       // Gửi request
       int res = WebRequest("POST", url, NULL, NULL, 5000, post, ArraySize(post), result, headers);
       
       if(res == -1)
       {
           int error = GetLastError();
           Print("Error in WebRequest: ", error);
           if(error == 4060)
           {
               MessageBox("Please allow WebRequest for www.mql5.com in Tools->Options->Expert Advisors", 
                         "WebRequest Error", MB_ICONEXCLAMATION);
           }
           return false;
       }
       
       // Phân tích dữ liệu HTML
       string html = CharArrayToString(result);
       return ParseEconomicCalendarHTML(html);
   }
   
   // Phân tích HTML từ lịch kinh tế
   bool ParseEconomicCalendarHTML(string html)
   {
       // Reset dữ liệu tin tức
       ArrayFree(m_newsTime);
       ArrayFree(m_newsTitle);
       ArrayFree(m_newsImpact);
       m_newsCount = 0;
       
       // Tìm các mục tin tức trong HTML
       int pos = 0;
       while(true)
       {
           // Tìm mỗi sự kiện tin tức
           int startPos = StringFind(html, "<tr class=\"ec-table__row", pos);
           if(startPos == -1) break;
           
           // Tìm ngày và giờ
           int datePos = StringFind(html, "data-time=\"", startPos);
           if(datePos == -1) {
               pos = startPos + 1;
               continue;
           }
           
           datePos += 11; // Độ dài của "data-time=\""
           int dateEndPos = StringFind(html, "\"", datePos);
           string dateTimeStr = StringSubstr(html, datePos, dateEndPos - datePos);
           datetime newsTime = StringToTime(dateTimeStr);
           
           // Tìm tiêu đề tin tức
           int titlePos = StringFind(html, "class=\"ec-table__name\">", startPos);
           if(titlePos == -1) {
               pos = startPos + 1;
               continue;
           }
           
           titlePos += 23; // Độ dài của "class=\"ec-table__name\">"
           int titleEndPos = StringFind(html, "</div>", titlePos);
           string title = StringSubstr(html, titlePos, titleEndPos - titlePos);
           // Loại bỏ HTML tags
           
           title = StringReplace(title, "<span>", "");
           title = StringReplace(title, "</span>", "");
           
           // Tìm quốc gia
           int countryPos = StringFind(html, "class=\"ec-table__country\">", startPos);
           if(countryPos == -1) {
               pos = startPos + 1;
               continue;
           }
           
           countryPos += 25; // Độ dài của "class=\"ec-table__country\">"
           int countryEndPos = StringFind(html, "</div>", countryPos);
           string country = StringSubstr(html, countryPos, countryEndPos - countryPos);
           
           // Tìm mức độ ảnh hưởng (1-3 stars)
           int impactPos = StringFind(html, "class=\"ec-table__importance", startPos);
           if(impactPos == -1) {
               pos = startPos + 1;
               continue;
           }
           
           // Đếm số lượng sao (stars) - thay thế hàm StringCount
           string impactSection = StringSubstr(html, impactPos, 100);
           if(impactSection == "") {
               pos = startPos + 1;
               continue;
           }
           
           int starsCount = 0; // Đếm số sao để xác định mức độ ảnh hưởng, chỉ dùng cho so sánh
           int starPos = 0;
           while((starPos = StringFind(impactSection, "star", starPos)) != -1) {
               starsCount++;
               starPos += 4; // Độ dài của "star"
           }
           
           // Chuyển đổi sang ENUM_NEWS_IMPACT
           ENUM_NEWS_IMPACT impact;
           switch(starsCount)
           {
               case 3: impact = NEWS_IMPACT_HIGH; break;
               case 2: impact = NEWS_IMPACT_MEDIUM; break;
               default: impact = NEWS_IMPACT_LOW; break;
           }
           
           // Thêm tin tức vào danh sách (đảm bảo không có chuyển đổi ngầm từ int sang string)
           AddNews(newsTime, title + " (" + country + ")", impact);
           
           // Di chuyển tới vị trí tiếp theo
           pos = startPos + 1;
       }
       
       return m_newsCount > 0;
   }

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
      // Giải phóng bộ nhớ của các mảng
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
      
      // Gọi hàm lấy dữ liệu tin tức thực
      bool result = FetchEconomicCalendarData();
      
      if(result)
         m_lastUpdate = TimeCurrent();
         
      return result;
      
      // Mã mẫu dưới đây được giữ lại làm tham khảo hoặc để dùng cho kiểm thử
      /*   
      // Xóa dữ liệu cũ
      ArrayFree(m_newsTime);
      ArrayFree(m_newsTitle);
      ArrayFree(m_newsImpact);
      m_newsCount = 0;  // Reset counter
      
      // Mô phỏng: Thêm một số tin tức mẫu cho 2 ngày
      datetime currentTime = TimeCurrent();
      datetime today = currentTime - (currentTime % 86400); // Lấy đầu ngày (00:00:00)
      datetime tomorrow = today + 86400; // Thêm 1 ngày
      
      // Thêm các tin tức mẫu
      AddNews(today + 10*3600, "Non-Farm Payroll (US)", NEWS_IMPACT_HIGH);
      AddNews(today + 14*3600, "FOMC Statement (US)", NEWS_IMPACT_HIGH);
      AddNews(today + 16*3600, "Unemployment Rate (EU)", NEWS_IMPACT_MEDIUM);
      AddNews(tomorrow + 8*3600, "GDP (GB)", NEWS_IMPACT_HIGH);
      AddNews(tomorrow + 12*3600, "Retail Sales (JP)", NEWS_IMPACT_MEDIUM);
      
      m_lastUpdate = TimeCurrent();
      return true;
      */
   }
   
   // Thêm tin tức vào mảng
   void AddNews(datetime time, string title, ENUM_NEWS_IMPACT impact)
   {
      // Tăng kích thước mảng
      int newSize = m_newsCount + 1;
      ArrayResize(m_newsTime, newSize);
      ArrayResize(m_newsTitle, newSize);
      ArrayResize(m_newsImpact, newSize);
      
      // Thêm dữ liệu mới
      m_newsTime[m_newsCount] = time;
      m_newsTitle[m_newsCount] = title;
      m_newsImpact[m_newsCount] = impact;
      
      // Tăng counter
      m_newsCount++;
   }
   
   // Kiểm tra xem hiện tại có tin tức quan trọng không (phương thức cũ giữ nguyên để tương thích)
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
            // Chuyển đổi tường minh số phút thành giây (chỉ dùng để so sánh thời gian)
            int beforeSeconds = m_minutesBefore * 60; // Chỉ để so sánh thời gian, không phải cho string operations
            int afterSeconds = m_minutesAfter * 60;   // Chỉ để so sánh thời gian, không phải cho string operations
            
            if(currentTime >= m_newsTime[i] - beforeSeconds && 
               currentTime <= m_newsTime[i] + afterSeconds)
            {
               return true;
            }
         }
      }
      
      return false;
   }
   
   // Kiểm tra xem có tin tức quan trọng cho cặp tiền cụ thể không
   bool IsHighImpactNewsForSymbol(string symbol)
   {
       if(!m_enabled)
           return false;
           
       // Cập nhật dữ liệu tin tức nếu đã quá 12 giờ
       if(TimeCurrent() - m_lastUpdate > 12*3600)
           UpdateNewsData();
           
       datetime currentTime = TimeCurrent();
       
       // Lấy các đồng tiền từ cặp tiền
       string currencies[];
       GetCurrenciesFromPair(symbol, currencies);
       
       // Lấy mã quốc gia tương ứng
       string countries[];
       ArrayResize(countries, ArraySize(currencies));
       for(int i = 0; i < ArraySize(currencies); i++)
       {
           countries[i] = GetCountryFromCurrency(currencies[i]);
       }
       
       // Kiểm tra tin tức cho các đồng tiền này
       for(int i = 0; i < m_newsCount; i++)
       {
           // Chỉ quan tâm tin tức có mức độ ảnh hưởng cao
           if(m_newsImpact[i] == NEWS_IMPACT_HIGH)
           {
               // Kiểm tra xem thời gian hiện tại có nằm trong khoảng cần tránh
               // Chuyển đổi tường minh số phút thành giây
               int beforeSeconds = m_minutesBefore * 60; // Chỉ để so sánh thời gian, không phải cho string operations
               int afterSeconds = m_minutesAfter * 60;   // Chỉ để so sánh thời gian, không phải cho string operations
               
               // Sử dụng các biến số đã chuyển đổi
               if(currentTime >= m_newsTime[i] - beforeSeconds && 
                  currentTime <= m_newsTime[i] + afterSeconds)
               {
                   // Kiểm tra xem tin tức có liên quan đến cặp tiền này không
                   for(int j = 0; j < ArraySize(countries); j++)
                   {
                       if(countries[j] != "" && StringFind(m_newsTitle[i], countries[j]) >= 0)
                       {
                           return true;
                       }
                   }
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
         // Chỉ hiển thị tin trong 24 giờ tới, chuyển đổi 24 giờ thành giây
         int dayInSeconds = 24 * 3600; // Chỉ để so sánh thời gian, không phải cho string operations
         
         if(m_newsTime[i] > currentTime && m_newsTime[i] - currentTime < dayInSeconds)
         {
            string impactStr = "";
            
            // Chuyển đổi enum thành chuỗi
            switch(m_newsImpact[i])
            {
               case NEWS_IMPACT_LOW: 
                  impactStr = "Low"; 
                  break;
               case NEWS_IMPACT_MEDIUM: 
                  impactStr = "Medium"; 
                  break;
               case NEWS_IMPACT_HIGH: 
                  impactStr = "High"; 
                  break;
               default:
                  impactStr = "Unknown";
                  break;
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
   
   // Helper function để log thông tin với integer, tránh implicit conversion
   void LogInfoWithInt(string message, int value)
   {
      Print(message + ": " + IntegerToString(value));
   }
};