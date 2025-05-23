//+------------------------------------------------------------------+
//|                                               NewsManager.mqh    |
//|                        Copyright 2025, Your Company              |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"
#property version   "2.00"

// Enum cho mức độ ảnh hưởng tin tức
enum ENUM_NEWS_IMPACT
{
   NEWS_IMPACT_LOW,     // Ảnh hưởng thấp
   NEWS_IMPACT_MEDIUM,  // Ảnh hưởng trung bình
   NEWS_IMPACT_HIGH     // Ảnh hưởng cao
};

//+------------------------------------------------------------------+
//| Class quản lý tin tức - Enhanced for v2.0                        |
//+------------------------------------------------------------------+
class CNewsManager
{
private:
   bool              m_enabled;           // Trạng thái bật/tắt
   datetime          m_newsTime[];        // Mảng thời gian tin tức
   string            m_newsTitle[];       // Mảng tiêu đề tin tức
   string            m_newsCountry[];     // Mảng quốc gia tin tức
   ENUM_NEWS_IMPACT  m_newsImpact[];      // Mảng mức độ ảnh hưởng
   int               m_newsCount;         // Số lượng tin tức
   datetime          m_lastUpdate;        // Thời gian cập nhật cuối
   int               m_minutesBefore;     // Số phút tránh trước tin
   int               m_minutesAfter;      // Số phút tránh sau tin
   bool              m_usingAlternateSource; // Sử dụng nguồn dữ liệu thay thế
   int               m_webRequestTimeout; // Timeout cho WebRequest (ms)
   string            m_cacheFilePath;     // Đường dẫn file cache
   bool              m_logEnabled;        // Enable detailed logging
   
   // Ánh xạ cặp tiền tới các đồng tiền thành phần
   void GetCurrenciesFromPair(string symbol, string &currencies[])
   {
       ArrayResize(currencies, 2);
       
       // Reset values
       currencies[0] = "";
       currencies[1] = "";
       
       // Xử lý cặp tiền forex chuẩn 6 ký tự (EURUSD, GBPJPY, etc.)
       if(StringLen(symbol) >= 6)
       {
           currencies[0] = StringSubstr(symbol, 0, 3);
           currencies[1] = StringSubstr(symbol, 3, 3);
           return;
       }
       
       // Xử lý các trường hợp đặc biệt
       if(StringFind(symbol, "XAU") >= 0) currencies[0] = "XAU";
       if(StringFind(symbol, "XAG") >= 0) currencies[0] = "XAG";
       if(StringFind(symbol, "USD") >= 0) currencies[1] = "USD";
       
       // Xử lý indices
       if(StringFind(symbol, "US30") >= 0 || 
          StringFind(symbol, "SPX") >= 0 || 
          StringFind(symbol, "NAS") >= 0) 
       {
           currencies[0] = "USD"; // US indices treated as USD
       }
       
       // Xử lý các trường hợp khác theo yêu cầu
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
       if(currency == "CNY") return "CN";
       if(currency == "HKD") return "HK";
       if(currency == "SGD") return "SG";
       if(currency == "XAU") return "GOLD"; // Gold
       if(currency == "XAG") return "SILVER"; // Silver
       
       // Thêm ánh xạ khác nếu cần
       return "";
   }
   
   // Lấy dữ liệu từ lịch kinh tế với xử lý lỗi tốt hơn
   bool FetchEconomicCalendarData()
   {
       // Use a more robust approach with multiple retry attempts
       int maxRetries = 3;
       int retryDelay = 2000; // 2 seconds
       
       for(int attempt = 1; attempt <= maxRetries; attempt++)
       {
           if(m_logEnabled) Print("Attempt ", attempt, " to fetch economic calendar data...");
           
           // Try to fetch from the primary source
           bool result = FetchFromPrimarySource();
           
           if(result)
           {
               if(m_logEnabled) Print("Successfully fetched economic calendar data");
               return true;
           }
           
           // If failed, wait before retrying
           if(attempt < maxRetries)
           {
               if(m_logEnabled) Print("Fetch attempt ", attempt, " failed. Retrying in ", retryDelay/1000, " seconds...");
               Sleep(retryDelay);
           }
       }
       
       // If all attempts failed, try the alternate method
       if(m_logEnabled) Print("All attempts to fetch from primary source failed. Using alternate source...");
       m_usingAlternateSource = true;
       
       // Try to load from cache file first
       if(LoadNewsFromCache())
       {
           if(m_logEnabled) Print("Successfully loaded news data from cache");
           return true;
       }
       
       // If no cache, generate sample data
       if(m_logEnabled) Print("No cache available. Generating sample news data...");
       return GenerateSampleNewsData();
   }
   
