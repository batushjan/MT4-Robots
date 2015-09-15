//+------------------------------------------------------------------+
//|                                                 MedianTrader.mq4 |
//|                                       Copyright 2013, Didble.com |
//|                                                       didble.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Didble.com"
#property link      "didble.com"
#property strict

#define VERSION 0.4
// 0.2         Revised Consecutive behaviour
//             Added Decisive_Amount Parameter
//             to denote the maximum number of Orders in a group,
//             to allow opening of another group of Orders
//             
// 0.3         Added Invert Parameter
//             allows inverting the opening of Buy and Sell Orders.
//             
// 0.4         Added First Moving Stop Loss
//             Revise the OpenOrder to change the StopLoss/TakeProfit 
//             to MarginStop only on Error
//             
// 0.5         Added Second Moving Stop Loss
//             Revised First Moving Stop Loss - Margin calculations 
//             

int Count = 0;

input int               MA_Period   = 50;
input ENUM_MA_METHOD    MA_Type     = MODE_SMA;
input int     Concomitant       = 0;
input int     Consecutive       = 0;
input int     Decisive_Amount   = 0;
input double  Lots              = 0.1;

input double  StopLoss1         = 10;
input double  StopLoss2         = 10;
input double  StopLoss3         = 10;
input double  StopLoss4         = 10;
input double  StopLoss5         = 10;

input double  TakeProfit1       = 25;
input double  TakeProfit2       = 50;
input double  TakeProfit3       = 75;
input double  TakeProfit4       = 100;
input double  TakeProfit5       = 125;

input double  FirstChangeLevelPips1      = 15; 
input double  FirstChangeLevelPips2      = 25;
input double  FirstChangeLevelPips3      = 50;
input double  FirstChangeLevelPips4      = 65;
input double  FirstChangeLevelPips5      = 90;

input double  SecondChangeLevelPercent1  = 90;
input double  SecondChangeLevelPercent2  = 90;
input double  SecondChangeLevelPercent3  = 90;
input double  SecondChangeLevelPercent4  = 90;
input double  SecondChangeLevelPercent5  = 90;

input double  SecondChangeValuePercent1  = 70;
input double  SecondChangeValuePercent2  = 70;
input double  SecondChangeValuePercent3  = 70;
input double  SecondChangeValuePercent4  = 70;
input double  SecondChangeValuePercent5  = 70;


input bool    UseTimeFilter     = false;
input int     GMTUsed           = 0;        // The GMT your Sever/Broker Operates
input int     GMTDesired        = 0;        // The GMT your trade operationss take place
input int     StartHour;                    // The StartDate in the GMTDesired format
input int     EndHour;                      // The EndDate in the GMTDesired format

input bool    Invert            = false;

struct OrderDetails
{
   int   TicketNumber;
   double   _OrderType;
   double   MagicNumber;
   double   _Lots;
   double   OpenPrice;
   double   StopLoss;
   double   TakeProfit;
   bool     HasComment;
   bool     FirstChangeApplied;
   bool     SecondChangeApplied;
   /*
   //--- Constructor 
   OrderDetails()
   {
      TicketNumber = 0;
      _OrderType = 0;
      MagicNumber = 0;
      _Lots = 0;
      OpenPrice = 0.0;
      StopPrice = 0.0;
      TakeProfit = 0.0;
      _Comment = 0.0;
      FirstChangeApplied = false;
      SecondChangeApplied = false;
   }
   //--- Destructor
   ~OrderDetails() { }
   */
};

enum GroupState
{
   Free                                = 0,
   OrderNumberLessThanDecisiveAmount   = 1,
   OrderNumberMoreThanDecisiveAmount   = 2,
};

enum MediumAverageType
{

};



// ArrayFormat
// 1  TicketNumber 
// 2  OrderType 
// 3  MagicNumber 
// 4  Lots 
// 5  OpenPrice 
// 6  StopLoss 
// 7  TakeProfit 
// 8  Comment
// 9  Has First Stop Loss Change Applied
// 10 Has Second Stop Loss Change Applied
//


//[Consecutive Number][Concomitend Number]
OrderDetails SellOrder[100][5];
OrderDetails BuyOrder[100][5];




// 0 State Group Free
// 1 State Group Order Amount is less than Decisive Amount
// 2 State Group Order Amount is more than Decisive Amount
// [Consecutive Number]
GroupState SellGroupState[100];
GroupState BuyGroupState[100];

double StopLoss[5];
double TakeProfit[5];
double FirstChangeLevelPips[5];
double SecondChangeLevelPercent[5];
double SecondChangeValuePercent[5];

int BuyGroupCount;
int SellGroupCount;

// ---------------------
int     pips2points;    // slippage  3 pips    3=points    30=points
double  pips2dbl;       // Stoploss 15 pips    0.015      0.0150
int     Digits_pips;    // DoubleToStr(dbl/pips2dbl, Digits.pips)

