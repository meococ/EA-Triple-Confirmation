//+------------------------------------------------------------------+
//|                                              TradeJournal.mqh |
//|                        Copyright 2025, Your Company               |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"

// Định nghĩa mã lỗi
#ifndef ERR_DIRECTORY_ALREADY_EXISTS 
#define ERR_DIRECTORY_ALREADY_EXISTS 4906  // Mã lỗi cho "Directory already exists"
#endif

// Sử dụng enum và struct từ CommonDefinitions.mqh
#include "CommonDefinitions.mqh"

// Lưu ý: Đã loại bỏ các enum và struct trùng lặp - Sử dụng từ CommonDefinitions.mqh thay thế

class CTradeJournal
{
private:
   string               m_logDirectory;
   string               m_eaName;
   bool                 m_detailedLogging;
   int                  m_logFile;
   int                  m_setupLogFile;
   int                  m_resultLogFile;
   string               m_logFilename;
   string               m_setupLogFilename;
   string               m_resultLogFilename;
   
   // Tạo thư mục nếu chưa tồn tại
   bool CreateDirectoryIfNotExists(string path)
   {
      // Kiểm tra trước khi tạo thư mục
      if(!FileIsExist(path))
      {
         if(!FolderCreate(path))
         {
            int error = GetLastError();
            if(error != ERR_DIRECTORY_ALREADY_EXISTS) // Bỏ qua nếu thư mục đã tồn tại
            {
               Print("Không thể tạo thư mục: ", path, " Lỗi: ", IntegerToString(error));
               return false;
            }
         }
      }
      return true;
   }
   
   // Tạo tên file với timestamp
   string CreateTimestampFilename(string prefix)
   {
      datetime now = TimeCurrent();
      
      // Lấy phần ngày và giờ riêng biệt
      MqlDateTime dt;
      TimeToStruct(now, dt);
      
      // Tạo chuỗi theo định dạng yyyy-mm-dd_hh-mm, tránh dùng StringReplace
      string year = IntegerToString(dt.year);
      string month = IntegerToString(dt.mon, 2, '0');   // Đảm bảo 2 chữ số với padding 0
      string day = IntegerToString(dt.day, 2, '0');     // Đảm bảo 2 chữ số với padding 0
      string hour = IntegerToString(dt.hour, 2, '0');   // Đảm bảo 2 chữ số với padding 0
      string minute = IntegerToString(dt.min, 2, '0');  // Đảm bảo 2 chữ số với padding 0
      
      // Tạo chuỗi timestamp trực tiếp với các dấu phân cách mong muốn
      string timestamp = year + "-" + month + "-" + day + "_" + hour + "-" + minute;
      
      // Kết hợp với prefix và phần mở rộng
      return prefix + "_" + timestamp + ".csv";
   }

public:
   // Constructor
   CTradeJournal()
   {
      m_logDirectory = "MQL5\\Files\\Logs";
      m_eaName = "EA";
      m_detailedLogging = true;
      m_logFile = INVALID_HANDLE;
      m_setupLogFile = INVALID_HANDLE;
      m_resultLogFile = INVALID_HANDLE;
   }
   
   // Destructor
   ~CTradeJournal()
   {
      if(m_logFile != INVALID_HANDLE)
         FileClose(m_logFile);
         
      if(m_setupLogFile != INVALID_HANDLE)
         FileClose(m_setupLogFile);
         
      if(m_resultLogFile != INVALID_HANDLE)
         FileClose(m_resultLogFile);
   }
   