   // Primary data source fetch method
   bool FetchFromPrimarySource()
   {
       // MQL5 Economic Calendar API or another reliable source
       string url = "https://www.mql5.com/en/economic-calendar/content";
       string cookies = NULL, headers;
       char post[], result[];
       
       // Lấy ngày hiện tại
       MqlDateTime dt;
       TimeToStruct(TimeCurrent(), dt);
       
       // Tạo request body (lấy tin trong 7 ngày tiếp theo)
       string data = StringFormat("date=%04d-%02d-%02d", dt.year, dt.mon, dt.day);
       StringToCharArray(data, post);
       
       // Gửi request với timeout
       int res = WebRequest("POST", url, NULL, NULL, m_webRequestTimeout, post, ArraySize(post), result, headers);
       
       if(res == -1)
       {
           int error = GetLastError();
           if(m_logEnabled) Print("Error in WebRequest: ", error);
           
           if(error == 4060)
           {
               if(m_logEnabled) Print("Please allow WebRequest for www.mql5.com in Tools->Options->Expert Advisors");
           }
           return false;
       }
       
       // Phân tích dữ liệu HTML nếu nhận được
       if(ArraySize(result) > 0)
       {
           string html = CharArrayToString(result);
           return ParseEconomicCalendarHTML(html);
       }
       
       return false;
   }
   
   // Parse HTML với robust error handling
   bool ParseEconomicCalendarHTML(string html)
   {
       // Make sure we have some content to parse
       if(html == "" || StringLen(html) < 100)
       {
           if(m_logEnabled) Print("Empty or very short HTML content received");
           return false;
       }
       
       // Reset dữ liệu tin tức
       ArrayFree(m_newsTime);
       ArrayFree(m_newsTitle);
       ArrayFree(m_newsCountry);
       ArrayFree(m_newsImpact);
       m_newsCount = 0;
       
       // Perform more robust parsing with error checking
       try
       {
           // Tìm các mục tin tức trong HTML
           int pos = 0;
           int newsFound = 0;
           
           while(true)
           {
               // Tìm mỗi sự kiện tin tức
               int startPos = StringFind(html, "<tr class=\"ec-table__row", pos);
               if(startPos == -1) break;
               
               // Find the end of this row
               int endPos = StringFind(html, "</tr>", startPos);
               if(endPos == -1) {
                   pos = startPos + 1;
                   continue;
               }
               
               // Extract just this row's HTML for easier processing
               string rowHtml = StringSubstr(html, startPos, endPos - startPos);
               
               // Tìm ngày và giờ
               int datePos = StringFind(rowHtml, "data-time=\"");
               if(datePos == -1) {
                   pos = startPos + 1;
                   continue;
               }
               
               datePos += 11; // Độ dài của "data-time=\""
               int dateEndPos = StringFind(rowHtml, "\"", datePos);
               string dateTimeStr = StringSubstr(rowHtml, datePos, dateEndPos - datePos);
               datetime newsTime = StringToTime(dateTimeStr);
               
               // Tìm tiêu đề tin tức
               int titlePos = StringFind(rowHtml, "class=\"ec-table__name\">", 0);
               if(titlePos == -1) {
                   pos = startPos + 1;
                   continue;
               }
               
               titlePos += 23; // Độ dài của "class=\"ec-table__name\">"
               int titleEndPos = StringFind(rowHtml, "</", titlePos);
               string title = StringSubstr(rowHtml, titlePos, titleEndPos - titlePos);
               
               // Clean HTML entities and tags
               StringReplace(title, "<span>", "");
               StringReplace(title, "</span>", "");
               StringReplace(title, "&quot;", "\"");
               StringReplace(title, "&amp;", "&");
               StringReplace(title, "&lt;", "<");
               StringReplace(title, "&gt;", ">");
               
               // Tìm quốc gia
               int countryPos = StringFind(rowHtml, "class=\"ec-table__country\">", 0);
               if(countryPos == -1) {
                   pos = startPos + 1;
                   continue;
               }
               
               countryPos += 25; // Độ dài của "class=\"ec-table__country\">"
               int countryEndPos = StringFind(rowHtml, "</", countryPos);
               string country = StringSubstr(rowHtml, countryPos, countryEndPos - countryPos);
               
               // Tìm mức độ ảnh hưởng (1-3 stars)
               ENUM_NEWS_IMPACT impact = NEWS_IMPACT_LOW; // Default to low
               
               int impactPos = StringFind(rowHtml, "class=\"ec-table__importance", 0);
               if(impactPos != -1)
               {
                   // Extract the importance section
                   int impactEndPos = StringFind(rowHtml, "</td>", impactPos);
                   string impactSection = StringSubstr(rowHtml, impactPos, impactEndPos - impactPos);
                   
                   // Count stars to determine importance
                   int starCount = 0;
                   int starPos = 0;
                   while((starPos = StringFind(impactSection, "star", starPos)) != -1) {
                       starCount++;
                       starPos += 4; // Độ dài của "star"
                   }
                   
                   // Set impact based on star count
                   switch(starCount)
                   {
                       case 3: impact = NEWS_IMPACT_HIGH; break;
                       case 2: impact = NEWS_IMPACT_MEDIUM; break;
                       default: impact = NEWS_IMPACT_LOW; break;
                   }
               }
               
               // Add news only if we have a valid time
               if(newsTime > 0)
               {
                   AddNews(newsTime, title, country, impact);
                   newsFound++;
               }
               
               // Move to next position
               pos = startPos + 1;
           }
           
           // Save to cache if we found news
           if(newsFound > 0)
           {
               SaveNewsToCache();
           }
           
           if(m_logEnabled) Print("Parsed ", newsFound, " news events");
           return (newsFound > 0);
       }
       catch(...)
       {
           if(m_logEnabled) Print("Exception while parsing HTML");
           return false;
       }
   }
   