void OnInit()
{
   // Set StopLoss & Take Profit Arrays

   StopLoss[0] = StopLoss1;
   StopLoss[1] = StopLoss2;
   StopLoss[2] = StopLoss3;
   StopLoss[3] = StopLoss4;
   StopLoss[4] = StopLoss5;

   TakeProfit[0] = TakeProfit1;
   TakeProfit[1] = TakeProfit2;
   TakeProfit[2] = TakeProfit3;
   TakeProfit[3] = TakeProfit4;
   TakeProfit[4] = TakeProfit5;
   
   FirstChangeLevelPips[0] = FirstChangeLevelPips1;
   FirstChangeLevelPips[1] = FirstChangeLevelPips2;
   FirstChangeLevelPips[2] = FirstChangeLevelPips3;
   FirstChangeLevelPips[3] = FirstChangeLevelPips4;
   FirstChangeLevelPips[4] = FirstChangeLevelPips5;
   
   SecondChangeLevelPercent[0] = SecondChangeLevelPercent1;
   SecondChangeLevelPercent[1] = SecondChangeLevelPercent2;
   SecondChangeLevelPercent[2] = SecondChangeLevelPercent3;
   SecondChangeLevelPercent[3] = SecondChangeLevelPercent4;
   SecondChangeLevelPercent[4] = SecondChangeLevelPercent5;
   
   SecondChangeValuePercent[0] = SecondChangeValuePercent1;
   SecondChangeValuePercent[1] = SecondChangeValuePercent2;
   SecondChangeValuePercent[2] = SecondChangeValuePercent3;
   SecondChangeValuePercent[3] = SecondChangeValuePercent4;
   SecondChangeValuePercent[4] = SecondChangeValuePercent5;
   
   // Set up 

   if (Digits % 2 == 1)
   {      
      pips2dbl    = Point*10; pips2points = 10;   Digits_pips = 1;
   }
   else
   {
      pips2dbl    = Point;    pips2points =  1;   Digits_pips = 0;
   }

   return ;
}

void OnDeinit(const int value)
{
   return;
}

void OnTick()
{
   // Enforce Stop Loss Change on Profit level taken
   
   ProcessChartData();
   
   UpdateStopLossData();

   return;
  }
//+------------------------------------------------------------------+

void ProcessChartData()
{
   double MA_Value = 0;
   
   // Check if the current number of bars is more than MA_Period
   // for the evaluation of MA_Value;
   bool canReadMovingAverageData = Bars < MA_Period;
   if (canReadMovingAverageData == true)
      return;
      
   if (IsNewData() == false)
      return;

   if (IsAppropriateTimeFrame() == false)
      return;

         
   // Get Mediaum average value         
      MA_Value = iMA(NULL, 0, MA_Period, 0, MA_Type,   PRICE_TYPICAL, 0);
      
      if (Open[1] > Close[1] && MA_Value > Close[1] && MA_Value < Open[1])
      {
         if (Invert) 
         {
            if (CanOpenBuy() == true)
            {
               OpenBuyOrderGroup();
            }
         } else 
         {
            if (CanOpenSell() == true)
            {
               OpenSellOrderGroup();
            }
         }
      }
   
      if (Close[1] > Open[1] && MA_Value > Open[1] && MA_Value < Close[1])
      {
         if (Invert)
         {
            if (CanOpenSell() == true)
            {
               OpenSellOrderGroup();
            }
         }
         else
         {
            if (CanOpenBuy() == true)
            {
               OpenBuyOrderGroup();
            }
         }
      }
   
   return;
}

bool IsNewData()
{
   static datetime LastTime;
   
   if (LastTime != Time[1])
   {
      LastTime = Time[1];
      return true;
   }
   
   return false;
}

bool IsAppropriateTimeFrame()
{

   if (UseTimeFilter == false)
      return (true);
   
   // Get Server Time Value;
   int CurrentDate = TimeCurrent();
   // Set Time to GMT +0;
   CurrentDate = CurrentDate - GMTUsed * 3600; 
   // Set Time to Time Zone needed
   CurrentDate = CurrentDate + GMTDesired * 3600;
   
   return (StartHour <= TimeHour(CurrentDate) && TimeHour(CurrentDate) <= EndHour);
   
}

void UpdateBuyData()
{
   if (Consecutive <= 0 || Concomitant <= 0)
      return;
   
   //Alert("Update BuyOrderData : BuyGroupCount ", BuyGroupCount);
   // Foreach consecutive Group of Orders
   for (int currentGroupNumber = 0; currentGroupNumber < BuyGroupCount; currentGroupNumber++)
   {
      UpdateBuyOrderGroup(currentGroupNumber);
   }
   
}

void UpdateBuyOrderGroup(int GroupNumber)
{
   int amount = 0; // Group Amount of Orders
   
   // For each order in concomitent Group of Orders
   for (int currentOrderNumber = 0; currentOrderNumber < Concomitant; currentOrderNumber++)
   {
      bool found = UpdateBuyOrder(GroupNumber, currentOrderNumber);
      
      amount = amount + found; // When the Order is found increase the group amount of orders with 1
   }
      
   if (amount == 0)
   {
      //Alert("BuyGroupState #",currentGroupNumber, " - 0");
      BuyGroupState[GroupNumber] = 0;
   } else if (amount > 0 && Decisive_Amount >= amount)
   {
      //Alert("BuyGroupState #",currentGroupNumber, " - 1");
      BuyGroupState[GroupNumber] = 1;
   } else //if (amount > Decisive_Amount && Concomitant >= amount)
   {
      //Alert("BuyGroupState #",currentGroupNumber, " - 2");
      BuyGroupState[GroupNumber] = 2;
   }
}

