//+------------------------------------------------------------------+
//|                                            ConfigManager.mqh     |
//|                        Copyright 2025, Your Company              |
//|                                             https://yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://yoursite.com"
#property version   "2.00"

// Khai báo hằng số cần thiết
#ifndef ERR_DIRECTORY_ALREADY_EXISTS
#define ERR_DIRECTORY_ALREADY_EXISTS 4906
#endif

#include <Files\FileTxt.mqh>
#include "..\Include\Json.mqh"

class CConfigManager
{
private:
   string            m_configFilePath;
   string            m_eaName;
   CFileTxt          m_file;
   CJAVal            m_config;
   bool              m_logEnabled;     // Enable detailed logging
   
   // Giá trị mặc định nếu không tải được cấu hình - Updated for v2.0
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
      double   rsi_lower;           // Changed from rsi_oversold
      double   rsi_upper;           // Changed from rsi_overbought
      int      bb_period;
      double   bb_deviation;
      int      atr_period;
      double   vwap_min_distance;   // New in v2.0
      
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
      int      max_consecutive_scaling; // New in v2.0
      
      // Bộ lọc thị trường
      bool     use_adx_filter;
      int      adx_period;
      int      adx_trending_threshold;
      int      adx_ranging_threshold;
      bool     use_time_filter;     // New in v2.0
      int      start_hour;          // New in v2.0
      int      end_hour;            // New in v2.0
      double   volatility_min_ratio; // New in v2.0
      double   volatility_max_ratio; // New in v2.0
      
