//+------------------------------------------------------------------+
//|                                             TradeManager 3.1.mq5 |
//|                                Copyright 2024, MalindaRasingolla |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MalindaRasingolla"
#property link      "https://www.mql5.com"
#property version   "3.10"

#include <Controls/Button.mqh>
#include <Trade/Trade.mqh>

CTrade Trade;
CPositionInfo PositionInfo;

input group "TRADE MANAGEMENT INPUTS"
input double RiskPercentage = 0.2;
input double RewardMultiplier = 1;
input bool TakeProfit = true;
input bool StopLoss = true;

input group "EQUITY PROTECTOR"
input bool EquityProtector = false;
input double EquityDrawdown = 1.0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double price_sl;
double price_st;
double price_li;

#define BUTTON_WIDTH 70
#define BUTTON_HEIGHT 30
CButton buttonBuy;
CButton buttonSell;

bool buySignal=false;
bool sellSignal=false;

double MaxDrawdown;
bool finalProfitloss = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   return(INIT_SUCCEEDED);

  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   string comment = "";
   string orderType = GetOrderType();

   handleButtons(price_sl);

   MaxDrawdown = NormalizeDouble((AccountInfoDouble(ACCOUNT_BALANCE)*RiskPercentage/100),2);
   double EquityDrawdownMax = NormalizeDouble((AccountInfoDouble(ACCOUNT_BALANCE)*EquityDrawdown/100),2);

// Executing Orders
   Buy();
   Sell();
   BuyLimit();
   SellLimit();
   BuyStop();
   SellStop();

   double profitLoss = calculateProfitLoss();

//Quity Protector
   if(profitLoss <= (-1*EquityDrawdownMax))
     {
      finalProfitloss = true;
     }
   if(finalProfitloss == true && EquityProtector == true)
     {
      CloseAllTrades();
      finalProfitloss = false;
     }

// Comment section
   comment = "✖ ️";

   if(NumOfTrades() > 0)
     {
      comment += " | Open positions : " + IntegerToString(NumOfTrades(),0,0);
      if(EquityProtector == true)
         comment +=  " | " + "Max Drawdown : " + DoubleToString(EquityDrawdownMax,2);
     }
   if(price_sl != 0)
     {
      comment += " | " + "Risk Per Trade : " + DoubleToString(MaxDrawdown,2) + " | " + "LotSize : " + DoubleToString(NormalizeDouble(CalculatePositionSize(),2),2) + " | " + "OrderType : " + GetOrderType();
     }

   if(profitLoss != 0)
      comment +=  " | " + "Balance : " + DoubleToString(NormalizeDouble(profitLoss,2),2) + "\n" + CalculateBalance();

   Comment(comment);
  }