bool UpdateBuyOrder(int GroupNumber, int OrderNumber)
{
   bool found = false;
   
   int TicketNumber = BuyOrder[GroupNumber][OrderNumber].TicketNumber;
         
   if (TicketNumber != 0)
   {
      for(int i = 0; i < OrdersTotal(); i++)
      {
         if ((OrderSelect(i, SELECT_BY_POS) == true) && (OrderSymbol()==Symbol()))
         {
            if (OrderTicket() == TicketNumber) // Same Ticket
            {
               found = true;
               break;
            }
         }
      }
            
      if (found == false)
      {
         // ClearData - The Buy Order Was Closed 
         // Alert("Removed Buy Ticket #", BuyOrder[currentGroupNumber][currentOrderNumber][0]," GroupNumber #",currentGroupNumber," OrderNumber #", currentOrderNumber);
         OrderDetails details = {0, 0, 0, 0, 0, 0, 0, 0, false, false};
         BuyOrder[GroupNumber][OrderNumber] = details;
      }
   }
   
   return (found);
}


void UpdateSellData()
{
   if (Consecutive <= 0 || Concomitant <= 0)
      return;
   
   // Foreach consecutive Group of Orders
   for (int currentGroupNumber = 0; currentGroupNumber < SellGroupCount; currentGroupNumber++)
   {
      UpdateSellOrderGroup(currentGroupNumber);
   }

}

void UpdateSellOrderGroup(int GroupNumber)
{
   int amount = 0;
      // For each order in concomitent Group of Orders
   for (int currentOrderNumber = 0; currentOrderNumber < Concomitant; currentOrderNumber++)
   {
      bool found = UpdateSellOrder(GroupNumber, currentOrderNumber);
      amount = amount + found;
   }
      
   // Check Concomitant Buy Group of order State
   if (amount == 0)
   {
      //Alert("SellGroupState #",currentGroupNumber, " - 0");
      SellGroupState[GroupNumber] = 0;
   } else if (amount > 0  && Decisive_Amount >= amount)
   {
      //Alert("SellGroupState #",currentGroupNumber, " - 1");
      SellGroupState[GroupNumber] = 1;
   }
   else // if (amount > Decisive_Amount && Concomitant >= amount)
   {
      //Alert("SellGroupState #",GroupNumber, " - 2");
      SellGroupState[GroupNumber] = 2;
   }
}

bool UpdateSellOrder(int GroupNumber, int OrderNumber)
{
   bool found = false;
   int ticketNumber = SellOrder[GroupNumber][OrderNumber].TicketNumber;
         
   if (ticketNumber != 0)
   {
      
      for(int i = 0; i < OrdersTotal(); i++)
      {
         if ((OrderSelect(i, SELECT_BY_POS) == true) && (OrderSymbol()==Symbol()))
         {
            if (OrderTicket() == ticketNumber) // Same Ticket
            {
               found = true;
               break;
            }
         }
      }
            
      if (found == false)
      {
         // ClearData - The Sell Order Was Closed
         //Alert("Removed Sell Ticket #", SellOrder[currentGroupNumber][currentOrderNumber][0]," GroupNumber #",currentGroupNumber," OrderNumber #", currentOrderNumber);
         
         OrderDetails details = {0, 0, 0, 0, 0, 0, 0, 0, false, false};
         SellOrder[GroupNumber][OrderNumber] = details;
      }
   }
   
   return (found);
}


bool CanOpenBuy()
{

   // Check the number of consecutive trades (0 = Maximal)
   if (Consecutive == 0)
      return (true);
   
   // Check the number of consecutive trades (0 = No trades)
   if (Concomitant == 0)
      return (false);
      
   UpdateBuyData();
   
   int amount = 0;
   
   for(int i = 0; i < BuyGroupCount; i++)
   {
      if (BuyGroupState[i] == 2)
      {
         amount++;
      }
   }
   
   if (Consecutive > amount) // Consecutive is more than the number of Groups with a decisive amount of Orders
   {
      //Alert("CanOpenBuy: Consecutive: ", Consecutive," BuyTotal: ", amount,"  Ask: ", Ask, " Bid: ", Bid, " Open: ", Open[0], " Close: ", Close[0]);
      return (true);
   }
   
   return(false);
   
}

bool CanOpenSell()
{

   // Check the number of consecutive trades (0 = Maximal)
   if (Consecutive == 0)
      return (true);
   
   // Check the number of consecutive trades (0 = No trades)
   if (Concomitant == 0)
      return (false);
      
   UpdateSellData();
   
   int amount = 0;
   
   for(int i = 0; i < SellGroupCount; i++)
   {
      if (SellGroupState[i] == 2)
      {
         amount++;
      }
   }
   
   if (Consecutive > amount)
   {
      //Alert("CanOpenSell: Consecutive: ", Consecutive," SellTotal: ", SellTotal," Ask: ", Ask, " Bid: ", Bid, " Open: ", Open[0], " Close: ", Close[0]);
      return (true);
   }

   return(false);
}

