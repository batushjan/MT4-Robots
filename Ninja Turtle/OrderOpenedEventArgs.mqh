//+------------------------------------------------------------------+
//|                                         OrderOpenedEventArgs.mqh |
//|                                            Copyright 2015, Didbl |
//|                                            https://www.didbl.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, Didbl"
#property link      "https://www.didbl.com"
#property version   "1.00"
#property strict

#include "EventArgs.mqh"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class OrderOpenedEventArgs : public EventArgs
  {
private:

public:
                     OrderOpenedEventArgs();
                    ~OrderOpenedEventArgs();
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
OrderOpenedEventArgs::OrderOpenedEventArgs()
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
OrderOpenedEventArgs::~OrderOpenedEventArgs()
  {
  }
//+------------------------------------------------------------------+
