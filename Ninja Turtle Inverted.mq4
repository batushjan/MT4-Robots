//+------------------------------------------------------------------+
//|                                                  NinjaTurtle Inverted.mq4 |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, Didbl"
#property link      "https://didbl.com"
#property version   "1.00"
#property strict

#include "Ninja Turtle\EnumNinjaTradeMode.mqh";
#include "Ninja Turtle\EnumPriceChannelMode.mqh";
#include "Ninja Turtle\EnumTimeFilterTradeMode.mqh";
#include "Ninja Turtle\EnumTimeFilterActivationMode.mqh";

input int Price_Channel_Period = 20;
input ENUM_PRICE_CHANNEL_MODE Price_Channel_Mode = PCHANNEL_HIGH_LOW;
input ENUM_NINJA_TRADEMODE OrderTradeMode = NJNTRADE_BUYANDSELL;

input double Lots = 1.0;
input double TakeProfit = 40;
input double StopLoss = 25;

input int TrailingStop_Profit = 15;
input double TrailingStop_Percent = 10;

input bool  UseTimeFilter = false;
input int   StartHour = 12;                    
input int   EndHour = 14;     

      int   GMTUsed = 0,
            GMTDesired = 0;                 
            
input ENUM_TIMEFILTER_TRADEMODE NumberTradeMode = TFILTER_MULTIPLE;
input ENUM_TIMEFILTER_ACTIVATIONMODE TradeActivation = TFILTER_AM_KEEPUPDATE; 
      bool  IsFirstTradeDone = false;
      bool  WasOutofPeriod = false;

double   Current_PriceChannel_Top,
         Current_PriceChannel_Bottom;

struct OrderDetails
{
   int   TicketNumber;
   int   _OrderType;
   double   MagicNumber;
   double   _Lots;
   double   OpenPrice;
   double   StopLoss;
   double   TakeProfit;
   bool     HasComment;
   bool     TrailingStopApplied;
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

const OrderDetails defaultOrderDetails = {0, -1, 0, 0, 0, 0, 0, false, false};



// [Consecutive number of OrderGroups][Concomitent number of orders in a group]
OrderDetails SellOrder; 
OrderDetails BuyOrder;

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
   
   SellOrder = defaultOrderDetails;
   BuyOrder = defaultOrderDetails;
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
  
      UpdatePendingOrders();
      UpdateActivatedOrders();
      ParticularCase_BuyLimitCheck();
      ParticularCase_SellLimitCheck();
//---

      if (UseTimeFilter)
        {
         if (!IsAppropriateTimeFrame())
           {
            if (!WasOutofPeriod)
              {
               if (TradeActivation == TFILTER_AM_DELETECREATE) // DELETE
                 {
                  if (SellOrder._OrderType == OP_SELLLIMIT && BuyOrder._OrderType == OP_BUYLIMIT)
                    {
                     DeleteOrder(SellOrder);
                     DeleteOrder(BuyOrder);
                    }
                 }
               WasOutofPeriod = true;
              }
               
            if (IsFirstTradeDone)
               IsFirstTradeDone = false;
               
            return;
           }
         else 
           {
            if (WasOutofPeriod)
              {
               WasOutofPeriod = false;
               if(TradeActivation == TFILTER_AM_KEEPUPDATE)
                 {
                  if (SellOrder._OrderType == OP_SELLLIMIT && BuyOrder._OrderType == OP_BUYLIMIT)
                    {
                     Alert("OnTimeFilterActivation");
                     bool result = UpdateOrdersOnTimeFilterActivation();
                     if (!result)
                        WasOutofPeriod = true;
                     return;
                    }
                 }
              }
           }
        }
      //Alert("BuyOrderType ", BuyOrder._OrderType, " SellOrderType ", SellOrder._OrderType);
      
      if (SellOrder._OrderType == -1 && BuyOrder._OrderType == -1)
      {
         
         double stopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL);
         double stopLevelPoint = stopLevel * Point;