      // Cài đặt ghi log
      bool     enable_detailed_logging;
      string   log_directory;
   };
   
   DefaultConfig     m_defaultConfig;
   
   // Hàm trợ giúp để truy cập JSON an toàn
   CJAVal* FindSection(string section)
   {
      for(int i=0; i<m_config.Size(); i++)
      {
         if(m_config.m_e[i].m_key == section)
            return GetPointer(m_config.m_e[i]);
      }
      return NULL;
   }
   
   // Hàm truy cập các giá trị từ JSON với kiểm tra null
   bool GetBoolValue(string section, string key, bool defaultValue)
   {
      CJAVal* sectionObj = FindSection(section);
      if(sectionObj == NULL) return defaultValue;
      
      CJAVal* val = sectionObj.FindKey(key);
      if(val == NULL) return defaultValue;
      
      return val.ToBool();
   }
   
   int GetIntValue(string section, string key, int defaultValue)
   {
      CJAVal* sectionObj = FindSection(section);
      if(sectionObj == NULL) return defaultValue;
      
      CJAVal* val = sectionObj.FindKey(key);
      if(val == NULL) return defaultValue;
      
      return (int)val.ToInt();
   }
   
   double GetDoubleValue(string section, string key, double defaultValue)
   {
      CJAVal* sectionObj = FindSection(section);
      if(sectionObj == NULL) return defaultValue;
      
      CJAVal* val = sectionObj.FindKey(key);
      if(val == NULL) return defaultValue;
      
      return val.ToDbl();
   }
   
   string GetStringValue(string section, string key, string defaultValue)
   {
      CJAVal* sectionObj = FindSection(section);
      if(sectionObj == NULL) return defaultValue;
      
      CJAVal* val = sectionObj.FindKey(key);
      if(val == NULL) return defaultValue;
      
      return val.ToStr();
   }
   
   // Hàm thiết lập giá trị vào JSON
   void SetValue(string section, string key, bool value)
   {
      CJAVal* sectionObj = FindSection(section);
      if(sectionObj != NULL)
      {
         (*sectionObj)[key] = value;
      }
      else
      {
         CJAVal newSection;
         newSection.m_key = section;
         newSection[key] = value;
         m_config.Add(newSection);
      }
   }
   
   void SetValue(string section, string key, int value)
   {
      CJAVal* sectionObj = FindSection(section);
      if(sectionObj != NULL)
      {
         (*sectionObj)[key] = value;
      }
      else
      {
         CJAVal newSection;
         newSection.m_key = section;
         newSection[key] = value;
         m_config.Add(newSection);
      }
   }
   
   void SetValue(string section, string key, double value)
   {
      CJAVal* sectionObj = FindSection(section);
      if(sectionObj != NULL)
      {
         (*sectionObj)[key] = value;
      }
      else
      {
         CJAVal newSection;
         newSection.m_key = section;
         newSection[key] = value;
         m_config.Add(newSection);
      }
   }
   
   void SetValue(string section, string key, string value)
   {
      CJAVal* sectionObj = FindSection(section);
      if(sectionObj != NULL)
      {
         (*sectionObj)[key] = value;
      }
      else
      {
         CJAVal newSection;
         newSection.m_key = section;
         newSection[key] = value;
         m_config.Add(newSection);
      }
   }
   
   // Khởi tạo cấu hình mặc định theo Triple Confirmation v2.0
   void InitDefaultConfig()
   {
      // General settings
      m_defaultConfig.enable_trading = true;
      m_defaultConfig.enable_news_filter = true;
      m_defaultConfig.risk_percent = 0.5;        // Updated: 0.5% instead of 1%
      m_defaultConfig.magic_number = 123456;
      
      // Strategy settings
      m_defaultConfig.vwap_period = 20;
      m_defaultConfig.rsi_period = 14;          // Updated: Standard RSI period
      m_defaultConfig.rsi_lower = 30;           // Updated: Standard RSI oversold
      m_defaultConfig.rsi_upper = 70;           // Updated: Standard RSI overbought
      m_defaultConfig.bb_period = 20;
      m_defaultConfig.bb_deviation = 2.0;
      m_defaultConfig.atr_period = 14;
      m_defaultConfig.vwap_min_distance = 0.5;  // New in v2.0
      
      // TP/SL settings
      m_defaultConfig.sl_atr_multiplier = 1.8;   // Updated: Increased from 1.2
      m_defaultConfig.tp1_atr_multiplier = 2.0;  // Updated: Increased from 1.5
      m_defaultConfig.tp2_atr_multiplier = 3.2;  // Updated: Increased from 2.5
      m_defaultConfig.tp3_atr_multiplier = 4.8;  // Updated: Increased from 4.0
      m_defaultConfig.tp1_percent = 40;
      m_defaultConfig.tp2_percent = 35;
      m_defaultConfig.tp3_percent = 25;
      
      // Risk management settings
      m_defaultConfig.use_atr_adaptive_sizing = true;
      m_defaultConfig.atr_base_period = 50;
      m_defaultConfig.enable_scaling_after_loss = true;
      m_defaultConfig.scaling_factor = 0.75;
      m_defaultConfig.max_consecutive_scaling = 3; // New in v2.0
      
      // Market filter settings
      m_defaultConfig.use_adx_filter = true;
      m_defaultConfig.adx_period = 14;
      m_defaultConfig.adx_trending_threshold = 25;
      m_defaultConfig.adx_ranging_threshold = 20;
      m_defaultConfig.use_time_filter = true;      // New in v2.0
      m_defaultConfig.start_hour = 7;              // New in v2.0: 7 GMT (London)
      m_defaultConfig.end_hour = 17;               // New in v2.0: 17 GMT (NY Close)
      m_defaultConfig.volatility_min_ratio = 0.7;  // New in v2.0
      m_defaultConfig.volatility_max_ratio = 1.3;  // New in v2.0
      
      // Logging settings
      m_defaultConfig.enable_detailed_logging = true;
      m_defaultConfig.log_directory = "TripleConfirmation_Logs";
   }
   
   // Tạo file cấu hình mặc định
   bool CreateDefaultConfigFile()
   {
      // Đảm bảo m_config trống
      m_config.Clear();
      
      // Tạo cấu trúc cho general
      CJAVal general;
      general.m_key = "general";
      general["enable_trading"] = m_defaultConfig.enable_trading;
      general["enable_news_filter"] = m_defaultConfig.enable_news_filter;
      general["risk_percent"] = m_defaultConfig.risk_percent;
      general["magic_number"] = m_defaultConfig.magic_number;
      m_config.Add(general);
      
      // Tạo cấu trúc cho strategy
      CJAVal strategy;
      strategy.m_key = "strategy";
      strategy["vwap_period"] = m_defaultConfig.vwap_period;
      strategy["rsi_period"] = m_defaultConfig.rsi_period;
      strategy["rsi_lower"] = m_defaultConfig.rsi_lower;      // Updated name
      strategy["rsi_upper"] = m_defaultConfig.rsi_upper;      // Updated name
      strategy["bb_period"] = m_defaultConfig.bb_period;
      strategy["bb_deviation"] = m_defaultConfig.bb_deviation;
      strategy["atr_period"] = m_defaultConfig.atr_period;
      strategy["vwap_min_distance"] = m_defaultConfig.vwap_min_distance; // New in v2.0
      m_config.Add(strategy);
      
      // Tạo cấu trúc cho risk
      CJAVal risk;
      risk.m_key = "risk";
      risk["sl_atr_multiplier"] = m_defaultConfig.sl_atr_multiplier;
      risk["tp1_atr_multiplier"] = m_defaultConfig.tp1_atr_multiplier;
      risk["tp2_atr_multiplier"] = m_defaultConfig.tp2_atr_multiplier;
      risk["tp3_atr_multiplier"] = m_defaultConfig.tp3_atr_multiplier;
      risk["tp1_percent"] = m_defaultConfig.tp1_percent;
      risk["tp2_percent"] = m_defaultConfig.tp2_percent;
      risk["tp3_percent"] = m_defaultConfig.tp3_percent;
      risk["use_atr_adaptive_sizing"] = m_defaultConfig.use_atr_adaptive_sizing;
      risk["atr_base_period"] = m_defaultConfig.atr_base_period;
      risk["enable_scaling_after_loss"] = m_defaultConfig.enable_scaling_after_loss;
      risk["scaling_factor"] = m_defaultConfig.scaling_factor;
      risk["max_consecutive_scaling"] = m_defaultConfig.max_consecutive_scaling; // New in v2.0
      m_config.Add(risk);
      
      // Tạo cấu trúc cho filters
      CJAVal filters;
      filters.m_key = "filters";
      filters["use_adx_filter"] = m_defaultConfig.use_adx_filter;
      filters["adx_period"] = m_defaultConfig.adx_period;
      filters["adx_trending_threshold"] = m_defaultConfig.adx_trending_threshold;
      filters["adx_ranging_threshold"] = m_defaultConfig.adx_ranging_threshold;
      filters["use_time_filter"] = m_defaultConfig.use_time_filter;         // New in v2.0
      filters["start_hour"] = m_defaultConfig.start_hour;                   // New in v2.0
      filters["end_hour"] = m_defaultConfig.end_hour;                       // New in v2.0
      filters["volatility_min_ratio"] = m_defaultConfig.volatility_min_ratio; // New in v2.0
      filters["volatility_max_ratio"] = m_defaultConfig.volatility_max_ratio; // New in v2.0
      m_config.Add(filters);
      
      // Tạo cấu trúc cho logging
      CJAVal logging;
      logging.m_key = "logging";
      logging["enable_detailed_logging"] = m_defaultConfig.enable_detailed_logging;
      logging["log_directory"] = m_defaultConfig.log_directory;
      m_config.Add(logging);
      
      // Chuyển đổi sang chuỗi JSON
      string jsonStr = m_config.Serialize();
      
      // Lưu vào file
      if(!m_file.Open(m_configFilePath, FILE_WRITE|FILE_TXT))
      {
         int error = GetLastError();
         if(m_logEnabled) Print("Lỗi khi tạo file cấu hình: ", error);
         return false;
      }
      
      m_file.WriteString(jsonStr);
      m_file.Close();
      
      if(m_logEnabled) Print("File cấu hình mặc định v2.0 đã được tạo: ", m_configFilePath);
      return true;
   }

