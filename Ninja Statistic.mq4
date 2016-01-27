//+------------------------------------------------------------------+
//|                                              Ninja Statistic.mq4 |
//|                                            Copyright 2015, Didbl |
//|                                            https://www.didbl.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, Didbl"
#property link      "https://www.didbl.com"
#property version   "1.00"
#property strict

input double Lots = 1.0;
input double TakeProfit = 40;
input double StopLoss = 25;

input bool Invert = false;
input int  MagicNumber = 9009;
      
struct OrderDetails
{
   int      TicketNumber;
   int      _OrderType;
   int      MagicNumber;
   double   _Lots;
   double   OpenPrice;
   double   StopLoss;
   double   TakeProfit;
   bool     HasComment;

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
      _Comment = false;
      TrailingStopApplied = false;
   }
   //--- Destructor
   ~OrderDetails() { }
   */
};

const OrderDetails defaultOrderDetails = {0, -1, 0, 0, 0, 0, 0, false};
OrderDetails currentOrder = defaultOrderDetails;

// ---------------------
int     pips2points;    // slippage  3 pips    3=points    30=points
double  pips2dbl;       // Stoploss 15 pips    0.015      0.0150
int     Digits_pips;    // DoubleToStr(dbl/pips2dbl, Digits.pips)


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
//---
 if (Digits % 2 == 1)
 {      
  pips2dbl    = Point*10; pips2points = 10;   Digits_pips = 1;
 }
 else
 {
  pips2dbl    = Point;    pips2points =  1;   Digits_pips = 0;
 }

//---
 return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//---
   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//---
 if (IsNewBar())
 {
  if (!HasOrder())
  {
   MakeNewOrder();
  }
 }
 
}
//+------------------------------------------------------------------+
bool IsNewBar()
{
 static datetime LastTime;
 
 if (LastTime != Time[1])
 {
  LastTime = Time[1];
  return true;
 }

 return false;
}

bool HasOrder()
{
 for(int i = 0; i < OrdersTotal(); i++)
 {
  if ((OrderSelect(i, SELECT_BY_POS) == true) && (OrderSymbol()==Symbol()))
  {
   if (OrderMagicNumber() == MagicNumber) // Same Ticket
   {
    return true;
   }
  }
 }

 return false;
}

void MakeNewOrder()
{
 if (Open[1] > Close[1])
 {
  if (!Invert)
  {
   OpenBuyOrder(StopLoss, TakeProfit);
  }
  else
  {
   OpenSellOrder(StopLoss, TakeProfit);
  }
 }
 else if (Open[1] <= Close[1])
 {
  if (!Invert)
  {
   OpenSellOrder(StopLoss, TakeProfit);
  }
  else 
  {
   OpenBuyOrder(StopLoss, TakeProfit);
  }
 }
}

bool OpenBuyOrder(double _StopLoss, double _TakeProfit)
{
   int         Ticket = 0,
               Slippage = 3,
               TerminalStopLevel = 0,
               _MagicNumber;

   double      SL = 0,
               TP = 0;

   string      Symb;
   
   bool        result = false,
               UseStopLevel = false;

   while (true)
   {
      Symb         = Symbol();
      _MagicNumber = MagicNumber;
      
      RefreshRates();
   
      if (UseStopLevel)
      {
         TerminalStopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL );// Last known

         if (TerminalStopLevel > _StopLoss) {
            SL = NormalizeDouble(Bid - TerminalStopLevel * pips2dbl, Digits);
         }
         else
         {
            SL = NormalizeDouble(Ask - _StopLoss * pips2dbl, Digits);
         }
   
         if (TerminalStopLevel > _TakeProfit)
         {
            TP = NormalizeDouble(Bid + TerminalStopLevel * pips2dbl, Digits);
         }
         else
         {
            TP = NormalizeDouble(Ask + _TakeProfit * pips2dbl, Digits);
         }
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
                  UseStopLevel = true;
               continue;   // Overcomable Error
            }                           
         }

         result = true;
         break;
      }
   return (result);
}

bool OpenSellOrder(double _StopLoss, double _TakeProfit)
{
   bool        result        = false,
               UseStopLevel  = false;
   
   int         Ticket = 0,
               Slippage = 3,
               TerminalStopLevel = 0,
               _MagicNumber;

   double      SL = 0,
               TP = 0,
               StopLossMargin   = 0,
               TakeProfitMargin = 0;

   string      Symb;
   
   while (true)
   {
      Symb         = Symbol();
      _MagicNumber = MagicNumber;
   
      RefreshRates();
      
      if (UseStopLevel)
      {
         TerminalStopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL );// Last known

         if (TerminalStopLevel > _StopLoss) {
            SL = NormalizeDouble(Ask + TerminalStopLevel * pips2dbl, Digits);
         }
         else
         {
            SL = NormalizeDouble(Bid + _StopLoss * pips2dbl, Digits);
         }
   
         if (TerminalStopLevel > _TakeProfit)
         {
            TP = NormalizeDouble(Ask - TerminalStopLevel * pips2dbl, Digits);
         }
         else
         {
            TP = NormalizeDouble(Bid - _TakeProfit * pips2dbl, Digits);
         }
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
                  UseStopLevel = true;
               continue; // Overcomable Error
            }                           
         }
   
         // Ticket Processed
   
         OrderDetails details = defaultOrderDetails;
         
         // Ticket Processed
         details.TicketNumber          = Ticket;      // Order number
         details._OrderType            = OP_BUYSTOP;       // Order type
         details.MagicNumber           = MagicNumber;  // Magic number 
         details._Lots                 = Lots;         // Amount of lots
         details.OpenPrice             = Bid;          // Order open price
         details.StopLoss              = SL;           // SL price
         details.TakeProfit            = TP;           // TP price 
         details.HasComment            = false;       // If there is no comment
         
         currentOrder = details;
    
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