   // Khởi tạo
   bool Init(string logDirectory, string eaName, bool detailedLogging)
   {
      m_logDirectory = logDirectory;
      m_eaName = eaName;
      m_detailedLogging = detailedLogging;
      
      // Tạo thư mục logs nếu chưa tồn tại
      string fullPath = "MQL5\\Files\\" + m_logDirectory;
      if(!CreateDirectoryIfNotExists(fullPath))
         return false;
         
      // Tạo file log chung
      m_logFilename = m_logDirectory + "\\" + m_eaName + "_Log.txt";
      m_logFile = FileOpen(m_logFilename, FILE_WRITE|FILE_READ|FILE_TXT);
      
      if(m_logFile == INVALID_HANDLE)
      {
         Print("Failed to create log file: ", m_logFilename, " Error: ", IntegerToString(GetLastError()));
         return false;
      }
      
      // Tạo file log setup
      m_setupLogFilename = m_logDirectory + "\\" + m_eaName + "_Setups.csv";
      m_setupLogFile = FileOpen(m_setupLogFilename, FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI);
      
      if(m_setupLogFile == INVALID_HANDLE)
      {
         Print("Failed to create setup log file: ", m_setupLogFilename, " Error: ", IntegerToString(GetLastError()));
         FileClose(m_logFile);
         return false;
      }
      
      // Viết header cho file setup log
      FileWrite(m_setupLogFile,
               "Date", "Time", "Symbol", "Direction", "Entry Price", "Stop Loss", 
               "TP1", "TP2", "TP3", "Risk/Reward", "Setup Quality", "Market Condition",
               "Lot Size", "Risk %", "RSI", "VWAP Distance", "BB Distance", "OBV", "ATR");
      
      // Tạo file log kết quả
      m_resultLogFilename = m_logDirectory + "\\" + m_eaName + "_Results.csv";
      m_resultLogFile = FileOpen(m_resultLogFilename, FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI);
      
      if(m_resultLogFile == INVALID_HANDLE)
      {
         Print("Failed to create result log file: ", m_resultLogFilename, " Error: ", IntegerToString(GetLastError()));
         FileClose(m_logFile);
         FileClose(m_setupLogFile);
         return false;
      }
      
      // Viết header cho file result log
      FileWrite(m_resultLogFile,
               "Date", "Time", "Ticket", "Symbol", "Profit", "Pips", "Duration (min)", "Exit Reason");
      
      // Log thông tin khởi động
      LogInfo("Trade Journal initialized for " + m_eaName);
      
      return true;
   }
   
   // Dọn dẹp
   void Deinit()
   {
      if(m_logFile != INVALID_HANDLE)
      {
         FileClose(m_logFile);
         m_logFile = INVALID_HANDLE;
      }
      
      if(m_setupLogFile != INVALID_HANDLE)
      {
         FileClose(m_setupLogFile);
         m_setupLogFile = INVALID_HANDLE;
      }
      
      if(m_resultLogFile != INVALID_HANDLE)
      {
         FileClose(m_resultLogFile);
         m_resultLogFile = INVALID_HANDLE;
      }
   }
   