int OpenBuyOrderGroup()
{
   int         GroupNumber = 0,
               currentOrderNumber = 0;

   bool        succeded = false;
   
   GroupNumber = GetNewBuyGroupNumber();
   
   while (currentOrderNumber < Concomitant)
   {
      succeded = OpenBuyOrder(StopLoss[currentOrderNumber], TakeProfit[currentOrderNumber], GroupNumber, currentOrderNumber);
      
      //if (succeded)
      currentOrderNumber++;
   }
   
   return(0);
}

int GetNewBuyGroupNumber()
{
   // Adjust maximal number of Groups
   for(int currentStateNumber = BuyGroupCount - 1; currentStateNumber >= 0; currentStateNumber--)
   {
      if (BuyGroupState[currentStateNumber] == 0)
         BuyGroupCount--;
      else
         break;
   }
   
   
   // Get the group Number to open the Concomitant Orders
   int groupNumber = 0;
   bool groupFound = false;
   for (int currentGroupNumber =0; currentGroupNumber < BuyGroupCount; currentGroupNumber++)
   {
      if (BuyGroupState[currentGroupNumber] == 0)
         {
            groupNumber = currentGroupNumber;
            groupFound = true;
            break;
         }
   }
   
   if (!groupFound)
   {
      groupNumber = BuyGroupCount;
      
      BuyGroupCount++;
   }
   
   return (groupNumber);
}

bool OpenBuyOrder(double _StopLoss, double _TakeProfit, int GroupNumber, int OrderNumber)
{
   int         Ticket = 0,
               Slippage = 3,
               Margin = 0,
               MagicNumber;

   double      SL = 0,
               TP = 0;

   string      Symb;
   
   bool        result = false,
               useMargin = false;

   while (true)
   {
      Symb = Symbol();
      MagicNumber = TimeCurrent();
      
      RefreshRates();
   
      if (useMargin)
      {
         Margin = MarketInfo(Symbol(),MODE_STOPLEVEL );// Last known

         SL = MathMin(
            NormalizeDouble(Bid - Margin * pips2dbl, Digits),
            NormalizeDouble(Ask - _StopLoss * pips2dbl, Digits)); 
         
         
         TP = MathMax(
            NormalizeDouble(Bid + Margin * pips2dbl, Digits),
            NormalizeDouble(Ask + _TakeProfit * pips2dbl, Digits)
         );
         
      }
      else
      {
            SL = NormalizeDouble(Ask - _StopLoss * pips2dbl, Digits);
            TP = NormalizeDouble(Ask + _TakeProfit * pips2dbl, Digits);
      }
   
   //      Alert
   //      (
   //         " Symb: ",             Symb,             // int         Symbol
   //         " CMD: ",              OP_BUY,           // int         CMD
   //         " Volume: ",           Lots,             // double      Volume
   //         " Price: ",            Ask,              // double      Price
   //         " Slippage: ",         Slippage,         // int         Slippage
   //         " StopLoss: ",         SL,               // double      StopLoss
   //         " TakeProfit: ",       TP,               // double      TakeProfit
   //         " Comment: ",          "",               // string      Comment           = NULL
   //         " MagicNumber: ",      MagicNumber,      // int         MagicNumber       = 0
   //         " ExpirationTime: ",   0,                // datetime    ExpirationTime    = 0
   //         " Arrow_Color: ",       Green,             // color       Arrow_Color       = CLR_NONE
   //         " Point: ",             Point
   //      );
      
         Ticket=OrderSend(
            Symb,             // int         Symbol
            OP_BUY,           // int         CMD
            Lots,             // double      Volume
            Ask,              // double      Price
            Slippage,         // int         Slippage
            SL,               // double      StopLoss
            TP,               // double      TakeProfit
            "",               // string      Comment           = NULL
            MagicNumber,      // int         MagicNumber       = 0
            0,                // datetime    ExpirationTime    = 0
            Green             // color       Arrow_Color       = CLR_NONE
         );
   
         if (Ticket<0)                                      // Failed :( 
         {
            //Alert("Buy Error"); 
            int errorValue = GetLastError();                                              // Check for errors:
            if(ProcessErrors(errorValue)==false)     // If the error is critical,
            {
               result = false;
               break;      // Non Overcomable Error
            }
            else
            {
               if (errorValue == 130)
                  useMargin = true;
               continue;   // Overcomable Error
            }                           
         }
         
         // Ticket Processed
         BuyOrder[GroupNumber][OrderNumber].TicketNumber          = Ticket;      // Order number
         BuyOrder[GroupNumber][OrderNumber]._OrderType            =OP_BUY;       // Order type
         BuyOrder[GroupNumber][OrderNumber].MagicNumber           =MagicNumber;  // Magic number 
         BuyOrder[GroupNumber][OrderNumber]._Lots                 =Lots;         // Amount of lots
         BuyOrder[GroupNumber][OrderNumber].OpenPrice             =Ask;          // Order open price
         BuyOrder[GroupNumber][OrderNumber].StopLoss              =SL;           // SL price
         BuyOrder[GroupNumber][OrderNumber].TakeProfit            =TP;           // TP price 
         BuyOrder[GroupNumber][OrderNumber].HasComment            = false;       // If there is no comment
         BuyOrder[GroupNumber][OrderNumber].FirstChangeApplied    = false;       // Has Stop Profit Applied
         BuyOrder[GroupNumber][OrderNumber].SecondChangeApplied   = false;       // Has Stop Profit Second Applied

         result = true;
         break;
      }
   return (result);
}