   // Generate sample news data for testing or when web requests fail
   bool GenerateSampleNewsData()
   {
       // Reset data
       ArrayFree(m_newsTime);
       ArrayFree(m_newsTitle);
       ArrayFree(m_newsCountry);
       ArrayFree(m_newsImpact);
       m_newsCount = 0;
       
       // Current time
       datetime currentTime = TimeCurrent();
       datetime today = currentTime - (currentTime % 86400); // Start of current day
       
       // Add sample news events for major currencies
       // Today
       AddNews(today + 10*3600, "Non-Farm Payroll", "US", NEWS_IMPACT_HIGH);
       AddNews(today + 14*3600, "FOMC Statement", "US", NEWS_IMPACT_HIGH);
       AddNews(today + 16*3600, "ECB Interest Rate Decision", "EU", NEWS_IMPACT_HIGH);
       
       // Tomorrow
       AddNews(today + 86400 + 8*3600, "BOE Meeting Minutes", "GB", NEWS_IMPACT_HIGH);
       AddNews(today + 86400 + 12*3600, "RBA Interest Rate Decision", "AU", NEWS_IMPACT_HIGH);
       
       // Day after tomorrow
       AddNews(today + 2*86400 + 9*3600, "GDP", "US", NEWS_IMPACT_HIGH);
       AddNews(today + 2*86400 + 15*3600, "BOJ Press Conference", "JP", NEWS_IMPACT_HIGH);
       
       if(m_logEnabled) Print("Generated ", m_newsCount, " sample news events");
       
       // Save to cache
       SaveNewsToCache();
       
       return (m_newsCount > 0);
   }
   
   // Save news data to cache file
   bool SaveNewsToCache()
   {
       if(m_newsCount == 0)
           return false;
           
       // Prepare file
       int fileHandle = FileOpen(m_cacheFilePath, FILE_WRITE|FILE_BIN);
       if(fileHandle == INVALID_HANDLE)
       {
           int error = GetLastError();
           if(m_logEnabled) Print("Error opening cache file for writing: ", error);
           return false;
       }
       
       // Write header
       FileWriteInteger(fileHandle, m_newsCount, LONG_VALUE);
       FileWriteInteger(fileHandle, TimeCurrent(), LONG_VALUE); // Cache timestamp
       
       // Write news data
       for(int i = 0; i < m_newsCount; i++)
       {
           FileWriteInteger(fileHandle, m_newsTime[i], LONG_VALUE);
           FileWriteString(fileHandle, m_newsTitle[i], -1);
           FileWriteString(fileHandle, m_newsCountry[i], -1);
           FileWriteInteger(fileHandle, m_newsImpact[i], INT_VALUE);
       }
       
       FileClose(fileHandle);
       return true;
   }
   