         Current_PriceChannel_Top      = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 0, 0);
         Current_PriceChannel_Bottom   = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 1, 0);

         double BuyLimit_SL = NormalizeDouble(Current_PriceChannel_Bottom - StopLoss * pips2dbl, Digits);
         double BuyLimit_TP = NormalizeDouble(Current_PriceChannel_Bottom + TakeProfit * pips2dbl, Digits);
         
         double SellLimit_SL = NormalizeDouble(Current_PriceChannel_Top + StopLoss * pips2dbl, Digits);
         double SellLimit_TP = NormalizeDouble(Current_PriceChannel_Top - TakeProfit * pips2dbl, Digits);

         // 
        {
         bool BuyLimit_OpenPriceCondition = (Ask - Current_PriceChannel_Bottom >= stopLevelPoint);          // BuyLimit
         bool BuyLimit_StopLossCondition = (Current_PriceChannel_Bottom - BuyLimit_SL >= stopLevelPoint);   // BuyLimit
         bool BuyLimit_TakeProfitCondition = (BuyLimit_TP - Current_PriceChannel_Bottom >= stopLevelPoint); 
   
         bool SellLimit_OpenPriceCondition = (Current_PriceChannel_Top - Bid >= stopLevelPoint);            // SellLimit
         bool SellLimit_StopLossCondition = (SellLimit_SL - Current_PriceChannel_Top >= stopLevelPoint);    // SellLimit
         bool SellLimit_TakeProfitCondition = (Current_PriceChannel_Top - SellLimit_TP >= stopLevelPoint);

         if (BuyLimit_OpenPriceCondition && BuyLimit_StopLossCondition && BuyLimit_TakeProfitCondition
          && SellLimit_OpenPriceCondition && SellLimit_StopLossCondition && SellLimit_TakeProfitCondition)
         {
          if (UseTimeFilter)
          {
           if (NumberTradeMode == TFILTER_SINGLE)
           {
            if (IsFirstTradeDone)
            {
             return;
            }
            else
            {
             bool openResult = false;
             openResult = Open_SellLimit(Current_PriceChannel_Top);
              
             if (openResult) 
             {
              openResult = Open_BuyLimit(Current_PriceChannel_Bottom);
             }
              else 
              {
               // PROBLEM HANDLING
              }
              
              if (openResult)
               IsFirstTradeDone = true;
              else
              {
               // PROBLEM HANDLING
              }
             }
            }
            else
            {
             Open_SellLimit(Current_PriceChannel_Top);
             Open_BuyLimit(Current_PriceChannel_Bottom);               
            }
           }
           else
           {
            Open_SellLimit(Current_PriceChannel_Top);
            Open_BuyLimit(Current_PriceChannel_Bottom);               
           }
         }
         else
         {
            Alert("Stop Level: "+DoubleToStr(stopLevelPoint));
            if (!SellLimit_OpenPriceCondition)
            {

               if (!(Current_PriceChannel_Top - Bid >= stopLevelPoint))
                  Alert("SellLimit Price: Price - Bid = " + DoubleToStr(NormalizeDouble(Current_PriceChannel_Top - Bid, Digits)));
            }
            
            if (!BuyLimit_OpenPriceCondition)
            {
               if (!(Ask - Current_PriceChannel_Bottom >= stopLevelPoint))
                  Alert("BuyLimit Price: Ask - Price = " + DoubleToStr(Ask - Current_PriceChannel_Bottom));
            }

            if (!SellLimit_StopLossCondition)
            {
               if (!(SellLimit_SL - Current_PriceChannel_Top >= stopLevelPoint))
               {
                  Alert("SellLimit StopLoss = " + DoubleToStr(SellLimit_SL));
                  Alert("SellLimit StopLoss: StopLoss - Price =" + DoubleToStr(SellLimit_SL - Current_PriceChannel_Top));
               }
           }
           
           if (!BuyLimit_StopLossCondition)
           {
               if (!(Current_PriceChannel_Bottom - BuyLimit_SL>= stopLevelPoint))
               {
                  Alert("BuyLimit StopLoss = " + DoubleToStr(BuyLimit_SL));
                  Alert("BuyLimit StopLoss: Price - StopLoss =" + DoubleToStr(NormalizeDouble(Current_PriceChannel_Bottom - BuyLimit_SL , Digits)));
               }
            }
            
            if (!SellLimit_TakeProfitCondition)
            {
               if (! (Current_PriceChannel_Top - SellLimit_TP >= stopLevelPoint))
               {
                  Alert("SellLimit TakeProfit = " + DoubleToStr(SellLimit_TP));
                  Alert("SellLimit TakeProfit: Price - TakeProfit =" + DoubleToStr(Current_PriceChannel_Top - SellLimit_TP));
               }
            }
            
            if (!BuyLimit_TakeProfitCondition)
            {   
               if (!(BuyLimit_TP - Current_PriceChannel_Bottom>= stopLevelPoint))
               {
                  Alert("BuyLimit TakeProfit = " + DoubleToStr(BuyLimit_TP));
                  Alert("BuyLimit TakeProfit: TakeProfit - Price =" + DoubleToStr((BuyLimit_TP - Current_PriceChannel_Bottom)));
               }
            }
         }
        }
      }
  }
