//+------------------------------------------------------------------+
//|                                        OrderOpeningEventArgs.mqh |
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
class OrderOpeningEventArgs : public EventArgs
  {
private:
public:
   bool Cancel;
                     OrderOpeningEventArgs();
                    ~OrderOpeningEventArgs();
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
OrderOpeningEventArgs::OrderOpeningEventArgs()
  {
   Cancel = false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
OrderOpeningEventArgs::~OrderOpeningEventArgs()
  {
  }
//+------------------------------------------------------------------+
