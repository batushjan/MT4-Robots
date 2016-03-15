//+------------------------------------------------------------------+
//|                                                  NinjaTurtle.mq4 |
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

input bool UseSecondPriceChannnel = false;
input int Second_Price_Channel_Period = 20;
input ENUM_PRICE_CHANNEL_MODE Second_Price_Channel_Mode = PCHANNEL_HIGH_LOW;

input bool EnforceMinimalPriceChannelHeight = false;
input double MinimalPriceChannelHeight = 10.00;

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
//---

      if (UseTimeFilter)
        {
         if (!IsAppropriateTimeFrame())
           {
            if (!WasOutofPeriod)
              {
               if (TradeActivation == TFILTER_AM_DELETECREATE) // DELETE
                 {
                  if (SellOrder._OrderType == OP_SELLSTOP && BuyOrder._OrderType == OP_BUYSTOP)
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
                  if (SellOrder._OrderType == OP_BUYSTOP && BuyOrder._OrderType == OP_SELLSTOP)
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
         
         if (UseSecondPriceChannnel)
         {
          Current_PriceChannel_Bottom   = iCustom(NULL, 0, "PriceChannel", Second_Price_Channel_Period, Second_Price_Channel_Mode, 1, 0);
         }
         else 
         {
          Current_PriceChannel_Bottom   = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 1, 0);
         }

         double BuyStop_SL = NormalizeDouble(Current_PriceChannel_Top - StopLoss * pips2dbl, Digits);
         double BuyStop_TP = NormalizeDouble(Current_PriceChannel_Top + TakeProfit * pips2dbl, Digits);

         double SellStop_SL = NormalizeDouble(Current_PriceChannel_Bottom + StopLoss * pips2dbl, Digits);
         double SellStop_TP = NormalizeDouble(Current_PriceChannel_Bottom - TakeProfit * pips2dbl, Digits);
         
         double PriceChannelHeight = NormalizeDouble(MathAbs(Current_PriceChannel_Top - Current_PriceChannel_Bottom), Digits);
         

         // 
         bool  OpenPriceCondition,
               StopLossCondition,
               TakeProfitCondition;

          OpenPriceCondition = (Current_PriceChannel_Top - Ask >= stopLevelPoint)
             && (Bid - Current_PriceChannel_Bottom>= stopLevelPoint);
             
          StopLossCondition = (Current_PriceChannel_Top - BuyStop_SL >= stopLevelPoint)
             && (SellStop_SL - Current_PriceChannel_Bottom >= stopLevelPoint);
             
          TakeProfitCondition = (BuyStop_TP - Current_PriceChannel_Top >= stopLevelPoint)
             && (Current_PriceChannel_Bottom - SellStop_TP >= stopLevelPoint);

          if (EnforceMinimalPriceChannelHeight && (NormalizeDouble(MinimalPriceChannelHeight * pips2dbl, Digits) > PriceChannelHeight))
          {
           return;
          }

          if (OpenPriceCondition && StopLossCondition && TakeProfitCondition)
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
              openResult = Open_BuyStop(Current_PriceChannel_Top);
              
              if (openResult) 
              {
               openResult = Open_SellStop(Current_PriceChannel_Bottom);
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
             Open_BuyStop(Current_PriceChannel_Top);
             Open_SellStop(Current_PriceChannel_Bottom);               
            }
           }
           else
           {
            Open_BuyStop(Current_PriceChannel_Top);
            Open_SellStop(Current_PriceChannel_Bottom);
           }
         }
         else
         {
            Alert("Stop Level: "+DoubleToStr(stopLevelPoint));
            if (!OpenPriceCondition)
            {
               if (!(Current_PriceChannel_Top - Ask >= stopLevelPoint))
                  Alert("BuyStop Price: Price - Ask = " + DoubleToStr(NormalizeDouble(Current_PriceChannel_Top - Ask, Digits)));

               if (!(Bid - Current_PriceChannel_Bottom >= stopLevelPoint))
                  Alert("SellStop Price: Bid - Price = " + DoubleToStr(Bid - Current_PriceChannel_Bottom));
            }
            
            if (!StopLossCondition)
            {
               if (!(Current_PriceChannel_Top - BuyStop_SL >= stopLevelPoint))
               {
                  Alert("BuyStop StopLoss = " + DoubleToStr(BuyStop_SL));
                  Alert("BuyStop StopLoss: Price - StopLoss =" + DoubleToStr(Current_PriceChannel_Top - BuyStop_SL));
               }
               
               if (!(SellStop_SL - Current_PriceChannel_Bottom >= stopLevelPoint))
               {
                  Alert("SellStop StopLoss = " + DoubleToStr(SellStop_SL));
                  Alert("SellStop StopLoss: StopLoss - Price =" + DoubleToStr(NormalizeDouble(SellStop_SL - Current_PriceChannel_Bottom, Digits)));
               }
            }
            
            if (!TakeProfitCondition)
            {
               if (! (BuyStop_TP - Current_PriceChannel_Top >= stopLevelPoint))
               {
                  Alert("BuyStop TakeProfit = " + DoubleToStr(BuyStop_TP));
                  Alert("BuyStop TakeProfit: TakeProfit - Price =" + DoubleToStr(BuyStop_TP - Current_PriceChannel_Top));
               }
               
               if (!(Current_PriceChannel_Bottom - SellStop_TP >= stopLevelPoint))
               {
                  Alert("SellStop TakeProfit = " + DoubleToStr(SellStop_TP));
                  Alert("SellStop TakeProfit: Price - TakeProfit =" + DoubleToStr(Current_PriceChannel_Bottom - SellStop_TP));
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

bool Open_BuyStop(double price)
{
   bool result = false;
   if (OrderTradeMode == NJNTRADE_BUYANDSELL || OrderTradeMode == NJNTRADE_ONLYBUY)
     {
      result = OpenBuyStopOrder(price, StopLoss, TakeProfit);
     }
   else
      result = true;
   
   return result;
}

bool Open_SellStop(double price)
{
   bool result = false;
   if (OrderTradeMode == NJNTRADE_BUYANDSELL || OrderTradeMode == NJNTRADE_ONLYSELL)
     {
      result = OpenSellStopOrder(price, StopLoss, TakeProfit);
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
    
    if (BuyOrder._OrderType == OP_BUYSTOP)
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
                 bool result = DeleteOrder(SellOrder);  // Delete Sell Stop or Sell Limit
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
    
    if (SellOrder._OrderType == OP_SELLSTOP)
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
               bool result = DeleteOrder(BuyOrder);      // Delete Buy Stop
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
   
   if (sellFound && (SellOrder._OrderType == OP_SELLSTOP))
   {
      if ((UseTimeFilter && IsAppropriateTimeFrame()) || (!UseTimeFilter))
      {
         bool  canUpdateSell           ,
               sellStopConditionPrice      ,
               sellStopConditionStopLoss   ,
               sellStopConditionTakeProfit ;
               
         canUpdateSell = sellStopConditionPrice = sellStopConditionStopLoss = sellStopConditionTakeProfit = false;
   
         double stopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL);
         double stopLevelPoint = stopLevel * Point;
         
         Current_PriceChannel_Top      = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 0, 0);
         if (UseSecondPriceChannnel)
         {
          Current_PriceChannel_Bottom   = iCustom(NULL, 0, "PriceChannel", Second_Price_Channel_Period, Second_Price_Channel_Mode, 1, 0);
         }
         else
         {
          Current_PriceChannel_Bottom   = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 1, 0);
         }
      
         double SellStop_SL = NormalizeDouble(Current_PriceChannel_Bottom + StopLoss * pips2dbl, Digits);
         double SellStop_TP = NormalizeDouble(Current_PriceChannel_Bottom - TakeProfit * pips2dbl, Digits);

         // 
         sellStopConditionPrice = (Bid - Current_PriceChannel_Bottom)>= stopLevelPoint;
         sellStopConditionStopLoss = (SellStop_SL - Current_PriceChannel_Bottom >= stopLevelPoint);
         sellStopConditionTakeProfit = (Current_PriceChannel_Bottom - SellStop_TP >= stopLevelPoint);

          if (sellStopConditionPrice && sellStopConditionStopLoss && sellStopConditionTakeProfit)
          {
           if (SellOrder.OpenPrice != Current_PriceChannel_Bottom)
           {
            Alert("Pending Orders sell stop price adjustment");
            ModifySellStopOrder(SellOrder.TicketNumber, Current_PriceChannel_Bottom, StopLoss, TakeProfit);
           }
          }
         
      }
   }
   
   if (buyFound && (BuyOrder._OrderType == OP_BUYSTOP))
   {
    //Alert(" BuyOrder._OrderType ", BuyOrder._OrderType);
    if ((UseTimeFilter && IsAppropriateTimeFrame()) || (!UseTimeFilter))
      {
         bool  canUpdateBuy            ,
               buyStopConditionPrice       ,
               buyStopConditionStopLoss    ,
               buyStopConditionTakeProfit  ;
               
         canUpdateBuy = buyStopConditionPrice = buyStopConditionStopLoss = buyStopConditionTakeProfit = false;
   
         double stopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL);
         double stopLevelPoint = stopLevel * Point;
         
         Current_PriceChannel_Top      = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 0, 0);
         if (UseSecondPriceChannnel)
         {
          Current_PriceChannel_Bottom   = iCustom(NULL, 0, "PriceChannel", Second_Price_Channel_Period, Second_Price_Channel_Mode, 1, 0);
         }
         else
         {
          Current_PriceChannel_Bottom   = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 1, 0);
         }
         
         double BuyStop_SL = NormalizeDouble(Current_PriceChannel_Top - StopLoss * pips2dbl, Digits);
         double BuyStop_TP = NormalizeDouble(Current_PriceChannel_Top + TakeProfit * pips2dbl, Digits);

         // 
         buyStopConditionPrice = (Current_PriceChannel_Top - Ask) >= stopLevelPoint;
         buyStopConditionStopLoss = (Current_PriceChannel_Top - BuyStop_SL >= stopLevelPoint);
         buyStopConditionTakeProfit = (BuyStop_TP - Current_PriceChannel_Top >= stopLevelPoint);

         
          if (buyStopConditionPrice && buyStopConditionStopLoss && buyStopConditionTakeProfit)
          {
           if (BuyOrder.OpenPrice != Current_PriceChannel_Top)
           {
            Alert("Pending Orders buy stop price adjustment");
            ModifyBuyStopOrder(BuyOrder.TicketNumber, Current_PriceChannel_Top, StopLoss, TakeProfit);
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

bool UpdateOrdersOnTimeFilterActivation()
{
   
   double stopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL);
   double stopLevelPoint = stopLevel * Point;
   

   Current_PriceChannel_Top      = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 0, 0);
   if (UseSecondPriceChannnel)
   {
    Current_PriceChannel_Bottom   = iCustom(NULL, 0, "PriceChannel", Second_Price_Channel_Period, Second_Price_Channel_Mode, 1, 0);
   }
   else
   {
    Current_PriceChannel_Bottom   = iCustom(NULL, 0, "PriceChannel", Price_Channel_Period, Price_Channel_Mode, 1, 0);
   }

   double BuyStop_SL = NormalizeDouble(Current_PriceChannel_Top - StopLoss * pips2dbl, Digits);
   double BuyStop_TP = NormalizeDouble(Current_PriceChannel_Top + TakeProfit * pips2dbl, Digits);

   double SellStop_SL = NormalizeDouble(Current_PriceChannel_Bottom + StopLoss * pips2dbl, Digits);
   double SellStop_TP = NormalizeDouble(Current_PriceChannel_Bottom - TakeProfit * pips2dbl, Digits);
  
   // 
   bool OpenPriceCondition;
   bool response = false;
   
    OpenPriceCondition = (Current_PriceChannel_Top - Ask >= stopLevelPoint)
       && (Bid - Current_PriceChannel_Bottom >= stopLevelPoint);
    if (OpenPriceCondition)
    {
     if (BuyOrder.OpenPrice != Current_PriceChannel_Top)
        response = ModifyBuyStopOrder(BuyOrder.TicketNumber, Current_PriceChannel_Top, StopLoss, TakeProfit);
     else 
        response = true;
        
     if (response && (SellOrder.OpenPrice != Current_PriceChannel_Bottom))
        response = ModifySellStopOrder(SellOrder.TicketNumber, Current_PriceChannel_Bottom, StopLoss, TakeProfit);
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

bool OpenBuyStopOrder(double Price, double _StopLoss, double _TakeProfit)
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
            OP_BUYSTOP,           // int         CMD
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
            Alert("Buy Error"); 
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
         details._OrderType            =OP_BUYSTOP;       // Order type
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

bool OpenSellStopOrder(double Price, double _StopLoss, double _TakeProfit)
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
            OP_SELLSTOP,      // int         CMD
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
            " CMD: ",              OP_SELLSTOP,       // int         CMD
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
         details._OrderType            =OP_SELLSTOP;      // Order type
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


bool ModifyBuyStopOrder(int Ticket, double Price, double _StopLoss, double _TakeProfit)
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


bool ModifySellStopOrder(int Ticket, double Price, double _StopLoss, double _TakeProfit)
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