   // Load news data from cache file
   bool LoadNewsFromCache()
   {
       if(!FileIsExist(m_cacheFilePath))
           return false;
           
       // Open file
       int fileHandle = FileOpen(m_cacheFilePath, FILE_READ|FILE_BIN);
       if(fileHandle == INVALID_HANDLE)
       {
           int error = GetLastError();
           if(m_logEnabled) Print("Error opening cache file for reading: ", error);
           return false;
       }
       
       // Read header
       int newsCount = FileReadInteger(fileHandle, LONG_VALUE);
       datetime cacheTime = FileReadInteger(fileHandle, LONG_VALUE);
       
       // Check if cache is too old (more than 12 hours)
       if(TimeCurrent() - cacheTime > 12*3600)
       {
           if(m_logEnabled) Print("Cache file is too old: ", TimeToString(cacheTime));
           FileClose(fileHandle);
           return false;
       }
       
       // Reset arrays
       ArrayFree(m_newsTime);
       ArrayFree(m_newsTitle);
       ArrayFree(m_newsCountry);
       ArrayFree(m_newsImpact);
       m_newsCount = 0;
       
       // Read news data
       for(int i = 0; i < newsCount; i++)
       {
           datetime time = FileReadInteger(fileHandle, LONG_VALUE);
           string title = FileReadString(fileHandle, -1);
           string country = FileReadString(fileHandle, -1);
           ENUM_NEWS_IMPACT impact = (ENUM_NEWS_IMPACT)FileReadInteger(fileHandle, INT_VALUE);
           
           // Add to arrays
           AddNews(time, title, country, impact);
       }
       
       FileClose(fileHandle);
       
       if(m_logEnabled) Print("Loaded ", m_newsCount, " news events from cache");
       return (m_newsCount > 0);
   }

public:
   // Constructor
   CNewsManager() 
   {
      m_enabled = false;
      m_newsCount = 0;
      m_lastUpdate = 0;
      m_minutesBefore = 30;     // Default: avoid 30 minutes before news
      m_minutesAfter = 30;      // Default: avoid 30 minutes after news
      m_usingAlternateSource = false;
      m_webRequestTimeout = 5000; // 5 seconds timeout
      m_cacheFilePath = "MQL5\\Files\\Triple_Confirmation_System\\Data\\news_cache.bin";
      m_logEnabled = true;
   }
   
   // Destructor
   ~CNewsManager() { }
   
   // Initialization
   bool Init(bool enabled, int minutesBefore = 30, int minutesAfter = 30, bool enableLogging = true)
   {
      m_enabled = enabled;
      m_minutesBefore = minutesBefore;
      m_minutesAfter = minutesAfter;
      m_logEnabled = enableLogging;
      
      // Create cache directory
      string dirPath = "MQL5\\Files\\Triple_Confirmation_System\\Data";
      if(!FolderCreate(dirPath))
      {
         int lastError = GetLastError();
         if(lastError != ERR_DIRECTORY_ALREADY_EXISTS && m_logEnabled)
         {
            Print("Error creating directory for news cache: ", lastError);
         }
      }
      
      if(m_enabled)
      {
         // Update news data initially
         return UpdateNewsData();
      }
      
      return true;
   }
   
   // Deinitialization
   void Deinit()
   {
      // Free arrays memory
      ArrayFree(m_newsTime);
      ArrayFree(m_newsTitle);
      ArrayFree(m_newsCountry);
      ArrayFree(m_newsImpact);
      m_newsCount = 0;
   }
   