int OpenSellOrderGroup()
{
   int         GroupNumber = 0,
               currentOrderNumber = 0;
   bool        succeded = false;

   GroupNumber = GetNewSellGroupNumber();
   
   //
   while (currentOrderNumber < Concomitant)
   {
      succeded = OpenSellOrder(StopLoss[currentOrderNumber], TakeProfit[currentOrderNumber], GroupNumber, currentOrderNumber);
      //if (succeded)
         currentOrderNumber++;
   }
   
   return(0);
}

int GetNewSellGroupNumber()
{

   // Adjust current number of Groups (minimize)
   for(int currentStateNumber = SellGroupCount - 1; currentStateNumber >= 0; currentStateNumber --)
   {
      if (SellGroupState[currentStateNumber] == 0)
         SellGroupCount--;
      else
         break;
   }
   
   // Get the group Number to open the Concomitant Orders
   int groupNumber = 0;
   bool groupFound = false;
   for (int currentGroupNumber = 0; currentGroupNumber < SellGroupCount; currentGroupNumber++)
   {
      if (SellGroupState[currentGroupNumber] == 0)
         {
            groupNumber = currentGroupNumber;
            groupFound = true;
            break;
         }
   }
   
   if (!groupFound)
   {
      groupNumber = SellGroupCount;
      SellGroupCount++;
   }
   
   return (groupNumber);
}

bool OpenSellOrder(double _StopLoss, double _TakeProfit, int GroupNumber, int OrderNumber)
{
   bool        result = false,
               useMargin = false;
   
   int         Ticket = 0,
               Slippage = 3,
               Margin = 0,
               MagicNumber;

   double      SL = 0,
               TP = 0,
               StopLossMargin = 0,
               TakeProfitMargin = 0;

   string      Symb;
   
   while (true)
   {
      Symb = Symbol();
      MagicNumber = TimeCurrent();
   
      RefreshRates();
      
      if (useMargin)
      {
         Margin = MarketInfo(Symbol(),MODE_STOPLEVEL);// Last known

         SL = MathMax(
            NormalizeDouble(Bid + _StopLoss * pips2dbl, Digits),
            NormalizeDouble(Ask + Margin * pips2dbl, Digits)
         );
         
         TP = MathMin(
            NormalizeDouble(Bid - _TakeProfit * pips2dbl, Digits),
            NormalizeDouble(Ask - Margin * pips2dbl, Digits)
         );
      }
      else
      {
         SL = NormalizeDouble(Bid + _StopLoss * pips2dbl, Digits);
         TP = NormalizeDouble(Bid - _TakeProfit * pips2dbl, Digits);
      }
      
      
   //      Alert
   //      (
   //         
   //         " Symb: ",             Symb,             // int         Symbol
   //         " CMD: ",              OP_SELL,           // int         CMD
   //         " Volume: ",           Lots,             // double      Volume
   //         " Price: ",            Bid,              // double      Price
   //         " Slippage: ",         Slippage,         // int         Slippage
   //         " StopLoss: ",         Ask + StopLossMargin * Point,               // double      StopLoss
   //         " TakeProfit: ",       Ask - StopLossMargin * Point,               // double      TakeProfit
   //         " Comment: ",          "",               // string      Comment           = NULL
   //         " MagicNumber: ",      MagicNumber,      // int         MagicNumber       = 0
   //         " ExpirationTime: ",   0,                // datetime    ExpirationTime    = 0
   //         " Arrow_Color: ",      Green,             // color       Arrow_Color       = CLR_NONE
   //         " Point: ",             0.0 + Point
   //      );      
   
         Ticket=OrderSend(
            Symb,             // int         Symbol
            OP_SELL,          // int         CMD
            Lots,             // double      Volume
            Bid,              // double      Price
            Slippage,         // int         Slippage
            SL,               // double      StopLoss
            TP,               // double      TakeProfit
            "",               // string      Comment           = NULL
            MagicNumber,      // int         MagicNumber       = 0
            0,                // datetime    ExpirationTime    = 0
            Red               // color       Arrow_Color       = CLR_NONE
         );
   
         if (Ticket<0)                                      // Failed :( 
         {
            result = false;
                     
            //Alert("Sell error");                          // Check for errors:
            int Error = GetLastError();
            if(ProcessErrors(Error)==false)     // If the error is critical,
            {
               break; // Non Overcomable Error
            }
            else
            {
               if (Error == 130)
                  useMargin = true;
               continue; // Overcomable Error
            }                           
         }
   
         // Ticket Processed
   
         SellOrder[GroupNumber][OrderNumber].TicketNumber          = Ticket;      // Order number
         SellOrder[GroupNumber][OrderNumber]._OrderType            =OP_SELL;      // Order type
         SellOrder[GroupNumber][OrderNumber].MagicNumber           =MagicNumber;  // Magic number 
         SellOrder[GroupNumber][OrderNumber]._Lots                 =Lots;         // Amount of lots
         SellOrder[GroupNumber][OrderNumber].OpenPrice             =Bid;          // Order open price
         SellOrder[GroupNumber][OrderNumber].StopLoss              =SL;           // SL price
         SellOrder[GroupNumber][OrderNumber].TakeProfit            =TP;           // TP price 
         SellOrder[GroupNumber][OrderNumber].HasComment            = false;       // If there is no comment
         SellOrder[GroupNumber][OrderNumber].FirstChangeApplied    = false;       // Has Stop Profit Applied
         SellOrder[GroupNumber][OrderNumber].SecondChangeApplied   = false;       // Has Stop Profit Second Applied
    
         result = true;
         break;
      }
      
   return (result);
}