//+------------------------------------------------------------------+

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
   
   return (StartHour <= TimeHour(CurrentDate) && TimeHour(CurrentDate) < EndHour);
   
}

bool Open_BuyLimit(double price)
{
   bool result = false;
   if (OrderTradeMode == NJNTRADE_BUYANDSELL || OrderTradeMode == NJNTRADE_ONLYBUY)
     {
      result = OpenBuyLimitOrder(price, StopLoss, TakeProfit);
     }
   else
      result = true;
   
   return result;
}

bool Open_SellLimit(double price)
{
   bool result = false;
   if (OrderTradeMode == NJNTRADE_BUYANDSELL || OrderTradeMode == NJNTRADE_ONLYSELL)
     {
      result = OpenSellLimitOrder(price, StopLoss, TakeProfit);
     }
   else
      result = true;
   
   return result;
}


void UpdatePendingOrders()
{
   bool  buyFound    = false,
         sellFound   = false;
   int TicketNumber  = 0;
   
   // --------------------------------------------------------------
   // Buy Pending Order Update
   // --------------------------------------------------------------   
   if (OrderTradeMode == NJNTRADE_BUYANDSELL || OrderTradeMode == NJNTRADE_ONLYBUY)
   {
    TicketNumber = BuyOrder.TicketNumber;
    
    if (BuyOrder._OrderType == OP_BUYLIMIT)
    {
       if (TicketNumber != 0)
       {
          for(int i = 0; i < OrdersTotal(); i++)
          {
             if ((OrderSelect(i, SELECT_BY_POS) == true) && (OrderSymbol()==Symbol()))
             {
                if (OrderTicket() == TicketNumber) // Same Ticket
                {
                   buyFound = true;
                   break;
                }
             }
          }
 
          if (buyFound == false)  // No Order Found
          {
             // Order is activated and closed already (take profit or stop loss)
             BuyOrder = defaultOrderDetails;
          }
          else // Order found
          {
             if (OrderType() == OP_BUY)                // Order has been activated
             {
                BuyOrder._OrderType = OP_BUY;          //Change the OrderType
                if (OrderTradeMode == NJNTRADE_BUYANDSELL)
                {
                 bool result = DeleteOrder(SellOrder);  // Delete Sell Limit
                 if (result)
                   {
                    SellOrder = defaultOrderDetails;
                   }
                }
             }
          }
       }
    }
   }
   else
    buyFound = true;
   // --------------------------------------------------------------
   // Sell Pending Order Update
   // --------------------------------------------------------------
   sellFound = false;
   if (OrderTradeMode == NJNTRADE_BUYANDSELL || OrderTradeMode == NJNTRADE_ONLYSELL)
   {
    TicketNumber = SellOrder.TicketNumber;
    
    if (SellOrder._OrderType == OP_SELLLIMIT)
    {
       if (TicketNumber != 0)
       {
          for(int i = 0; i < OrdersTotal(); i++)
          {
             if ((OrderSelect(i, SELECT_BY_POS) == true) && (OrderSymbol()==Symbol()))
             {
                if (OrderTicket() == TicketNumber) // Same Ticket
                {
                   sellFound = true;
                   break;
                }
             }
          }
           
          if (sellFound == false)  // No Order Found
          {
             // Order is activated and closed already (take profit or stop loss)
             SellOrder = defaultOrderDetails;
          }
          else // Order found
          {
             if (OrderType() == OP_SELL)                  // Order has been activated
             {
              SellOrder._OrderType = OP_SELL;           //Change the OrderType
              if (OrderTradeMode == NJNTRADE_BUYANDSELL)
              {
               bool result = DeleteOrder(BuyOrder);      // Delete Buy Limit
               if (result)
               {
                BuyOrder = defaultOrderDetails;
               }
              }
             }
          }
       }
    }
   }
   else
    sellFound = true;
   
   if (sellFound && SellOrder._OrderType == OP_SELLLIMIT)
   {
      if ((UseTimeFilter && IsAppropriateTimeFrame()) || (!UseTimeFilter))
      {
         bool  canUpdateSell           ,
               sellLimitConditionPrice      ,
               sellLimitConditionStopLoss   ,
               sellLimitConditionTakeProfit ;
               
         canUpdateSell = sellLimitConditionPrice = sellLimitConditionStopLoss = sellLimitConditionTakeProfit = false;
   
         double stopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL);
         double stopLevelPoint = stopLevel * Point;
         
         Current_PriceChannel_Top      = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 0, 0);
         Current_PriceChannel_Bottom   = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 1, 0);
      
         double SellLimit_SL = NormalizeDouble(Current_PriceChannel_Top + StopLoss * pips2dbl, Digits);
         double SellLimit_TP = NormalizeDouble(Current_PriceChannel_Top - TakeProfit * pips2dbl, Digits);
         
         // 
         
         sellLimitConditionPrice = (Current_PriceChannel_Top - Bid)>= stopLevelPoint;
         sellLimitConditionStopLoss = (SellLimit_SL - Current_PriceChannel_Top >= stopLevelPoint);
         sellLimitConditionTakeProfit = (Current_PriceChannel_Top - SellLimit_TP >= stopLevelPoint);

         if (sellLimitConditionPrice && sellLimitConditionStopLoss && sellLimitConditionTakeProfit)
         {
          if (SellOrder.OpenPrice != Current_PriceChannel_Top)
          {
           Alert("Pending Orders Sell Limit stop price adjustment");
           ModifySellLimitOrder(SellOrder.TicketNumber, Current_PriceChannel_Top, StopLoss, TakeProfit);
          }
         }
      }
   }
   
   if (buyFound && BuyOrder._OrderType == OP_BUYLIMIT)
   {
    //Alert(" BuyOrder._OrderType ", BuyOrder._OrderType);
    if ((UseTimeFilter && IsAppropriateTimeFrame()) || (!UseTimeFilter))
      {
         bool  canUpdateBuy            ,
               buyLimitConditionPrice       ,
               buyLimitConditionStopLoss    ,
               buyLimitConditionTakeProfit  ;
               
         canUpdateBuy = buyLimitConditionPrice = buyLimitConditionStopLoss = buyLimitConditionTakeProfit = false;
   
         double stopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL);
         double stopLevelPoint = stopLevel * Point;
         
         Current_PriceChannel_Top      = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 0, 0);
         Current_PriceChannel_Bottom   = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 1, 0);
      
         double BuyLimit_SL = NormalizeDouble(Current_PriceChannel_Bottom - StopLoss * pips2dbl, Digits);
         double BuyLimit_TP = NormalizeDouble(Current_PriceChannel_Bottom + TakeProfit* pips2dbl, Digits);
         
         // 
         buyLimitConditionPrice = (Ask - Current_PriceChannel_Bottom) >= stopLevelPoint;
         buyLimitConditionStopLoss = (Current_PriceChannel_Bottom - BuyLimit_SL >= stopLevelPoint);
         buyLimitConditionTakeProfit = (BuyLimit_TP - Current_PriceChannel_Bottom >= stopLevelPoint);

         if (buyLimitConditionPrice && buyLimitConditionStopLoss && buyLimitConditionTakeProfit)
         {
          if (BuyOrder.OpenPrice != Current_PriceChannel_Bottom)
          {
           Alert("Pending Orders Buy Limit stop price adjustment");
           ModifyBuyLimitOrder(BuyOrder.TicketNumber, Current_PriceChannel_Bottom, StopLoss, TakeProfit);
          }
         }
      }    
   }
}

