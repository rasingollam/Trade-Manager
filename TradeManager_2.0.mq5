//+------------------------------------------------------------------+
//|                                             TradeManager-2.0.mq5 |
//|                                Copyright 2024, MalindaRasingolla |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MalindaRasingolla"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include <Controls\Button.mqh>
#include <Trade\Trade.mqh>

CTrade Trade;

input group "RISK INPUTS"
input double RiskPercentage = 0.2;
input double RewardMultiplier = 1;

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
// Get the line's price
   double linePrice = NormalizeDouble(ObjectGetDouble(0, lineName, OBJPROP_PRICE),_Digits);
   handleButtons(linePrice);

   double MaxDrawdown = NormalizeDouble((AccountInfoDouble(ACCOUNT_BALANCE)*RiskPercentage/100),2);
   double ProfitTarget = MaxDrawdown*RewardMultiplier; // Profit target
   double LotSize = NormalizeDouble(CalculatePositionSize(MaxDrawdown,linePrice),2);

// Executing Orders
   Buy(linePrice,LotSize);
   Sell(linePrice,LotSize);

   double profitLoss = calculateProfitLoss(_Symbol);

// Close all trades
   if(profitLoss <= (-1*MaxDrawdown) || profitLoss >= ProfitTarget)
     {
      CloseAllTrades();
     }

// Comment the total positions, maximum drawdown, profit target, and profit/loss on the chart
   string comment = _Symbol + " | Open positions: " + IntegerToString(PositionsTotal(),0,0) + " | " +
                    "Max Drawdown: " + DoubleToString(MaxDrawdown,2) + " | " +
                    "Profit Target: " + DoubleToString(ProfitTarget,2) + " | " +
                    "LotSize: " + DoubleToString(LotSize,2) + "\n" +
                    "Balance : " + DoubleToString(NormalizeDouble(profitLoss,2),2);
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
   double stopLossPoints = MathAbs(stopLossPrice - SymbolInfoDouble(Symbol(), SYMBOL_ASK));
   double take=ASK+(stopLossPoints*RewardMultiplier);

   if(!Trade.Buy(LotUsed,NULL,ASK,stopLossPrice,take,"TradeManagerBuy"))
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
   double take=BID-(stopLossPoints*RewardMultiplier);

   if(!Trade.Sell(LotUsed,NULL,BID,stopLossPrice,take,"TradeManagerSell"))
      Print("Failed TM Sell : ",GetLastError());

   sellSignal = false;
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Close all trades                                                 |
//+------------------------------------------------------------------+
void CloseAllTrades()
  {
   int totalPositions = 0;

   for(int i=totalPositions-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
           {
            if(!Trade.PositionClose(ticket))
              {
               Print("PositionClose error ",GetLastError());
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Position Profit                                        |
//+------------------------------------------------------------------+
double calculateProfitLoss(string symbol)
  {
   int totalPositions = PositionsTotal();
   int positionCount = 0;
   double profitLoss = 0;

   for(int i=totalPositions-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if(PositionGetString(POSITION_SYMBOL) == symbol)
           {
            positionCount++;
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
