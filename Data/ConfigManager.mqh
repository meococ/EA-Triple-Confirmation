//+------------------------------------------------------------------+
//|                                            ConfigManager.mqh |
//|                        Copyright 2025, Your Company               |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"

#include <Files\FileTxt.mqh>
#include <Files\Json.mqh>

class CConfigManager
{
private:
   string            m_configFilePath;
   string            m_eaName;
   CFileTxt          m_file;
   CJAVal            m_config;
   
   // Giá trị mặc định nếu không tải được cấu hình
   struct DefaultConfig
   {
      // Cài đặt chung
      bool     enable_trading;
      bool     enable_news_filter;
      double   risk_percent;
      int      magic_number;
      
      // Cài đặt chiến lược
      int      vwap_period;
      int      rsi_period;
      int      rsi_oversold;
      int      rsi_overbought;
      int      bb_period;
      double   bb_deviation;
      int      atr_period;
      
      // Cài đặt TP/SL
      double   sl_atr_multiplier;
      double   tp1_atr_multiplier;
      double   tp2_atr_multiplier;
      double   tp3_atr_multiplier;
      int      tp1_percent;
      int      tp2_percent;
      int      tp3_percent;
      
      // Cài đặt quản lý rủi ro
      bool     use_atr_adaptive_sizing;
      int      atr_base_period;
      bool     enable_scaling_after_loss;
      double   scaling_factor;
      
      // Bộ lọc thị trường
      bool     use_adx_filter;
      int      adx_period;
      int      adx_trending_threshold;
      int      adx_ranging_threshold;
      
      // Cài đặt ghi log
      bool     enable_detailed_logging;
      string   log_directory;
   };
   
   DefaultConfig     m_defaultConfig;
   
   // Khởi tạo cấu hình mặc định
   void InitDefaultConfig()
   {
      m_defaultConfig.enable_trading = true;
      m_defaultConfig.enable_news_filter = true;
      m_defaultConfig.risk_percent = 1.0;
      m_defaultConfig.magic_number = 123456;
      
      m_defaultConfig.vwap_period = 20;
      m_defaultConfig.rsi_period = 9;
      m_defaultConfig.rsi_oversold = 35;
      m_defaultConfig.rsi_overbought = 65;
      m_defaultConfig.bb_period = 20;
      m_defaultConfig.bb_deviation = 2.0;
      m_defaultConfig.atr_period = 14;
      
      m_defaultConfig.sl_atr_multiplier = 1.2;
      m_defaultConfig.tp1_atr_multiplier = 1.5;
      m_defaultConfig.tp2_atr_multiplier = 2.5;
      m_defaultConfig.tp3_atr_multiplier = 4.0;
      m_defaultConfig.tp1_percent = 40;
      m_defaultConfig.tp2_percent = 35;
      m_defaultConfig.tp3_percent = 25;
      
      m_defaultConfig.use_atr_adaptive_sizing = true;
      m_defaultConfig.atr_base_period = 50;
      m_defaultConfig.enable_scaling_after_loss = true;
      m_defaultConfig.scaling_factor = 0.75;
      
      m_defaultConfig.use_adx_filter = true;
      m_defaultConfig.adx_period = 14;
      m_defaultConfig.adx_trending_threshold = 25;
      m_defaultConfig.adx_ranging_threshold = 20;
      
      m_defaultConfig.enable_detailed_logging = true;
      m_defaultConfig.log_directory = "TripleConfirmation_Logs";
   }
   