void UpdateActivatedOrders()
{
// Check if activated orders have been closed
// If closed and substract the needed amount
// from the total number of orders
// If the order is still opened check for the
// Trailing Stop conditions and modify if appropriately

   bool found = false;
   
   // --------------------------------------------------------------
   // Buy Order Update
   // --------------------------------------------------------------
   
   int TicketNumber = BuyOrder.TicketNumber;
   
   if (BuyOrder._OrderType == OP_BUY)
   {
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
         if (found == false)  // No Order Found
         {
            // Order is closed already (take profit or stop loss)
            BuyOrder = defaultOrderDetails;
         }
         else // Order found
           {
            if (Bid - OrderOpenPrice() > TrailingStop_Profit * Point)
            //if(OrderProfit()/MarketInfo(Symbol(),MODE_TICKVALUE)/OrderLots()*Point > TrailingStop_Profit *Point)
              {
               if(OrderType() == OP_BUY)
                 {
                  double newSL = NormalizeDouble(OrderOpenPrice()+((Bid-OrderOpenPrice())*(TrailingStop_Percent/100.0)),Digits);
                  if(OrderStopLoss() < newSL || OrderStopLoss() == 0.00000)
                    {
                     ModifyBuyOrderStopLoss(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit()); 
                    }
                 }
              }           
           }
      }
   }   
   
   found = false;
   
   // --------------------------------------------------------------
   // Sell Order Update
   // --------------------------------------------------------------
   TicketNumber = SellOrder.TicketNumber;
   
   if (SellOrder._OrderType == OP_SELL)
   {
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
         
         if (found == false)  // No Order Found
         {
            // Order is activated and closed already (take profit or stop loss)
            SellOrder = defaultOrderDetails;
         }
         else // Order found
         {
            if(OrderOpenPrice() - Ask > TrailingStop_Profit * Point)
            //if(OrderProfit()/MarketInfo(Symbol(),MODE_TICKVALUE)/OrderLots()*Point > TrailingStop_Profit *Point)
              {
               if(OrderType() == OP_SELL)
                 {
                  double newSL = NormalizeDouble(OrderOpenPrice()-((OrderOpenPrice()-Ask)*(TrailingStop_Percent/100.0)), Digits);
                  if(OrderStopLoss() > newSL || OrderStopLoss() == 0.00000)
                    {
                     ModifySellOrderStopLoss(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit());
                    }
                 }
              }           

         }
      }
   }
}