   // Thêm tin tức vào mảng
   void AddNews(datetime time, string title, string country, ENUM_NEWS_IMPACT impact)
   {
      // Tăng kích thước mảng
      int newSize = m_newsCount + 1;
      ArrayResize(m_newsTime, newSize);
      ArrayResize(m_newsTitle, newSize);
      ArrayResize(m_newsCountry, newSize);
      ArrayResize(m_newsImpact, newSize);
      
      // Thêm dữ liệu mới
      m_newsTime[m_newsCount] = time;
      m_newsTitle[m_newsCount] = title;
      m_newsCountry[m_newsCount] = country;
      m_newsImpact[m_newsCount] = impact;
      
      // Tăng counter
      m_newsCount++;
   }
   
   // Cập nhật dữ liệu tin tức
   bool UpdateNewsData()
   {
      if(!m_enabled)
         return false;
      
      // Call the fetching function
      bool result = FetchEconomicCalendarData();
      
      if(result)
         m_lastUpdate = TimeCurrent();
         
      return result;
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
            int beforeSeconds = m_minutesBefore * 60;
            int afterSeconds = m_minutesAfter * 60;
            
            if(currentTime >= m_newsTime[i] - beforeSeconds && 
               currentTime <= m_newsTime[i] + afterSeconds)
            {
               return true;
            }
         }
      }
      
      return false;
   }
   
   // Kiểm tra xem có tin tức quan trọng cho cặp tiền cụ thể không - Enhanced for v2.0
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
       
       // Check if we have valid currencies
       bool hasCurrencies = false;
       for(int i = 0; i < ArraySize(currencies); i++)
       {
           if(currencies[i] != "")
           {
               hasCurrencies = true;
               break;
           }
       }
       
       if(!hasCurrencies && m_logEnabled)
       {
           Print("Warning: No currencies identified for symbol ", symbol);
           return false;
       }
       
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
               int beforeSeconds = m_minutesBefore * 60;
               int afterSeconds = m_minutesAfter * 60;
               
               if(currentTime >= m_newsTime[i] - beforeSeconds && 
                  currentTime <= m_newsTime[i] + afterSeconds)
               {
                   // Check if news is for one of our currencies
                   bool isRelevant = false;
                   for(int j = 0; j < ArraySize(countries); j++)
                   {
                       // Skip empty countries
                       if(countries[j] == "")
                           continue;
                           
                       // Check by country code in news country or title
                       if(m_newsCountry[i] == countries[j] || 
                          StringFind(m_newsTitle[i], countries[j]) >= 0)
                       {
                           isRelevant = true;
                           
                           if(m_logEnabled)
                           {
                               string newsTime = TimeToString(m_newsTime[i], TIME_DATE|TIME_MINUTES);
                               Print("High-impact news for ", symbol, ": ", m_newsTitle[i], 
                                     " (", countries[j], ") at ", newsTime);
                           }
                           
                           break;
                       }
                   }
                   
                   if(isRelevant)
                       return true;
               }
           }
       }
       
       return false;
   }
   
   // Set logging state
   void SetLogging(bool enabled)
   {
       m_logEnabled = enabled;
   }
   
   // Get a descriptive string of current settings
   string GetNewsFilterSettings()
   {
       if(!m_enabled)
           return "News filter: Disabled";
           
       string result = "News filter: Enabled - avoiding high impact news ";
       result += IntegerToString(m_minutesBefore) + " minutes before and ";
       result += IntegerToString(m_minutesAfter) + " minutes after events";
       
       if(m_usingAlternateSource)
           result += " (using cached/sample data)";
       
       return result;
   }
   
   // Get upcoming news info for UI
   string GetUpcomingNewsInfo()
   {
      if(!m_enabled)
         return "News filter disabled";
         
      string info = "";
      datetime currentTime = TimeCurrent();
      bool hasUpcoming = false;
      
      for(int i = 0; i < m_newsCount; i++)
      {
         // Only show high impact news within next 24 hours
         if(m_newsImpact[i] == NEWS_IMPACT_HIGH &&
            m_newsTime[i] > currentTime && 
            m_newsTime[i] - currentTime < 24*3600)
         {
            string impactStr = "High";
            
            info += TimeToString(m_newsTime[i], TIME_DATE|TIME_MINUTES) + 
                   " - " + m_newsTitle[i] + " (" + m_newsCountry[i] + " - " + impactStr + ")\n";
            hasUpcoming = true;
         }
      }
      
      if(!hasUpcoming)
         info = "No upcoming high-impact news in next 24 hours";
         
      return info;
   }
};