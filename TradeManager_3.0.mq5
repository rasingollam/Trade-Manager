//+------------------------------------------------------------------+
//|                                             TradeManager 3.0.mq5 |
//|                                Copyright 2024, MalindaRasingolla |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MalindaRasingolla"
#property link      "https://www.mql5.com"
#property version   "3.00"

#include <Controls\Button.mqh>
#include <Trade\Trade.mqh>

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
double price_bli;
double price_bst;
double price_sst;
double price_sli;

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
   comment = "😃 ";

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
      comment +=  " | " + "Balance : " + DoubleToString(NormalizeDouble(profitLoss,2),2) + "\n" + DoubleToString(NormalizeDouble(CalculateBalance(),2),2) + "%";

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
   if(GetOrderType()=="BuyLimit")
      stopLossPoints = MathAbs(price_sl - price_bli);
   if(GetOrderType()=="SellLimit")
      stopLossPoints = MathAbs(price_sl - price_sli);
   if(GetOrderType()=="BuyStop")
      stopLossPoints = MathAbs(price_sl - price_bst);
   if(GetOrderType()=="SellStop")
      stopLossPoints = MathAbs(price_sl - price_sst);

   if(tickSize == 0 || tickValue ==0 || lotStep == 0)
      return 0;

   double moneyLotStep = (stopLossPoints/tickSize)*tickValue*lotStep;
   if(moneyLotStep == 0)
      return 0;

   double lots = MathFloor(MaxDrawdown/moneyLotStep)*lotStep;

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
double CalculateBalance()
  {
   int totalPositions = PositionsTotal();
   double profitLoss = 0;
   int positionCount = 0;

   for(int i=totalPositions-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
           {
            double positionPoints=0;
            double slPoints = MathAbs(PositionGetDouble(POSITION_SL)-PositionGetDouble(POSITION_PRICE_OPEN));

            if(PositionInfo.PositionType() == POSITION_TYPE_BUY)
               positionPoints = PositionGetDouble(POSITION_PRICE_CURRENT)-PositionGetDouble(POSITION_PRICE_OPEN);
            if(PositionInfo.PositionType() == POSITION_TYPE_SELL)
               positionPoints = PositionGetDouble(POSITION_PRICE_OPEN)-PositionGetDouble(POSITION_PRICE_CURRENT);

            profitLoss += (positionPoints/slPoints)*100;
            positionCount++;

           }
        }
     }
   return profitLoss/positionCount;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetOrderType()
  {
// Get the line's price
   price_sl = NormalizeDouble(ObjectGetDouble(0, "sl", OBJPROP_PRICE),_Digits);
   price_bli = NormalizeDouble(ObjectGetDouble(0, "bli", OBJPROP_PRICE),_Digits);
   price_bst = NormalizeDouble(ObjectGetDouble(0, "bst", OBJPROP_PRICE),_Digits);
   price_sst = NormalizeDouble(ObjectGetDouble(0, "sst", OBJPROP_PRICE),_Digits);
   price_sli = NormalizeDouble(ObjectGetDouble(0, "sli", OBJPROP_PRICE),_Digits);

   string orderType = "";

   if(price_bli!=0 && price_sl!=0)
      orderType = "BuyLimit";

   else
      if(price_sli!=0 && price_sl!=0)
         orderType = "SellLimit";

      else
         if(price_bst!=0 && price_sl!=0)
            orderType = "BuyStop";

         else
            if(price_sst!=0 && price_sl!=0)
               orderType = "SellStop";

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
   if(buySignal==true && GetOrderType()=="BuyLimit")
     {
      double stopLossPoints = MathAbs(price_sl - price_bli);
      double take;
      double stop;

      if(price_sl < price_bli)
        {
         take = price_bli+(stopLossPoints*RewardMultiplier);
         stop = price_bli-stopLossPoints;
        }
      else
        {
         take = price_bli+stopLossPoints;
         stop = price_bli-(stopLossPoints*(1/RewardMultiplier));
        }

      if(TakeProfit == false)
         take = 0;
      if(StopLoss == false)
         stop = 0;

      if(!Trade.BuyLimit(LotSize,price_bli,NULL,stop,take,0,0,"TradeManagerBuyLimit"))
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
   if(sellSignal==true && GetOrderType()=="SellLimit")
     {
      double stopLossPoints = MathAbs(price_sl - price_sli);
      double take;
      double stop;

      if(price_sl > price_sli)
        {
         take = price_sli-(stopLossPoints*RewardMultiplier);
         stop = price_sli+stopLossPoints;
        }
      else
        {
         take = price_sli-stopLossPoints;
         stop = price_sli+(stopLossPoints*(1/RewardMultiplier));
        }

      if(TakeProfit == false)
         take = 0;
      if(StopLoss == false)
         stop = 0;

      if(!Trade.SellLimit(LotSize,price_sli,NULL,stop,take,0,0,"TradeManagerSellLimit"))
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
   if(buySignal==true && GetOrderType()=="BuyStop")
     {
      double stopLossPoints = MathAbs(price_sl - price_bst);
      double take;
      double stop;

      if(price_sl < price_bst)
        {
         take = price_bst+(stopLossPoints*RewardMultiplier);
         stop = price_bst-stopLossPoints;
        }
      else
        {
         take = price_bst+stopLossPoints;
         stop = price_bst-(stopLossPoints*(1/RewardMultiplier));
        }

      if(TakeProfit == false)
         take = 0;
      if(StopLoss == false)
         stop = 0;

      if(!Trade.BuyStop(LotSize,price_bst,NULL,stop,take,0,0,"TradeManagerBuyStop"))
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
   if(sellSignal==true && GetOrderType()=="SellStop")
     {
      double stopLossPoints = MathAbs(price_sl - price_sst);
      double take;
      double stop;

      if(price_sl > price_sst)
        {
         take = price_sst-(stopLossPoints*RewardMultiplier);
         stop = price_sst+stopLossPoints;
        }
      else
        {
         take = price_sst-stopLossPoints;
         stop = price_sst+(stopLossPoints*(1/RewardMultiplier));
        }

      if(TakeProfit == false)
         take = 0;
      if(StopLoss == false)
         stop = 0;

      if(!Trade.SellStop(LotSize,price_sst,NULL,stop,take,0,0,"TradeManagerSellStop"))
         Print("Failed TM SellStop : ",GetLastError());

      sellSignal = false;
     }
  }
//+------------------------------------------------------------------+