bool ParticularCase_BuyLimitCheck()
{

 Current_PriceChannel_Top      = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 0, 0);
 Current_PriceChannel_Bottom   = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 1, 0);

 if ((Bid == Current_PriceChannel_Bottom)
  && (BuyOrder._OrderType == OP_BUYLIMIT))
 {
  // Close BuyLimitOrder
  DeleteOrder(BuyOrder);
  // Open BuyOrder
  OpenBuyOrder(StopLoss, TakeProfit);
 }
 
 return true;
}

bool ParticularCase_SellLimitCheck()
{

 Current_PriceChannel_Top      = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 0, 0);
 Current_PriceChannel_Bottom   = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 1, 0);

 if ((Ask == Current_PriceChannel_Top)
  && (SellOrder._OrderType == OP_SELLLIMIT))
 {
  // Close BuyLimitOrder
  DeleteOrder(SellOrder);
  // Open BuyOrder
  OpenSellOrder(StopLoss, TakeProfit);
 }
 
 return true;
}

bool UpdateOrdersOnTimeFilterActivation()
{
   
   double stopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL);
   double stopLevelPoint = stopLevel * Point;
   

   Current_PriceChannel_Top      = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 0, 0);
   Current_PriceChannel_Bottom   = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 1, 0);

   double BuyLimit_SL = NormalizeDouble(Current_PriceChannel_Bottom - StopLoss * pips2dbl, Digits);
   double BuyLimit_TP = NormalizeDouble(Current_PriceChannel_Bottom + TakeProfit * pips2dbl, Digits);

   double SellLimit_SL = NormalizeDouble(Current_PriceChannel_Top + StopLoss * pips2dbl, Digits);
   double SellLimit_TP = NormalizeDouble(Current_PriceChannel_Top - TakeProfit * pips2dbl, Digits);
   
   // 
   bool OpenPriceCondition;
   bool response = false;
   
    OpenPriceCondition = (Ask - Current_PriceChannel_Top>= stopLevelPoint)
     && (Current_PriceChannel_Bottom - Bid >= stopLevelPoint);
     
    if (OpenPriceCondition)
    {
      if (SellOrder.OpenPrice != Current_PriceChannel_Top)
         response = ModifySellLimitOrder(SellOrder.TicketNumber, Current_PriceChannel_Top, StopLoss, TakeProfit);
      else 
         response = true;
         
      if (response && (BuyOrder.OpenPrice != Current_PriceChannel_Bottom))
         response = ModifyBuyLimitOrder(BuyOrder.TicketNumber, Current_PriceChannel_Bottom, StopLoss, TakeProfit);
    }

   return response;
}