   // Log thông tin EA khởi động
   void LogEAStart()
   {
      // Mở file để viết thêm
      if(m_logFile == INVALID_HANDLE)
         return;
         
      // Di chuyển con trỏ đến cuối file
      FileSeek(m_logFile, 0, SEEK_END);
      
      // Log thông tin
      FileWrite(m_logFile, "======================================================");
      FileWrite(m_logFile, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + ": " + m_eaName + " STARTED");
      FileWrite(m_logFile, "Account: " + AccountInfoString(ACCOUNT_COMPANY) + ", Balance: " + 
               DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
      FileWrite(m_logFile, "======================================================");
      
      // Flush để đảm bảo ghi vào file
      FileFlush(m_logFile);
   }
   
   // Log thông tin EA dừng
   void LogEAStop(int reason)
   {
      // Mở file để viết thêm
      if(m_logFile == INVALID_HANDLE)
         return;
         
      // Di chuyển con trỏ đến cuối file
      FileSeek(m_logFile, 0, SEEK_END);
      
      // Lấy mô tả lý do dừng
      string reasonDesc = "";
      switch(reason)
      {
         case REASON_PROGRAM: reasonDesc = "Program terminated"; break;
         case REASON_REMOVE: reasonDesc = "EA removed from chart"; break;
         case REASON_RECOMPILE: reasonDesc = "EA recompiled"; break;
         case REASON_CHARTCHANGE: reasonDesc = "Chart symbol or period changed"; break;
         case REASON_CHARTCLOSE: reasonDesc = "Chart closed"; break;
         case REASON_PARAMETERS: reasonDesc = "Parameters changed"; break;
         case REASON_ACCOUNT: reasonDesc = "Account changed"; break;
         case REASON_TEMPLATE: reasonDesc = "Template applied"; break;
         case REASON_INITFAILED: reasonDesc = "OnInit() failed"; break;
         case REASON_CLOSE: reasonDesc = "Terminal closed"; break;
         default: reasonDesc = "Unknown reason: " + IntegerToString(reason); break;
      }
      
      // Log thông tin
      FileWrite(m_logFile, "======================================================");
      FileWrite(m_logFile, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + ": " + m_eaName + " STOPPED - " + reasonDesc);
      FileWrite(m_logFile, "Account: " + AccountInfoString(ACCOUNT_COMPANY) + ", Balance: " + 
               DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
      FileWrite(m_logFile, "======================================================");
      
      // Flush để đảm bảo ghi vào file
      FileFlush(m_logFile);
   }
   
   // Log thông tin chung
   void LogInfo(string message)
   {
      // Mở file để viết thêm
      if(m_logFile == INVALID_HANDLE)
         return;
         
      // Di chuyển con trỏ đến cuối file
      FileSeek(m_logFile, 0, SEEK_END);
      
      // Log thông tin
      FileWrite(m_logFile, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + ": INFO - " + message);
      
      // Flush để đảm bảo ghi vào file
      FileFlush(m_logFile);
   }
   
   // Log cảnh báo
   void LogWarning(string message)
   {
      // Mở file để viết thêm
      if(m_logFile == INVALID_HANDLE)
         return;
         
      // Di chuyển con trỏ đến cuối file
      FileSeek(m_logFile, 0, SEEK_END);
      
      // Log cảnh báo
      FileWrite(m_logFile, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + ": WARNING - " + message);
      
      // Flush để đảm bảo ghi vào file
      FileFlush(m_logFile);
      
      // In ra console
      Print(m_eaName + " WARNING: " + message);
   }
   
   // Log lỗi
   void LogError(string message)
   {
      // Mở file để viết thêm
      if(m_logFile == INVALID_HANDLE)
         return;
         
      // Di chuyển con trỏ đến cuối file
      FileSeek(m_logFile, 0, SEEK_END);
      
      // Log lỗi
      FileWrite(m_logFile, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + ": ERROR - " + message);
      
      // Flush để đảm bảo ghi vào file
      FileFlush(m_logFile);
      
      // In ra console
      Print(m_eaName + " ERROR: " + message);
   }
   
   // Log chi tiết setup giao dịch
   void LogTradeSetup(STradeDetails& details)
   {
      if(!m_detailedLogging || m_setupLogFile == INVALID_HANDLE)
         return;
         
      // Di chuyển con trỏ đến cuối file
      FileSeek(m_setupLogFile, 0, SEEK_END);
      
      // Convert enum to string sử dụng EnumToString hoặc xử lý trực tiếp
      string directionStr = "";
      switch(details.direction)
      {
         case TRADE_DIRECTION_BUY:
            directionStr = "BUY";
            break;
         case TRADE_DIRECTION_SELL:
            directionStr = "SELL";
            break;
         default:
            directionStr = "UNKNOWN";
            break;
      }
      
      string setupQualityStr = "";
      switch(details.setupQuality)
      {
         case SETUP_QUALITY_A_PLUS:
            setupQualityStr = "A+";
            break;
         case SETUP_QUALITY_A:
            setupQualityStr = "A";
            break;
         case SETUP_QUALITY_B:
            setupQualityStr = "B";
            break;
         case SETUP_QUALITY_NONE:
         default:
            setupQualityStr = "NONE";
            break;
      }
      
      string marketConditionStr = "";
      switch(details.marketCondition)
      {
         case MARKET_CONDITION_TRENDING:
            marketConditionStr = "TRENDING";
            break;
         case MARKET_CONDITION_RANGING:
            marketConditionStr = "RANGING";
            break;
         case MARKET_CONDITION_VOLATILE:
            marketConditionStr = "VOLATILE";
            break;
         case MARKET_CONDITION_TRANSITION:
            marketConditionStr = "TRANSITION";
            break;
         case MARKET_CONDITION_UNDEFINED:
         default:
            marketConditionStr = "UNDEFINED";
            break;
      }
      
      // Log vào file CSV
      FileWrite(m_setupLogFile,
               TimeToString(TimeCurrent(), TIME_DATE),
               TimeToString(TimeCurrent(), TIME_SECONDS),
               details.symbol,
               directionStr,
               DoubleToString(details.entryPrice, Digits()),
               DoubleToString(details.stopLoss, Digits()),
               DoubleToString(details.takeProfit1, Digits()),
               DoubleToString(details.takeProfit2, Digits()),
               DoubleToString(details.takeProfit3, Digits()),
               DoubleToString(details.riskReward, 2),
               setupQualityStr,
               marketConditionStr,
               DoubleToString(details.lotSize, 2),
               DoubleToString(details.risk, 2),
               DoubleToString(details.RSI, 2),
               DoubleToString(details.VWAP_Distance, 2),
               DoubleToString(details.BB_Distance, 2),
               DoubleToString(details.OBV, 2),
               DoubleToString(details.ATR, 5));
      
      // Flush để đảm bảo ghi vào file
      FileFlush(m_setupLogFile);
      
      // Log thông tin cơ bản vào file log chính
      LogInfo("Trade setup: " + details.symbol + " " + directionStr + 
             " @ " + DoubleToString(details.entryPrice, Digits()) + 
             ", SL: " + DoubleToString(details.stopLoss, Digits()) + 
             ", TP1: " + DoubleToString(details.takeProfit1, Digits()) + 
             ", R:R = " + DoubleToString(details.riskReward, 2) + 
             ", Quality: " + setupQualityStr);
   }
   
   // Log khi vào lệnh
   void LogTradeEntry(STradeDetails& details)
   {
      // Sử dụng condition thay vì chuyển đổi trực tiếp
      string directionStr = (details.direction == TRADE_DIRECTION_BUY) ? "BUY" : "SELL";
      
      LogInfo("Trade entered: " + details.symbol + " " + directionStr + 
             " @ " + DoubleToString(details.entryPrice, Digits()) + 
             ", Lot size: " + DoubleToString(details.lotSize, 2));
   }
   
   // Log kết quả giao dịch
   void LogTradeResult(STradeResult& result)
   {
      // Log vào file kết quả
      if(m_resultLogFile != INVALID_HANDLE)
      {
         // Di chuyển con trỏ đến cuối file
         FileSeek(m_resultLogFile, 0, SEEK_END);
         
         // Chuyển đổi ticket từ ulong sang string an toàn
         string ticketStr = IntegerToString(result.ticket);
         
         // Log vào file CSV
         FileWrite(m_resultLogFile,
                  TimeToString(result.openTime, TIME_DATE),
                  TimeToString(result.closeTime, TIME_SECONDS),
                  ticketStr,
                  result.symbol,
                  DoubleToString(result.profit, 2),
                  DoubleToString(result.pips, 1),
                  IntegerToString(result.duration),
                  result.exitReason);
         
         // Flush để đảm bảo ghi vào file
         FileFlush(m_resultLogFile);
      }
      
      // Log thông tin vào file log chính
      string orderTypeStr = (result.type == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      string resultStr = result.profit >= 0.0 ? "PROFIT" : "LOSS";
      string qualityStr = "";
      
      switch (result.setupQuality)
      {
         case SETUP_QUALITY_A_PLUS:
            qualityStr = "A+";
            break;
         case SETUP_QUALITY_A:
            qualityStr = "A";
            break;
         case SETUP_QUALITY_B:
            qualityStr = "B";
            break;
         default:
            qualityStr = "NONE";
            break;
      }
      
      LogInfo("Trade result: #" + IntegerToString(result.ticket) + " " + 
             orderTypeStr + " " + resultStr + " " + DoubleToString(result.profit, 2) + 
             " (" + DoubleToString(result.pips, 1) + " pips)" + 
             ", Duration: " + IntegerToString(result.duration) + " min" + 
             ", Quality: " + qualityStr +
             ", Reason: " + result.exitReason);
   }
   
   // Tạo báo cáo nhật ký giao dịch đầy đủ
   bool CreateDetailedJournal(ulong ticket)
   {
      // Chỉ thực hiện nếu có log chi tiết
      if(!m_detailedLogging)
         return false;
         
      // Kiểm tra vị thế tồn tại
      if(!PositionSelectByTicket(ticket))
      {
         LogError("Position not found for ticket: " + IntegerToString(ticket));
         return false;
      }
      
      // Tạo tên file với format: Symbol_Ticket_Date.md
      string journalFilename = m_logDirectory + "\\" + 
                              PositionGetString(POSITION_SYMBOL) + "_" + 
                              IntegerToString(ticket) + "_" + 
                              TimeToString(TimeCurrent(), TIME_DATE) + ".md";
      
      // Tạo file journal
      int journalFile = FileOpen(journalFilename, FILE_WRITE|FILE_TXT);
      if(journalFile == INVALID_HANDLE)
      {
         LogError("Failed to create detailed journal file: " + journalFilename + ", Error: " + IntegerToString(GetLastError()));
         return false;
      }
      
      // Lấy dữ liệu từ vị thế để viết nhật ký
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double stopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);
      double volume = PositionGetDouble(POSITION_VOLUME);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      string symbol = PositionGetString(POSITION_SYMBOL);
      
      // Chuyển đổi kiểu vị thế sang chuỗi rõ ràng
      string posTypeStr = "";
      switch(posType)
      {
         case POSITION_TYPE_BUY:
            posTypeStr = "MUA";
            break;
         case POSITION_TYPE_SELL:
            posTypeStr = "BÁN";
            break;
         default:
            posTypeStr = "KHÔNG XÁC ĐỊNH";
            break;
      }
      
      // Viết header cho file Markdown
      FileWrite(journalFile, "# NHẬT KÝ GIAO DỊCH TOÀN DIỆN CHO PROP FIRM");
      FileWrite(journalFile, "");
      FileWrite(journalFile, "## THÔNG TIN GIAO DỊCH");
      FileWrite(journalFile, "");
      FileWrite(journalFile, "**Ngày/Giờ:** " + TimeToString(openTime, TIME_DATE|TIME_SECONDS));
      FileWrite(journalFile, "**Cặp tiền/Tài sản:** " + symbol);
      FileWrite(journalFile, "**Khung thời gian kiểm tra:** H4/H1/M15");
      FileWrite(journalFile, "**Loại lệnh:** " + posTypeStr);
      FileWrite(journalFile, "**Giá vào lệnh:** " + DoubleToString(entryPrice, Digits()));
      FileWrite(journalFile, "**Khối lượng:** " + DoubleToString(volume, 2));
      FileWrite(journalFile, "**Stop Loss:** " + DoubleToString(stopLoss, Digits()));
      FileWrite(journalFile, "**Take Profit:** " + DoubleToString(takeProfit, Digits()));
      
      // Thêm các thông tin khác từ dữ liệu đã lưu
      // ...
      
      // Đóng file
      FileClose(journalFile);
      
      LogInfo("Created detailed journal file: " + journalFilename);
      return true;
   }
};