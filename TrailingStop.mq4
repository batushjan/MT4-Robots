//+------------------------------------------------------------------+
//|                                                  TralingStop.mq4 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""

extern int profit = 100;
extern double percent = 70.0;

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
//----
   
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----
   
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
  {
//----
   int totalOrders = OrdersTotal();
   int i = 0;
   double p = 0.0;
   for(i=0; i<totalOrders; i++){
      OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
      if(OrderSymbol() == Symbol()){
         if(OrderProfit()/MarketInfo(Symbol(),MODE_TICKVALUE)/OrderLots()*Point > profit*Point){
            if(OrderType() == OP_BUY){
               if(OrderStopLoss() < (OrderOpenPrice()+((Bid-OrderOpenPrice())*(percent/100.0))) || OrderStopLoss() == 0.00000){
                  OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice()+((Bid-OrderOpenPrice())*(percent/100.0)),OrderTakeProfit(),0,CLR_NONE);
               }
            }
            if(OrderType() == OP_SELL){
               if(OrderStopLoss() > (OrderOpenPrice()-((OrderOpenPrice()-Ask)*(percent/100.0))) || OrderStopLoss() == 0.00000){
                  OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice()-((OrderOpenPrice()-Ask)*(percent/100.0)),OrderTakeProfit(),0,CLR_NONE);
               }
            }
         }
      }
   }
//----
   return(0);
  }
//+------------------------------------------------------------------+