bool DeleteOrder(OrderDetails& details)
{
   bool        result = false;
   
      Alert(
      "DeletePendingOrder \n",
      "Ticket : ", details.TicketNumber, "\n");               

   while (true)
   {
      
      bool response = OrderDelete(details.TicketNumber);
      
      if (response)
      {
         result = true;
         break;
      }
        
      int Error = GetLastError();
      
      switch(Error)                             // Overcomable errors
        {
         case  4: Alert("Trade server is busy. Retrying..");
            Sleep(3000);                        // Simple solution
            continue;                           // At the next iteration
         case 137:Alert("Broker is busy. Retrying..");
            Sleep(3000);                        // Simple solution
            continue;                           // At the next iteration
         case 146:Alert("Trading subsystem is busy. Retrying..");
            Sleep(500);                         // Simple solution
            continue;                           // At the next iteration
        }
      switch(Error)                             // Critical errors
        {
         case 2 : Alert("Common error.");
            break;                              // Exit 'switch'
         case 64: Alert("Account is blocked.");
            break;                              // Exit 'switch'
         case 133:Alert("Trading is prohibited");
            break;                              // Exit 'switch'
         case 139:Alert("The order is blocked and is being processed");
            break;                              // Exit 'switch'
         case 145:Alert("Modification is prohibited. ",
                              "The order is too close to the market");
            break;                              // Exit 'switch'
         default: Alert("Occurred error ",Error);//Other alternatives   
        }
     break;
   }
   
   return (result);
}