bool ProcessErrors(int Error)                    // Custom function
  {
   // Error             // Error number   
   if(Error==0)
      return(false);                      // No error
   //Alert("Error number: ", Error);        // Message
//--------------------------------------------------------------- 3 --
   switch(Error)
     {   // Overcomable errors:
      case 129:         // Wrong price
         RefreshRates();                  // Renew data
         return(true);                    // Error is overcomable
      case 130:         //Alert("Wrong stops. Retrying.");
         RefreshRates();                  // Update data
         return(true);                    // Error is overcomable
      case 135:         // Price changed
         RefreshRates();                  // Renew data
         return(true);                    // Error is overcomable
      case 136:         // No quotes. Waiting for the tick to come
         while(RefreshRates()==false)     // Before new tick
            Sleep(1);                     // Delay in the cycle
         return(true);                    // Error is overcomable
      case 146:         // The trade subsystem is busy
         Sleep(500);                      // Simple solution
         RefreshRates();                  // Renew data
         return(true);                    // Error is overcomable
         // Critical errors:
      case 2 :          // Common error
      case 5 :          // Old version of the client terminal
      case 64:          // Account blocked
      case 133:         // Trading is prohibited
      default:          // Other variants
         return(false);                   // Critical error
     }
//--------------------------------------------------------------- 4 --
}

void UpdateStopLossData()
{

   UpdateBuyStopLoss();

   UpdateSellStopLoss();
}

void UpdateBuyStopLoss()
{
   for (int currentGroupNumber = 0; currentGroupNumber < BuyGroupCount; currentGroupNumber++)
   {
      UpdateBuyGroupStopLoss(currentGroupNumber);
   }
}

void UpdateSellStopLoss()
{
   for (int currentGroupNumber = 0; currentGroupNumber < SellGroupCount; currentGroupNumber++)
   {
      UpdateSellGroupStopLoss(currentGroupNumber);
   }
}

void UpdateBuyGroupStopLoss(int GroupNumber)
{
   for (int currentOrderNumber = 0; currentOrderNumber < Concomitant; currentOrderNumber++)
   {
      UpdateBuyOrderStopLoss(GroupNumber, currentOrderNumber);
   }
}

void UpdateSellGroupStopLoss(int GroupNumber)
{
   for (int currentOrderNumber = 0; currentOrderNumber < Concomitant; currentOrderNumber++)
   {
      UpdateSellOrderStopLoss(GroupNumber, currentOrderNumber);
   }
}

void UpdateBuyOrderStopLoss(int GroupNumber, int OrderNumber)
{
   bool found = false;
   int ticketNumber = BuyOrder[GroupNumber][OrderNumber].TicketNumber;
         
   if (ticketNumber != 0)
   {
      
      for(int i = 0; i < OrdersTotal(); i++)
      {
         if ((OrderSelect(i, SELECT_BY_POS) == true) && (OrderSymbol()==Symbol()))
         {
            if (OrderTicket() == ticketNumber) // Same Ticket
            {
               found = true;
               break;
            }
         }
      }
   }
   
   if (found)
   {
      double price, stopLoss, takeProfit, profit;
      
      price = OrderOpenPrice();
      stopLoss = OrderStopLoss();
      takeProfit = OrderTakeProfit();
      profit = OrderProfit();
      
      if (
      (FirstChangeLevelPips[OrderNumber] != 0) &&
      (BuyOrder[GroupNumber][OrderNumber].FirstChangeApplied == false) &&
      (NormalizeDouble(profit, Digits) >= NormalizeDouble(FirstChangeLevelPips[OrderNumber], Digits))
      )
      {
         bool result = ModifyBuyOrderStopLoss(ticketNumber, price, price + 1 * pips2dbl, takeProfit);
         
         if (result)
            BuyOrder[GroupNumber][OrderNumber].FirstChangeApplied = true;
      }
      
      if (
      (SecondChangeLevelPercent[OrderNumber] != 0)
      // && (SellOrder[GroupNumber][OrderNumber].SecondChangeApplied == false)
      )
      {
//         double distanceInPercent = 100 * (Ask - price) / (takeProfit - price);
//         if (NormalizeDouble(distanceInPercent, Digits) >= NormalizeDouble(SecondChangeLevelPercent[OrderNumber], Digits))
//         {
//            double newStopLoss = ((takeProfit - price)* SecondChangeValuePercent[OrderNumber] / 100) + price;
//            
//            bool resultSecondChange = ModifyBuyOrderStopLoss(ticketNumber, price, newStopLoss, takeProfit);
//            if (resultSecondChange)
//               SellOrder[GroupNumber][OrderNumber].SecondChangeApplied = true;
//         }
         
         double TrailingStop_Profit = SecondChangeLevelPercent[OrderNumber];
         double TrailingStop_Percent = SecondChangeValuePercent[OrderNumber];
       
         if (Bid - OrderOpenPrice() > TrailingStop_Profit * Point)
         //(OrderProfit()/MarketInfo(Symbol(),MODE_TICKVALUE)/OrderLots()*Point > TrailingStop_Profit *Point)
           {
            double newSL = NormalizeDouble(OrderOpenPrice()+((Bid-OrderOpenPrice())*(TrailingStop_Percent/100.0)),Digits);
            if(OrderStopLoss() < newSL || OrderStopLoss() == 0.00000)
              {
               bool resultSecondChange = ModifyBuyOrderStopLoss(ticketNumber, price, newSL, takeProfit); 
               if (resultSecondChange)
                  SellOrder[GroupNumber][OrderNumber].SecondChangeApplied = true;
              }
           }           
      }
   }
}