   // Tạo file cấu hình mặc định
   bool CreateDefaultConfigFile()
   {
      CJAVal config;
      
      // Thêm cài đặt chung
      config["general"]["enable_trading"] = m_defaultConfig.enable_trading;
      config["general"]["enable_news_filter"] = m_defaultConfig.enable_news_filter;
      config["general"]["risk_percent"] = m_defaultConfig.risk_percent;
      config["general"]["magic_number"] = m_defaultConfig.magic_number;
      
      // Thêm cài đặt chiến lược
      config["strategy"]["vwap_period"] = m_defaultConfig.vwap_period;
      config["strategy"]["rsi_period"] = m_defaultConfig.rsi_period;
      config["strategy"]["rsi_oversold"] = m_defaultConfig.rsi_oversold;
      config["strategy"]["rsi_overbought"] = m_defaultConfig.rsi_overbought;
      config["strategy"]["bb_period"] = m_defaultConfig.bb_period;
      config["strategy"]["bb_deviation"] = m_defaultConfig.bb_deviation;
      config["strategy"]["atr_period"] = m_defaultConfig.atr_period;
      
      // Thêm cài đặt TP/SL
      config["risk"]["sl_atr_multiplier"] = m_defaultConfig.sl_atr_multiplier;
      config["risk"]["tp1_atr_multiplier"] = m_defaultConfig.tp1_atr_multiplier;
      config["risk"]["tp2_atr_multiplier"] = m_defaultConfig.tp2_atr_multiplier;
      config["risk"]["tp3_atr_multiplier"] = m_defaultConfig.tp3_atr_multiplier;
      config["risk"]["tp1_percent"] = m_defaultConfig.tp1_percent;
      config["risk"]["tp2_percent"] = m_defaultConfig.tp2_percent;
      config["risk"]["tp3_percent"] = m_defaultConfig.tp3_percent;
      
      // Thêm cài đặt quản lý rủi ro
      config["risk"]["use_atr_adaptive_sizing"] = m_defaultConfig.use_atr_adaptive_sizing;
      config["risk"]["atr_base_period"] = m_defaultConfig.atr_base_period;
      config["risk"]["enable_scaling_after_loss"] = m_defaultConfig.enable_scaling_after_loss;
      config["risk"]["scaling_factor"] = m_defaultConfig.scaling_factor;
      
      // Thêm bộ lọc thị trường
      config["filters"]["use_adx_filter"] = m_defaultConfig.use_adx_filter;
      config["filters"]["adx_period"] = m_defaultConfig.adx_period;
      config["filters"]["adx_trending_threshold"] = m_defaultConfig.adx_trending_threshold;
      config["filters"]["adx_ranging_threshold"] = m_defaultConfig.adx_ranging_threshold;
      
      // Thêm cài đặt ghi log
      config["logging"]["enable_detailed_logging"] = m_defaultConfig.enable_detailed_logging;
      config["logging"]["log_directory"] = m_defaultConfig.log_directory;
      
      // Chuyển đổi sang chuỗi JSON
      string jsonStr = config.Serialize();
      
      // Lưu vào file
      if(!m_file.Open(m_configFilePath, FILE_WRITE|FILE_TXT))
      {
         Print("Lỗi khi tạo file cấu hình: ", GetLastError());
         return false;
      }
      
      m_file.WriteString(jsonStr);
      m_file.Close();
      
      Print("File cấu hình mặc định đã được tạo: ", m_configFilePath);
      return true;
   }

public:
   // Constructor
   CConfigManager()
   {
      m_eaName = "TripleConfirmation";
      m_configFilePath = "MQL5\\Files\\Triple_Confirmation_System\\Data\\config.json";
      
      // Khởi tạo cấu hình mặc định
      InitDefaultConfig();
   }
   
   // Destructor
   ~CConfigManager() { }
   
   // Khởi tạo
   bool Init(string eaName = "TripleConfirmation")
   {
      m_eaName = eaName;
      m_configFilePath = "MQL5\\Files\\Triple_Confirmation_System\\Data\\config.json";
      
      // Tạo thư mục nếu chưa tồn tại
      string dirPath = "MQL5\\Files\\Triple_Confirmation_System\\Data";
      if(!FolderCreate(dirPath))
      {
         int lastError = GetLastError();
         if(lastError != ERR_DIRECTORY_ALREADY_EXISTS)
         {
            Print("Lỗi khi tạo thư mục cấu hình: ", lastError);
            return false;
         }
      }
      
      // Kiểm tra file cấu hình đã tồn tại chưa
      if(FileIsExist(m_configFilePath))
      {
         // Tải file cấu hình đã tồn tại
         if(!LoadConfig())
         {
            Print("Lỗi khi tải file cấu hình. Tạo file mới...");
            return CreateDefaultConfigFile();
         }
      }
      else
      {
         // Tạo file cấu hình mới
         return CreateDefaultConfigFile();
      }
      
      return true;
   }
   
   // Tải cấu hình từ file
   bool LoadConfig()
   {
      if(!m_file.Open(m_configFilePath, FILE_READ|FILE_TXT))
      {
         Print("Lỗi khi mở file cấu hình: ", GetLastError());
         return false;
      }
      
      // Đọc toàn bộ nội dung file
      string jsonStr = m_file.ReadString();
      m_file.Close();
      
      if(jsonStr == "")
      {
         Print("File cấu hình trống");
         return false;
      }
      
      // Phân tích JSON
      if(!m_config.Deserialize(jsonStr))
      {
         Print("Lỗi khi phân tích file cấu hình JSON");
         return false;
      }
      
      Print("Cấu hình đã được tải thành công");
      return true;
   }
   
   // Lưu cấu hình hiện tại vào file
   bool SaveConfig()
   {
      // Chuyển thành chuỗi JSON
      string jsonStr = m_config.Serialize();
      
      // Lưu vào file
      if(!m_file.Open(m_configFilePath, FILE_WRITE|FILE_TXT))
      {
         Print("Lỗi khi mở file cấu hình để ghi: ", GetLastError());
         return false;
      }
      
      m_file.WriteString(jsonStr);
      m_file.Close();
      
      Print("Cấu hình đã được lưu thành công");
      return true;
   }
   