bool ModifyBuyOrderStopLoss(int Ticket, double Price, double _StopLoss, double _TakeProfit)
{
   bool        result = false,
               useMargin = false;
   
   double      Margin = 0;

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
   
   double      Margin = 0;

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

bool OpenBuyLimitOrder(double Price, double _StopLoss, double _TakeProfit)
{
   int         Ticket = 0,
               Slippage = 3,
               stopLevel = -1,
               MagicNumber;

   double      SL = 0,
               TP = 0;

   string      Symb;
   
   bool        result = false,
               checkStopLevels = false;

   while (true)
   {
      Symb = Symbol();
      MagicNumber = TimeCurrent();
      
      RefreshRates();
      
      if (checkStopLevels)
      {
         stopLevel = MarketInfo(Symb,MODE_STOPLEVEL);   // Minimal permissible StopLoss/TakeProfit value in points.

         if (stopLevel > _StopLoss) {
            SL = NormalizeDouble(Price - stopLevel * pips2dbl, Digits);
         }
         else
         {
            SL = NormalizeDouble(Price - _StopLoss * pips2dbl, Digits);
         }
   
         if (stopLevel > _TakeProfit)
         {
            TP = NormalizeDouble(Price + stopLevel * pips2dbl, Digits);
         }
         else
         {
            TP = NormalizeDouble(Price + _TakeProfit * pips2dbl, Digits);
         }
      }
      else
      {
            SL = NormalizeDouble(Price - _StopLoss * pips2dbl, Digits);
            TP = NormalizeDouble(Price + _TakeProfit * pips2dbl, Digits);
      }
      
         Ticket=OrderSend(
            Symb,             // int         Symbol
            OP_BUYLIMIT,           // int         CMD
            Lots,             // double      Volume
            Price,              // double      Price
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
            Alert("BuyLimit Error"); 
            Alert(" StopLevel: ", stopLevel, " Ask: ", Ask, " Bid: ", Bid, " Digits: ", Digits);
            
            Alert(" Price - Ask: ", NormalizeDouble(Price - Ask, Digits),
               " Price - StopLoss: ", NormalizeDouble(Price - SL, Digits),
               " TakeProfit - Price: ", NormalizeDouble(TP - Price, Digits)
               );
               
         Alert
         (
            
            " Symb: ",             Symb,             // int         Symbol
            " CMD: ",              OP_BUYSTOP,       // int         CMD
            " Volume: ",           Lots,             // double      Volume
            " Price: ",            Bid,              // double      Price
            " Slippage: ",         Slippage,         // int         Slippage
            " StopLoss: ",         SL,               // double      StopLoss
            " TakeProfit: ",       TP,               // double      TakeProfit
            " Comment: ",          "",               // string      Comment           = NULL
            " MagicNumber: ",      MagicNumber,      // int         MagicNumber       = 0
            " ExpirationTime: ",   0,                // datetime    ExpirationTime    = 0
            " Arrow_Color: ",      Green,             // color       Arrow_Color       = CLR_NONE
            " Point: ",            0.0 + Point
         );             
            int errorValue = GetLastError();                                              // Check for errors:
            if(ProcessErrors(errorValue)==false)     // If the error is critical,
            {
               result = false;
               break;      // Non Overcomable Error
            }
            else
            {
               if (errorValue == 130)
                  checkStopLevels = true;
               continue;   // Overcomable Error
            }                           
         }
         
         OrderDetails details = defaultOrderDetails;
         
         // Ticket Processed
         details.TicketNumber          = Ticket;      // Order number
         details._OrderType            =OP_BUYLIMIT;       // Order type
         details.MagicNumber           =MagicNumber;  // Magic number 
         details._Lots                 =Lots;         // Amount of lots
         details.OpenPrice             =Price;          // Order open price
         details.StopLoss              =SL;           // SL price
         details.TakeProfit            =TP;           // TP price 
         details.HasComment            = false;       // If there is no comment
         details.TrailingStopApplied   = false;       // Has Stop Profit Applied
         
         BuyOrder = details;


         result = true;
         break;
      }
   return (result);
}

bool OpenSellLimitOrder(double Price, double _StopLoss, double _TakeProfit)
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

         if (Margin > _StopLoss) {
            StopLossMargin = Margin;
         }
         else
         {
            StopLossMargin = _StopLoss;
         }

         if (Margin > _TakeProfit)
         {
            TakeProfitMargin = Margin;
         }
         else
         {
            TakeProfitMargin = _TakeProfit;
         }
      }
      else
      {
         StopLossMargin = _StopLoss;
         TakeProfitMargin = _TakeProfit;
      }
      
      SL = NormalizeDouble(Price + StopLossMargin * pips2dbl, Digits);
      TP = NormalizeDouble(Price - TakeProfitMargin * pips2dbl, Digits);
      
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
            OP_SELLLIMIT,      // int         CMD
            Lots,             // double      Volume
            Price,            // double      Price
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
                     
            Alert("Sell error");                          // Check for errors:
         Alert
         (
            
            " Symb: ",             Symb,             // int         Symbol
            " CMD: ",              OP_SELLLIMIT,       // int         CMD
            " Volume: ",           Lots,             // double      Volume
            " Price: ",            Price,              // double      Price
            " Slippage: ",         Slippage,         // int         Slippage
            " StopLoss: ",         SL,               // double      StopLoss
            " TakeProfit: ",       TP,               // double      TakeProfit
            " Comment: ",          "",               // string      Comment           = NULL
            " MagicNumber: ",      MagicNumber,      // int         MagicNumber       = 0
            " ExpirationTime: ",   0,                // datetime    ExpirationTime    = 0
            " Arrow_Color: ",      Green,             // color       Arrow_Color       = CLR_NONE
            " Point: ",            0.0 + Point
         );  
                     
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
         OrderDetails details = defaultOrderDetails;
         
         details.TicketNumber          = Ticket;      // Order number
         details._OrderType            =OP_SELLLIMIT;      // Order type
         details.MagicNumber           =MagicNumber;  // Magic number 
         details._Lots                 =Lots;         // Amount of lots
         details.OpenPrice             =Price;          // Order open price
         details.StopLoss              =SL;           // SL price
         details.TakeProfit            =TP;           // TP price 
         details.HasComment            = false;       // If there is no comment
         details.TrailingStopApplied   = false;       // Has Stop Profit Applied
         
         SellOrder = details;
    
         result = true;
         break;
      }
      
   return (result);
}