public:
   // Constructor
   CConfigManager() 
   {
      m_eaName = "TripleConfirmation";
      m_configFilePath = "MQL5\\Files\\Triple_Confirmation_System\\Data\\config.json";
      m_logEnabled = true;
      
      // Khởi tạo cấu hình mặc định
      InitDefaultConfig();
   }
   
   // Destructor
   ~CConfigManager() { }
   
   // Khởi tạo
   bool Init(string eaName = "TripleConfirmation", bool enableLogging = true)
   {
      m_eaName = eaName;
      m_logEnabled = enableLogging;
      m_configFilePath = "MQL5\\Files\\Triple_Confirmation_System\\Data\\config.json";
      
      // Tạo thư mục nếu chưa tồn tại
      string dirPath = "MQL5\\Files\\Triple_Confirmation_System\\Data";
      if(!FolderCreate(dirPath))
      {
         int lastError = GetLastError();
         if(lastError != ERR_DIRECTORY_ALREADY_EXISTS)
         {
            if(m_logEnabled) Print("Lỗi khi tạo thư mục cấu hình: ", lastError);
            return false;
         }
      }
      
      // Kiểm tra file cấu hình đã tồn tại chưa
      if(FileIsExist(m_configFilePath))
      {
         // Tải file cấu hình đã tồn tại
         if(!LoadConfig())
         {
            if(m_logEnabled) Print("Lỗi khi tải file cấu hình. Tạo file mới...");
            return CreateDefaultConfigFile();
         }
      }
      else
      {
         // Tạo file cấu hình mới
         if(m_logEnabled) Print("Không tìm thấy file cấu hình. Tạo file mới...");
         return CreateDefaultConfigFile();
      }
      
      return true;
   }
   
   // Tải cấu hình từ file
   bool LoadConfig()
   {
      if(!m_file.Open(m_configFilePath, FILE_READ|FILE_TXT))
      {
         int error = GetLastError();
         if(m_logEnabled) Print("Lỗi khi mở file cấu hình: ", error);
         return false;
      }
      
      // Đọc toàn bộ nội dung file
      string jsonStr = m_file.ReadString();
      m_file.Close();
      
      if(jsonStr == "")
      {
         if(m_logEnabled) Print("File cấu hình trống");
         return false;
      }
      
      // Phân tích JSON
      if(!m_config.Deserialize(jsonStr))
      {
         if(m_logEnabled) Print("Lỗi khi phân tích file cấu hình JSON");
         return false;
      }
      
      if(m_logEnabled) Print("Cấu hình đã được tải thành công");
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
         int error = GetLastError();
         if(m_logEnabled) Print("Lỗi khi mở file cấu hình để ghi: ", error);
         return false;
      }
      
      m_file.WriteString(jsonStr);
      m_file.Close();
      
      if(m_logEnabled) Print("Cấu hình đã được lưu thành công");
      return true;
   }
   
   // Phương thức lấy giá trị cấu hình - Updated for v2.0
   
   // Cài đặt chung
   bool GetEnableTrading() { return GetBoolValue("general", "enable_trading", m_defaultConfig.enable_trading); }
   bool GetEnableNewsFilter() { return GetBoolValue("general", "enable_news_filter", m_defaultConfig.enable_news_filter); }
   double GetRiskPercent() { return GetDoubleValue("general", "risk_percent", m_defaultConfig.risk_percent); }
   int GetMagicNumber() { return GetIntValue("general", "magic_number", m_defaultConfig.magic_number); }
   
   // Cài đặt chiến lược
   int GetVwapPeriod() { return GetIntValue("strategy", "vwap_period", m_defaultConfig.vwap_period); }
   int GetRsiPeriod() { return GetIntValue("strategy", "rsi_period", m_defaultConfig.rsi_period); }
   double GetRsiLower() { return GetDoubleValue("strategy", "rsi_lower", m_defaultConfig.rsi_lower); } // Updated
   double GetRsiUpper() { return GetDoubleValue("strategy", "rsi_upper", m_defaultConfig.rsi_upper); } // Updated
   int GetBbPeriod() { return GetIntValue("strategy", "bb_period", m_defaultConfig.bb_period); }
   double GetBbDeviation() { return GetDoubleValue("strategy", "bb_deviation", m_defaultConfig.bb_deviation); }
   int GetAtrPeriod() { return GetIntValue("strategy", "atr_period", m_defaultConfig.atr_period); }
   double GetVwapMinDistance() { return GetDoubleValue("strategy", "vwap_min_distance", m_defaultConfig.vwap_min_distance); } // New
   
   // Cài đặt TP/SL
   double GetSlAtrMultiplier() { return GetDoubleValue("risk", "sl_atr_multiplier", m_defaultConfig.sl_atr_multiplier); }
   double GetTp1AtrMultiplier() { return GetDoubleValue("risk", "tp1_atr_multiplier", m_defaultConfig.tp1_atr_multiplier); }
   double GetTp2AtrMultiplier() { return GetDoubleValue("risk", "tp2_atr_multiplier", m_defaultConfig.tp2_atr_multiplier); }
   double GetTp3AtrMultiplier() { return GetDoubleValue("risk", "tp3_atr_multiplier", m_defaultConfig.tp3_atr_multiplier); }
   int GetTp1Percent() { return GetIntValue("risk", "tp1_percent", m_defaultConfig.tp1_percent); }
   int GetTp2Percent() { return GetIntValue("risk", "tp2_percent", m_defaultConfig.tp2_percent); }
   int GetTp3Percent() { return GetIntValue("risk", "tp3_percent", m_defaultConfig.tp3_percent); }
   
   // Cài đặt quản lý rủi ro
   bool GetUseAtrAdaptiveSizing() { return GetBoolValue("risk", "use_atr_adaptive_sizing", m_defaultConfig.use_atr_adaptive_sizing); }
   int GetAtrBasePeriod() { return GetIntValue("risk", "atr_base_period", m_defaultConfig.atr_base_period); }
   bool GetEnableScalingAfterLoss() { return GetBoolValue("risk", "enable_scaling_after_loss", m_defaultConfig.enable_scaling_after_loss); }
   double GetScalingFactor() { return GetDoubleValue("risk", "scaling_factor", m_defaultConfig.scaling_factor); }
   int GetMaxConsecutiveScaling() { return GetIntValue("risk", "max_consecutive_scaling", m_defaultConfig.max_consecutive_scaling); } // New
   
   // Bộ lọc thị trường
   bool GetUseAdxFilter() { return GetBoolValue("filters", "use_adx_filter", m_defaultConfig.use_adx_filter); }
   int GetAdxPeriod() { return GetIntValue("filters", "adx_period", m_defaultConfig.adx_period); }
   int GetAdxTrendingThreshold() { return GetIntValue("filters", "adx_trending_threshold", m_defaultConfig.adx_trending_threshold); }
   int GetAdxRangingThreshold() { return GetIntValue("filters", "adx_ranging_threshold", m_defaultConfig.adx_ranging_threshold); }
   bool GetUseTimeFilter() { return GetBoolValue("filters", "use_time_filter", m_defaultConfig.use_time_filter); } // New
   int GetStartHour() { return GetIntValue("filters", "start_hour", m_defaultConfig.start_hour); } // New
   int GetEndHour() { return GetIntValue("filters", "end_hour", m_defaultConfig.end_hour); } // New
   double GetVolatilityMinRatio() { return GetDoubleValue("filters", "volatility_min_ratio", m_defaultConfig.volatility_min_ratio); } // New
   double GetVolatilityMaxRatio() { return GetDoubleValue("filters", "volatility_max_ratio", m_defaultConfig.volatility_max_ratio); } // New
   
   // Cài đặt ghi log
   bool GetEnableDetailedLogging() { return GetBoolValue("logging", "enable_detailed_logging", m_defaultConfig.enable_detailed_logging); }
   string GetLogDirectory() { return GetStringValue("logging", "log_directory", m_defaultConfig.log_directory); }
   
   // Thiết lập giá trị cấu hình - Basic setters, add more as needed
   void SetRiskPercent(double value) { SetValue("general", "risk_percent", value); }
   void SetEnableTrading(bool value) { SetValue("general", "enable_trading", value); }
   void SetVwapMinDistance(double value) { SetValue("strategy", "vwap_min_distance", value); }
   
   // Get configuration summary
   string GetConfigSummary()
   {
      string summary = "Triple Confirmation v2.0 - Configuration Summary\n";
      summary += "----------------------------------------\n";
      summary += "Risk: " + DoubleToString(GetRiskPercent(), 2) + "%\n";
      summary += "SL/TP Multipliers: " + DoubleToString(GetSlAtrMultiplier(), 1) + "/"
                + DoubleToString(GetTp1AtrMultiplier(), 1) + "/"
                + DoubleToString(GetTp2AtrMultiplier(), 1) + "/"
                + DoubleToString(GetTp3AtrMultiplier(), 1) + " ATR\n";
      summary += "ADX Filter: " + (GetUseAdxFilter() ? "Enabled (Ranging < " + IntegerToString(GetAdxRangingThreshold()) + ")" : "Disabled") + "\n";
      summary += "Time Filter: " + (GetUseTimeFilter() ? "Enabled (" + IntegerToString(GetStartHour()) + "-" + IntegerToString(GetEndHour()) + " GMT)" : "Disabled") + "\n";
      summary += "Loss Scaling: " + (GetEnableScalingAfterLoss() ? "Enabled (Factor: " + DoubleToString(GetScalingFactor(), 2) + ", Max: " + IntegerToString(GetMaxConsecutiveScaling()) + ")" : "Disabled") + "\n";
      summary += "ATR Adaptation: " + (GetUseAtrAdaptiveSizing() ? "Enabled" : "Disabled") + "\n";
      
      return summary;
   }
};