void UpdateSellOrderStopLoss(int GroupNumber, int OrderNumber)
{
   bool found = false;
   int ticketNumber = SellOrder[GroupNumber][OrderNumber].TicketNumber;
         
   if (ticketNumber != 0)
   {
      
      for(int i = 0; i < OrdersTotal(); i++)
      {
         if ((OrderSelect(i, SELECT_BY_POS) == true) && (OrderSymbol()==Symbol()))
         {
            if (OrderTicket() == ticketNumber) // Same Ticket
            {
               found = true;
               break;
            }
         }
      }
   }
   
   if (found)
   {
      double price, stopLoss, takeProfit, profit;
      
      price = OrderOpenPrice();
      stopLoss = OrderStopLoss();
      takeProfit = OrderTakeProfit();
      profit = OrderProfit();

      if (
      (FirstChangeLevelPips[OrderNumber] != 0) &&      
      (SellOrder[GroupNumber][OrderNumber].FirstChangeApplied == false) &&
      (NormalizeDouble(profit, Digits) >= NormalizeDouble(FirstChangeLevelPips[OrderNumber], Digits)))
      {
         bool resultFirstChange = ModifySellOrderStopLoss(ticketNumber, price, price - 1 * pips2dbl, takeProfit);
         if (resultFirstChange)
            SellOrder[GroupNumber][OrderNumber].FirstChangeApplied = true;
      }
      
      
      if (
      (SecondChangeLevelPercent[OrderNumber] != 0)
       // && (SellOrder[GroupNumber][OrderNumber].SecondChangeApplied == false)
      )
      {
//         double distanceInPercent = 100 * (price - Bid) / (price - takeProfit);
//         if (NormalizeDouble(distanceInPercent, Digits) >= NormalizeDouble(SecondChangeLevelPercent[OrderNumber], Digits))
//         {
//            double newStopLoss = price - ((price - takeProfit) * SecondChangeValuePercent[OrderNumber] / 100);
//            
//            bool resultSecondChange = ModifySellOrderStopLoss(ticketNumber, price, newStopLoss, takeProfit);
//            if (resultSecondChange)
//               SellOrder[GroupNumber][OrderNumber].SecondChangeApplied = true;
//         }
         
         double TrailingStop_Profit= SecondChangeLevelPercent[OrderNumber];
         double TrailingStop_Percent = SecondChangeValuePercent[OrderNumber];
         if (OrderOpenPrice() - Ask > TrailingStop_Profit * Point)
         //(OrderProfit()/MarketInfo(Symbol(),MODE_TICKVALUE)/OrderLots()*Point > TrailingStop_Profit *Point)
           {
            double newSL = NormalizeDouble(OrderOpenPrice()-((OrderOpenPrice()-Ask)*(TrailingStop_Percent/100.0)), Digits);
            if(OrderStopLoss() > newSL || OrderStopLoss() == 0.00000)
              {
               bool resultSecondChange = ModifySellOrderStopLoss(OrderTicket(), price, newSL, OrderTakeProfit());
               if (resultSecondChange)
                  SellOrder[GroupNumber][OrderNumber].SecondChangeApplied = true;
              }
           }           

      }

   }
}