bool ModifyBuyLimitOrder(int Ticket, double Price, double _StopLoss, double _TakeProfit)
{
   bool        result = false,
               checkStopLevels = false;
   
   double      stopLevel = 0;

   double      SL = 0,
               TP = 0,
               StopLossMargin = 0,
               TakeProfitMargin = 0;
               
   string      Symb;
   

   while (true)
     {
      Symb = Symbol();

      if (checkStopLevels)
        {
         stopLevel = MarketInfo(Symb,MODE_STOPLEVEL);   // Minimal permissible StopLoss/TakeProfit value in points.

         if (stopLevel > _StopLoss)
           {
            SL = NormalizeDouble(Price - stopLevel * pips2dbl, Digits);
           }
         else
           {
            SL = NormalizeDouble(Price - _StopLoss * pips2dbl, Digits);
           }
   
         if (stopLevel > _TakeProfit)
           {
            TP = NormalizeDouble(Price + stopLevel * pips2dbl, Digits);
           }
         else
           {
            TP = NormalizeDouble(Price + _TakeProfit * pips2dbl, Digits);
           }
        }
      else
        {
         SL = NormalizeDouble(Price - _StopLoss * pips2dbl, Digits);
         TP = NormalizeDouble(Price + _TakeProfit * pips2dbl, Digits);
        }
      
      bool response = OrderModify(Ticket, Price, SL, TP, 0);
      
      if (response == true)
        {
        
         BuyOrder.OpenPrice = Price;
         BuyOrder.StopLoss = SL;
         BuyOrder.TakeProfit = TP;
       
         result = true;
         break;
        }
      
      int Error = GetLastError();
      
      switch(Error)                       // Overcomable errors
        {
         case 130:
            //Alert("Wrong stops. Retrying.");
            RefreshRates();               // Update data
            checkStopLevels = true;
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


bool ModifySellLimitOrder(int Ticket, double Price, double _StopLoss, double _TakeProfit)
{
   bool        result = false,
               useMargin = false;
   
   double      Margin = 0;

   double      SL = 0,
               TP = 0,
               StopLossMargin = 0,
               TakeProfitMargin = 0;

   while (true)
   {
      if (useMargin)
      {   
         Margin = MarketInfo(Symbol(),MODE_STOPLEVEL );// Last known
   
         RefreshRates();

         if (Margin > _StopLoss) {
            StopLossMargin = Margin;
         }
         else
         {
            StopLossMargin = _StopLoss;
         }

         if (Margin > _TakeProfit)
         {
            TakeProfitMargin = Margin;
         }
         else
         {
            TakeProfitMargin = _TakeProfit;
         }
      }
      else
      {
         StopLossMargin = _StopLoss;
         TakeProfitMargin = _TakeProfit;
      }
      
      SL = NormalizeDouble(Price + StopLossMargin * pips2dbl, Digits);
      TP = NormalizeDouble(Price - TakeProfitMargin * pips2dbl, Digits);
      
      bool response = OrderModify(Ticket, Price, SL, TP, 0);
      
      if (response)
      {
         SellOrder.OpenPrice = Price;
         SellOrder.StopLoss = SL;
         SellOrder.TakeProfit = TP;
         
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

bool OpenBuyOrder(double _StopLoss, double _TakeProfit)
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
      NormalizeDouble(Ask + _TakeProfit * pips2dbl, Digits));
          
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
         OrderDetails details = defaultOrderDetails;
         
         // Ticket Processed
         details.TicketNumber          = Ticket;      // Order number
         details._OrderType            =OP_BUYSTOP;   // Order type
         details.MagicNumber           =MagicNumber;  // Magic number 
         details._Lots                 =Lots;         // Amount of lots
         details.OpenPrice             =Ask;          // Order open price
         details.StopLoss              =SL;           // SL price
         details.TakeProfit            =TP;           // TP price 
         details.HasComment            = false;       // If there is no comment
         details.TrailingStopApplied   = false;       // Has Stop Profit Applied
         
         BuyOrder = details;

         result = true;
         break;
      }
   return (result);
}


bool OpenSellOrder(double _StopLoss, double _TakeProfit)
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
         
            // Ticket Processed
         OrderDetails details = defaultOrderDetails;
         
         // Ticket Processed
         details.TicketNumber          = Ticket;       // Order number
         details._OrderType            = OP_SELLSTOP;  // Order type
         details.MagicNumber           = MagicNumber;  // Magic number 
         details._Lots                 = Lots;         // Amount of lots
         details.OpenPrice             = Bid;          // Order open price
         details.StopLoss              = SL;           // SL price
         details.TakeProfit            = TP;           // TP price 
         details.HasComment            = false;        // If there is no comment
         details.TrailingStopApplied   = false;        // Has Stop Profit Applied
         
         BuyOrder = details;
    
         result = true;
         break;
      }
      
   return (result);
}