//+------------------------------------------------------------------+
//| Chart event function                                             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == "Buy")
        {
         buySignal = true;

        }
      else
         if(sparam == "Sell")
           {
            sellSignal = true;
           }
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate the position size                                      |
//+------------------------------------------------------------------+
double CalculatePositionSize()
  {
   double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double stopLossPoints = 0;
   if(GetOrderType()=="Market")
      stopLossPoints = MathAbs(price_sl - SymbolInfoDouble(Symbol(), SYMBOL_ASK));
   if(GetOrderType()=="Limit")
      stopLossPoints = MathAbs(price_sl - price_li);
   if(GetOrderType()=="Stop")
      stopLossPoints = MathAbs(price_sl - price_st);

   if(tickSize == 0 || tickValue ==0 || lotStep == 0)
      return 0;

   double moneyLotStep = (stopLossPoints/tickSize)*tickValue*lotStep;
   if(moneyLotStep == 0)
      return 0;

   double lots = MathFloor(MaxDrawdown/moneyLotStep)*lotStep;
   if(_Symbol=="XAUUSD")
      lots=MathFloor(MaxDrawdown/(moneyLotStep*100))*lotStep;

   return lots;

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Position Profit                                        |
//+------------------------------------------------------------------+
double calculateProfitLoss()
  {
   int totalPositions = PositionsTotal();
   double profitLoss = 0;
   for(int i=totalPositions-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
           {
            profitLoss += PositionGetDouble(POSITION_PROFIT);
           }
        }
     }
   return profitLoss;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|  handle Buttons                                                  |
//+------------------------------------------------------------------+
void handleButtons(double linePrice)
  {
   if(linePrice != 0)
     {
      buttonBuy.Create(0, "Buy", 0, 4+BUTTON_WIDTH, 50, 0, 0);
      buttonBuy.Width(BUTTON_WIDTH);
      buttonBuy.Height(BUTTON_HEIGHT);
      buttonBuy.Text("BUY");
      buttonBuy.ColorBackground(clrLightBlue);
      ObjectSetInteger(0, "Buy", OBJPROP_COLOR, clrBlue);

      buttonSell.Create(0, "Sell", 0, 4, 50, 0, 0);
      buttonSell.Width(BUTTON_WIDTH);
      buttonSell.Height(BUTTON_HEIGHT);
      buttonSell.Text("SELL");
      buttonSell.ColorBackground(clrSalmon);
      ObjectSetInteger(0, "Sell", OBJPROP_COLOR, clrDarkRed);
     }
   else
     {
      buttonBuy.Destroy(0);
      buttonSell.Destroy(0);
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int NumOfTrades()
  {
   int Num = 0;
   for(int i = PositionsTotal()-1; i>=0; i--)
     {
      if(!PositionInfo.SelectByIndex(i))
         continue;
      if(PositionInfo.Symbol()!=_Symbol)
         continue;
      Num++;
     }
   return Num;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAllTrades()
  {
   for(int i = PositionsTotal()-1; i>=0; i--)
     {
      if(!PositionInfo.SelectByTicket(PositionGetTicket(i)))
         continue;
      if(PositionInfo.Symbol()!=_Symbol)
         continue;

      if(!Trade.PositionClose(PositionGetInteger(POSITION_TICKET)))
         Print("Failed to close position : ",GetLastError());
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string CalculateBalance()
  {
   int totalPositions = PositionsTotal();
   double profitLoss = 0;
   double riskToReward = 0;
   int positionCount = 0;

   for(int i=totalPositions-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
           {
            double positionPoints=0;
            double positionTpPoints=0;
            double slPoints = MathAbs(PositionGetDouble(POSITION_SL)-PositionGetDouble(POSITION_PRICE_OPEN));
            double tpPoints = MathAbs(PositionGetDouble(POSITION_TP)-PositionGetDouble(POSITION_PRICE_OPEN));

            if(PositionInfo.PositionType() == POSITION_TYPE_BUY)
               positionPoints = PositionGetDouble(POSITION_PRICE_CURRENT)-PositionGetDouble(POSITION_PRICE_OPEN);
               positionTpPoints = MathAbs(PositionGetDouble(POSITION_TP)-PositionGetDouble(POSITION_PRICE_OPEN));
            if(PositionInfo.PositionType() == POSITION_TYPE_SELL)
               positionPoints = PositionGetDouble(POSITION_PRICE_OPEN)-PositionGetDouble(POSITION_PRICE_CURRENT);
               positionTpPoints = MathAbs(PositionGetDouble(POSITION_PRICE_OPEN)-PositionGetDouble(POSITION_TP));

            profitLoss += (positionPoints/slPoints);
            riskToReward +=(positionTpPoints/slPoints);
            positionCount++;

           }
        }
     }
   return DoubleToString(profitLoss/positionCount,2) + "  R ( " + DoubleToString(riskToReward/positionCount,2) + " )";
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetOrderType()
  {
// Get the line's price
   price_sl = NormalizeDouble(ObjectGetDouble(0, "sl", OBJPROP_PRICE),_Digits);
   price_li = NormalizeDouble(ObjectGetDouble(0, "li", OBJPROP_PRICE),_Digits);
   price_st = NormalizeDouble(ObjectGetDouble(0, "st", OBJPROP_PRICE),_Digits);

   string orderType = "";

   if(price_li!=0 && price_sl!=0)
      orderType = "Limit";

   else
      if(price_st!=0 && price_sl!=0)
         orderType = "Stop";

      else
         if(price_sl!=0)
            orderType = "Market";
         else
            orderType = "";

   return orderType;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Buy                                                              |
//+------------------------------------------------------------------+
void Buy()
  {
   double LotSize = NormalizeDouble(CalculatePositionSize(),2);
   if(buySignal==true && GetOrderType()=="Market")
     {
      double ASK = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
      double stopLossPoints = MathAbs(price_sl - ASK);
      double take;
      double stop;

      if(price_sl < ASK)
        {
         take = ASK+(stopLossPoints*RewardMultiplier);
         stop = ASK-stopLossPoints;
        }
      else
        {
         take = ASK+stopLossPoints;
         stop = ASK-(stopLossPoints*(1/RewardMultiplier));
        }

      if(TakeProfit == false)
         take = 0;
      if(StopLoss == false)
         stop = 0;

      if(!Trade.Buy(LotSize,NULL,ASK,stop,take,"TradeManagerBuy"))
         Print("Failed TM Buy : ",GetLastError());

      buySignal = false;
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Sell                                                             |
//+------------------------------------------------------------------+
void Sell()
  {
   double LotSize = NormalizeDouble(CalculatePositionSize(),2);
   if(sellSignal==true && GetOrderType()=="Market")
     {
      double BID = SymbolInfoDouble(Symbol(),SYMBOL_BID);
      double stopLossPoints = MathAbs(price_sl - SymbolInfoDouble(Symbol(), SYMBOL_BID));
      double take;
      double stop;

      if(price_sl > BID)
        {
         take = BID-(stopLossPoints*RewardMultiplier);
         stop = BID+stopLossPoints;
        }
      else
        {
         take = BID-stopLossPoints;
         stop = BID+(stopLossPoints*(1/RewardMultiplier));
        }

      if(TakeProfit == false)
         take = 0;
      if(StopLoss == false)
         stop = 0;

      if(!Trade.Sell(LotSize,NULL,BID,stop,take,"TradeManagerSell"))
         Print("Failed TM Sell : ",GetLastError());

      sellSignal = false;
     }
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BuyLimit()
  {
   double LotSize = NormalizeDouble(CalculatePositionSize(),2);
   if(buySignal==true && GetOrderType()=="Limit")
     {
      double stopLossPoints = MathAbs(price_sl - price_li);
      double take;
      double stop;

      if(price_sl < price_li)
        {
         take = price_li+(stopLossPoints*RewardMultiplier);
         stop = price_li-stopLossPoints;
        }
      else
        {
         take = price_li+stopLossPoints;
         stop = price_li-(stopLossPoints*(1/RewardMultiplier));
        }

      if(TakeProfit == false)
         take = 0;
      if(StopLoss == false)
         stop = 0;

      if(!Trade.BuyLimit(LotSize,price_li,NULL,stop,take,0,0,"TradeManagerBuyLimit"))
         Print("Failed TM BuyLimit : ",GetLastError());

      buySignal = false;
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SellLimit()
  {
   double LotSize = NormalizeDouble(CalculatePositionSize(),2);
   if(sellSignal==true && GetOrderType()=="Limit")
     {
      double stopLossPoints = MathAbs(price_sl - price_li);
      double take;
      double stop;

      if(price_sl > price_li)
        {
         take = price_li-(stopLossPoints*RewardMultiplier);
         stop = price_li+stopLossPoints;
        }
      else
        {
         take = price_li-stopLossPoints;
         stop = price_li+(stopLossPoints*(1/RewardMultiplier));
        }

      if(TakeProfit == false)
         take = 0;
      if(StopLoss == false)
         stop = 0;

      if(!Trade.SellLimit(LotSize,price_li,NULL,stop,take,0,0,"TradeManagerSellLimit"))
         Print("Failed TM SellLimit : ",GetLastError());

      sellSignal = false;
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BuyStop()
  {
   double LotSize = NormalizeDouble(CalculatePositionSize(),2);
   if(buySignal==true && GetOrderType()=="Stop")
     {
      double stopLossPoints = MathAbs(price_sl - price_st);
      double take;
      double stop;

      if(price_sl < price_st)
        {
         take = price_st+(stopLossPoints*RewardMultiplier);
         stop = price_st-stopLossPoints;
        }
      else
        {
         take = price_st+stopLossPoints;
         stop = price_st-(stopLossPoints*(1/RewardMultiplier));
        }

      if(TakeProfit == false)
         take = 0;
      if(StopLoss == false)
         stop = 0;

      if(!Trade.BuyStop(LotSize,price_st,NULL,stop,take,0,0,"TradeManagerBuyStop"))
         Print("Failed TM BuyStop : ",GetLastError());

      buySignal = false;
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SellStop()
  {
   double LotSize = NormalizeDouble(CalculatePositionSize(),2);
   if(sellSignal==true && GetOrderType()=="Stop")
     {
      double stopLossPoints = MathAbs(price_sl - price_st);
      double take;
      double stop;

      if(price_sl > price_st)
        {
         take = price_st-(stopLossPoints*RewardMultiplier);
         stop = price_st+stopLossPoints;
        }
      else
        {
         take = price_st-stopLossPoints;
         stop = price_st+(stopLossPoints*(1/RewardMultiplier));
        }

      if(TakeProfit == false)
         take = 0;
      if(StopLoss == false)
         stop = 0;

      if(!Trade.SellStop(LotSize,price_st,NULL,stop,take,0,0,"TradeManagerSellStop"))
         Print("Failed TM SellStop : ",GetLastError());

      sellSignal = false;
     }
  }
//+------------------------------------------------------------------+