bool ModifyBuyOrderStopLoss(int Ticket, double Price, double _StopLoss, double _TakeProfit)
{
   bool        result = false,
               useMargin = false;
   
   int         Margin = 0;

   double      SL = 0,
               TP = 0,
               StopLossMargin = 0,
               TakeProfitMargin = 0;
               
   Alert(
      "ModifyBuyOrderStopLoss \n",
      "Ticket : ", Ticket, "\n",
      "Price : ", Price, "\n",
      "StopLoss : ", _StopLoss, "\n",
      "Take Profit : ", _TakeProfit, "\n" );               
   
   while (true)
   {
      if (useMargin)
      {
         Margin = MarketInfo(Symbol(),MODE_STOPLEVEL );// Last known
   
         RefreshRates();
      
         if (Margin > 0)
         {
            if (NormalizeDouble(Bid - Margin * pips2dbl, Digits) < NormalizeDouble(_StopLoss, Digits))
            {
               // The Original Price + 1 
               // is more than Market Magin Stop level 
               // to the Current Market Price
               // the Order can`t be modified
               break;
            }
            else 
            {
               SL = NormalizeDouble(_StopLoss, Digits);
            }
         }
         else 
         {
            SL = NormalizeDouble(_StopLoss, Digits);
         }
      }
      else
      {
         SL = NormalizeDouble(_StopLoss, Digits);
      }
      
      //Alert("Applied Stop Loss : ", SL);
      
      Alert("BUY MO: #",Ticket," P: ", Price, " SL: ", _StopLoss, " NSL ", SL, " TP ", _TakeProfit);
      bool response = OrderModify(Ticket, Price, SL, _TakeProfit, 0);
      
      if (response == true)
      {
         result = true;
         break;
      }
      
      int Error = GetLastError();
      
      switch(Error)                       // Overcomable errors
      {
         case 130:
            //Alert("Wrong stops. Retrying.");
            RefreshRates();               // Update data
            useMargin = true;
            continue;                     // At the next iteration
         case 136:
            //Alert("No prices. Waiting for a new tick..");
            while(RefreshRates()==false)  // To the new tick
               Sleep(1);                  // Cycle delay
            continue;                     // At the next iteration
         case 146:
            //Alert("Trading subsystem is busy. Retrying ");
            Sleep(500);                   // Simple solution
            RefreshRates();               // Update data
            continue;                     // At the next iteration
            // Critical errors
         case 2:
            //Alert("Common error.");
            break;                        // Exit 'switch'
         case 5:
            //Alert("Old version of the client terminal.");
            break;                        // Exit 'switch'
         case 64:
            //Alert("Account is blocked.");
            break;                        // Exit 'switch'
         case 133:
            //Alert("Trading is prohibited");
            break;                        // Exit 'switch'
         default:
            //Alert("Occurred error ",Error);//Other errors
            break;
     }
     break;
   }
   
   //Alert("BMO #", Ticket, " result ", result);
   return (result);
}

bool ModifySellOrderStopLoss(int Ticket, double Price, double _StopLoss, double _TakeProfit)
{
   bool        result = false,
               useMargin = false;
   
   int         Margin = 0;

   double      SL = 0,
               TP = 0,
               StopLossMargin = 0,
               TakeProfitMargin = 0;
               
      Alert(
      "ModifySellOrderStopLoss \n",
      "Ticket : ", Ticket, "\n",
      "Price : ", Price, "\n",
      "StopLoss : ", _StopLoss, "\n",
      "Take Profit : ", _TakeProfit, "\n" );               


   while (true)
   {
      if (useMargin)
      {   
         Margin = MarketInfo(Symbol(),MODE_STOPLEVEL );// Last known
   
         RefreshRates();
      
         if (Margin > 0)
         {
            if (NormalizeDouble(Ask + Margin * pips2dbl, Digits) > NormalizeDouble(_StopLoss, Digits))
            {
               // The New StopLoss
               // is more than Market Magin Stop level 
               // to the Current Market Price
               // the Order can`t be modified
               break;
            }
            else 
            {
               SL = NormalizeDouble(_StopLoss, Digits);
            }
         }
         else 
         {
            SL = NormalizeDouble(_StopLoss, Digits);
         }
      }
      else
      {
         SL = NormalizeDouble(_StopLoss, Digits);
      }
      Alert("SELL MO: Ask: ", Ask, " Margin: ", Margin, " Minimal Stop Loss : ", NormalizeDouble(Ask + Margin * pips2dbl, Digits), " Stop Loss: ", NormalizeDouble(_StopLoss, Digits));
      //Alert("Applied Stop Loss : ", SL);
      Alert("SELL MO: #",Ticket," P: ", Price, " SL: ", _StopLoss, " NSL ", SL, " TP ", _TakeProfit);
      
      bool response = OrderModify(Ticket, Price, SL, _TakeProfit, 0);
      
      if (response)
      {
         result = true;
         break;
      }
        
      int Error = GetLastError();
      
      switch(Error)                       // Overcomable errors
      {
         case 130:
            //Alert("Wrong stops. Retrying.");
            RefreshRates();               // Update data
            useMargin = true;
            continue;                     // At the next iteration
         case 136:
            //Alert("No prices. Waiting for a new tick..");
            while(RefreshRates()==false)  // To the new tick
               Sleep(1);                  // Cycle delay
            continue;                     // At the next iteration
         case 146:
            //Alert("Trading subsystem is busy. Retrying ");
            Sleep(500);                   // Simple solution
            RefreshRates();               // Update data
            continue;                     // At the next iteration
            // Critical errors
         case 2:
            //Alert("Common error.");
            break;                        // Exit 'switch'
         case 5:
            //Alert("Old version of the client terminal.");
            break;                        // Exit 'switch'
         case 64:
            //Alert("Account is blocked.");
            break;                        // Exit 'switch'
         case 133:
            //Alert("Trading is prohibited");
            break;                        // Exit 'switch'
         default:
            //Alert("Occurred error ",Error);//Other errors
            break;
     }
     break;
   }
   
   //Alert("SMO #", Ticket, " result ", result);
   return (result);
}


