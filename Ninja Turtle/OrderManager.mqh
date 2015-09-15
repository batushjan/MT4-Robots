//+------------------------------------------------------------------+
//|                                                 OrderManager.mqh |
//|                                            Copyright 2015, Didbl |
//|                                            https://www.didbl.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, Didbl"
#property link      "https://www.didbl.com"
#property version   "1.00"
#property strict

#include "OrderOpeningEventArgs.mqh"
#include "OrderOpenedEventArgs.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class OrderManager
  {
private:
public:
                     OrderManager();
                    ~OrderManager();
      void           OrderOpen();
      virtual void  OnOrderOpening(OrderOpeningEventArgs& e) {};
      virtual void  OnOrderOpened(OrderOpenedEventArgs& e) {};
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
OrderManager::OrderManager()
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
OrderManager::~OrderManager()
  {
  }
//+------------------------------------------------------------------+
OrderManager::OrderOpen()
{
 OrderOpeningEventArgs openingArgs();
 this.OnOrderOpening(openingArgs);
 
 OrderOpenedEventArgs openedArgs();
 this.OnOrderOpened(openedArgs);  
   
}

OrderManager:OrderOpenBuyOrder()
{
 
}

OrderManager:OrderOpenBuyStopOrder()
{

}

OrderManager:OrderOpenBuyLimitOrder()
{

}