   // Phương thức lấy giá trị cấu hình
   
   // Cài đặt chung
   bool GetEnableTrading() { return m_config["general"]["enable_trading"].ToBool(m_defaultConfig.enable_trading); }
   bool GetEnableNewsFilter() { return m_config["general"]["enable_news_filter"].ToBool(m_defaultConfig.enable_news_filter); }
   double GetRiskPercent() { return m_config["general"]["risk_percent"].ToDouble(m_defaultConfig.risk_percent); }
   int GetMagicNumber() { return m_config["general"]["magic_number"].ToInt(m_defaultConfig.magic_number); }
   
   // Cài đặt chiến lược
   int GetVwapPeriod() { return m_config["strategy"]["vwap_period"].ToInt(m_defaultConfig.vwap_period); }
   int GetRsiPeriod() { return m_config["strategy"]["rsi_period"].ToInt(m_defaultConfig.rsi_period); }
   int GetRsiOversold() { return m_config["strategy"]["rsi_oversold"].ToInt(m_defaultConfig.rsi_oversold); }
   int GetRsiOverbought() { return m_config["strategy"]["rsi_overbought"].ToInt(m_defaultConfig.rsi_overbought); }
   int GetBbPeriod() { return m_config["strategy"]["bb_period"].ToInt(m_defaultConfig.bb_period); }
   double GetBbDeviation() { return m_config["strategy"]["bb_deviation"].ToDouble(m_defaultConfig.bb_deviation); }
   int GetAtrPeriod() { return m_config["strategy"]["atr_period"].ToInt(m_defaultConfig.atr_period); }
   
   // Cài đặt TP/SL
   double GetSlAtrMultiplier() { return m_config["risk"]["sl_atr_multiplier"].ToDouble(m_defaultConfig.sl_atr_multiplier); }
   double GetTp1AtrMultiplier() { return m_config["risk"]["tp1_atr_multiplier"].ToDouble(m_defaultConfig.tp1_atr_multiplier); }
   double GetTp2AtrMultiplier() { return m_config["risk"]["tp2_atr_multiplier"].ToDouble(m_defaultConfig.tp2_atr_multiplier); }
   double GetTp3AtrMultiplier() { return m_config["risk"]["tp3_atr_multiplier"].ToDouble(m_defaultConfig.tp3_atr_multiplier); }
   int GetTp1Percent() { return m_config["risk"]["tp1_percent"].ToInt(m_defaultConfig.tp1_percent); }
   int GetTp2Percent() { return m_config["risk"]["tp2_percent"].ToInt(m_defaultConfig.tp2_percent); }
   int GetTp3Percent() { return m_config["risk"]["tp3_percent"].ToInt(m_defaultConfig.tp3_percent); }
   
   // Cài đặt quản lý rủi ro
   bool GetUseAtrAdaptiveSizing() { return m_config["risk"]["use_atr_adaptive_sizing"].ToBool(m_defaultConfig.use_atr_adaptive_sizing); }
   int GetAtrBasePeriod() { return m_config["risk"]["atr_base_period"].ToInt(m_defaultConfig.atr_base_period); }
   bool GetEnableScalingAfterLoss() { return m_config["risk"]["enable_scaling_after_loss"].ToBool(m_defaultConfig.enable_scaling_after_loss); }
   double GetScalingFactor() { return m_config["risk"]["scaling_factor"].ToDouble(m_defaultConfig.scaling_factor); }
   
   // Bộ lọc thị trường
   bool GetUseAdxFilter() { return m_config["filters"]["use_adx_filter"].ToBool(m_defaultConfig.use_adx_filter); }
   int GetAdxPeriod() { return m_config["filters"]["adx_period"].ToInt(m_defaultConfig.adx_period); }
   int GetAdxTrendingThreshold() { return m_config["filters"]["adx_trending_threshold"].ToInt(m_defaultConfig.adx_trending_threshold); }
   int GetAdxRangingThreshold() { return m_config["filters"]["adx_ranging_threshold"].ToInt(m_defaultConfig.adx_ranging_threshold); }
   
   // Cài đặt ghi log
   bool GetEnableDetailedLogging() { return m_config["logging"]["enable_detailed_logging"].ToBool(m_defaultConfig.enable_detailed_logging); }
   string GetLogDirectory() { return m_config["logging"]["log_directory"].ToStr(m_defaultConfig.log_directory); }
   
   // Thiết lập giá trị cấu hình (ví dụ cho một số tham số quan trọng)
   void SetRiskPercent(double value) { m_config["general"]["risk_percent"] = value; }
   void SetEnableTrading(bool value) { m_config["general"]["enable_trading"] = value; }
   
   // Có thể thêm các phương thức Set khác khi cần
};