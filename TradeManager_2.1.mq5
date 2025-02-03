//+------------------------------------------------------------------+
//|                                             TradeManager 2.1.mq5 |
//|                                Copyright 2024, MalindaRasingolla |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MalindaRasingolla"
#property link      "https://www.mql5.com"
#property version   "2.10"

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
string lineName = "sl";

#define BUTTON_WIDTH 70
#define BUTTON_HEIGHT 30
CButton buttonBuy;
CButton buttonSell;

bool buySignal=false;
bool sellSignal=false;

double LotSize = 0;
double finalProfitloss = 0;

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

// Get the line's price
   double linePrice = NormalizeDouble(ObjectGetDouble(0, lineName, OBJPROP_PRICE),_Digits);
   handleButtons(linePrice);

   double MaxDrawdown = NormalizeDouble((AccountInfoDouble(ACCOUNT_BALANCE)*RiskPercentage/100),2);
   double EquityDrawdownMax = NormalizeDouble((AccountInfoDouble(ACCOUNT_BALANCE)*EquityDrawdown/100),2);

   LotSize = NormalizeDouble(CalculatePositionSize(MaxDrawdown,linePrice),2);

// Executing Orders
   Buy(linePrice,LotSize);
   Sell(linePrice,LotSize);

   double profitLoss = calculateProfitLoss();

//Quity Protector
   if(profitLoss <= (-1*EquityDrawdownMax))
     {
      finalProfitloss = 1;
     }
   if(finalProfitloss != 0 && EquityProtector == true)
     {
      CloseAllTrades();
      finalProfitloss = 0;
     }

// Comment section
   comment = _Symbol;

   if(NumOfTrades() > 0)
      comment += " | Open positions: " + IntegerToString(NumOfTrades(),0,0);

   comment += " | " + "Risk Per Trade: " + DoubleToString(MaxDrawdown,2);

   if(EquityProtector == true)
      comment +=  " | " + "Max Drawdown: " + DoubleToString(EquityDrawdownMax,2);

   if(linePrice != 0)
      comment += " | " + "LotSize: " + DoubleToString(LotSize,2);

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
double CalculatePositionSize(double riskAmount, double stopLossPrice)
  {
   double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double stopLossPoints = MathAbs(stopLossPrice - SymbolInfoDouble(Symbol(), SYMBOL_ASK));

   if(tickSize == 0 || tickValue ==0 || lotStep == 0)
      return 0;

   double moneyLotStep = (stopLossPoints/tickSize)*tickValue*lotStep;
   if(moneyLotStep == 0)
      return 0;

   double lots = MathFloor(riskAmount/moneyLotStep)*lotStep;

   return lots;

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Buy                                                              |
//+------------------------------------------------------------------+
void Buy(double stopLossPrice,double LotUsed)
  {

   if(!buySignal)
      return;

   double ASK = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   double stopLossPoints = MathAbs(stopLossPrice - ASK);
   double take;
   double stop;

   if(stopLossPrice < ASK)
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

   if(!Trade.Buy(LotUsed,NULL,ASK,stop,take,"TradeManagerBuy"))
      Print("Failed TM Buy : ",GetLastError());

   buySignal = false;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Sell                                                             |
//+------------------------------------------------------------------+
void Sell(double stopLossPrice,double LotUsed)
  {

   if(!sellSignal)
      return;

   double BID = SymbolInfoDouble(Symbol(),SYMBOL_BID);
   double stopLossPoints = MathAbs(stopLossPrice - SymbolInfoDouble(Symbol(), SYMBOL_BID));
   double take;
   double stop;

   if(stopLossPrice > BID)
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

   if(!Trade.Sell(LotUsed,NULL,BID,stop,take,"TradeManagerSell"))
      Print("Failed TM Sell : ",GetLastError());

   sellSignal = false;
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
      buttonBuy.Create(0, "Buy", 0, 4, 50, 0, 0);
      buttonBuy.Width(BUTTON_WIDTH);
      buttonBuy.Height(BUTTON_HEIGHT);
      buttonBuy.Text("BUY");
      buttonBuy.ColorBackground(clrLightBlue);
      ObjectSetInteger(0, "Buy", OBJPROP_COLOR, clrBlue);

      buttonSell.Create(0, "Sell", 0, 4+BUTTON_WIDTH, 50, 0, 0);
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
