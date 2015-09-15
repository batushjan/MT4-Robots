//+------------------------------------------------------------------+
//|                                                  TimeManager.mqh |
//|                                            Copyright 2015, Didbl |
//|                                            https://www.didbl.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, Didbl"
#property link      "https://www.didbl.com"
#property version   "1.00"
#property strict

int   StartHour,                    
      EndHour,
      GMTUsed,
      GMTDesired;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class TimeManager
  {
private:
      
public:
      void  TimeManager(int startHour, int endHour, int gmtUsed, int gmtDesired);
      void  ~TimeManager();

      bool  IsAppropriateTimeFrame();
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
TimeManager::TimeManager()
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
TimeManager::~TimeManager()
  {
  }
//+------------------------------------------------------------------+


bool IsAppropriateTimeFrame()
{

   // Get Server Time Value;
   int CurrentDate = TimeCurrent();
   // Set Time to GMT +0;
   CurrentDate = CurrentDate - GMTUsed * 3600; 
   // Set Time to Time Zone needed
   CurrentDate = CurrentDate + GMTDesired * 3600;
   
   return (StartHour <= TimeHour(CurrentDate) && TimeHour(CurrentDate) < EndHour);
   
}