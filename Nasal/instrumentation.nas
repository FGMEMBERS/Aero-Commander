# **********************************
# **** 5H1N0B1             2013 ****
# ****                          ****
# **** Updated Chris BROWN 2014 ****
# **********************************

var initIns = func {
  temperature();
  pression();
  
  settimer(initIns, 0.1);
  settimer(chtegt, 1);
}

var temperature = func{
        
  #setprop("engines/engine[0]/egt-degC", convertTemp(getprop("engines/engine[0]/egt-degf")));
  #setprop("engines/engine[1]/egt-degC", convertTemp(getprop("engines/engine[1]/egt-degf")));
  setprop("engines/engine[0]/oil-temperature-degC", convertTemp(getprop("engines/engine[0]/oil-temperature-degf")));
  setprop("engines/engine[1]/oil-temperature-degC", convertTemp(getprop("engines/engine[1]/oil-temperature-degf")));
        
}
var convertTemp = func(degF) {
  var degC = 0;
  if(degF != nil){
          #print(degF);
          degC = (degF - 32) * 5/9;
  }
  return degC;

}

var chtegt = func() {
  var rpm0 = getprop("/engines/engine[0]/rpm");
  var rpm1 = getprop("/engines/engine[1]/rpm");
  var oat = getprop("/environment/temperature-degc"); 
  var cht0 = getprop("/engines/engine[0]/cht-degc");
  var cht1 = getprop("/engines/engine[1]/cht-degc");
  var egt0 = getprop("/engines/engine[0]/egt-degc");
  var egt1 = getprop("/engines/engine[1]/egt-degc");
  var mp0 = getprop("/engines/engine[0]/mp-osi");
  var mp1 = getprop("/engines/engine[1]/mp-osi");
  var run0 = getprop("/engines/engine[0]/running");
  var run1 = getprop("/engines/engine[1]/running");
  var flow0 = getprop("/engines/engine[0]/fuel-flow-gph");
  var flow1 = getprop("/engines/engine[1]/fuel-flow-gph");
  var oilt0 = getprop("/engines/engine[0]/oil-temperature");
  var oilt1 = getprop("/engines/engine[1]/oil-temperature");
  var ias = getprop("/instrumentation/airspeed-indicator/indicated-speed-kt");

  if (mp0 < 10) { mp0 = 10; }
  if (mp1 < 10) { mp1 = 10; }
  
  #Engine 0
  if (run0) {
    cht0  = cht0 + (mp0 * 8 + oat - ias/3 - cht0) / 250;
    egt0  = egt0 + ((mp0 * 30 + cht0 * 2) * mp0 / (flow0 * 2 + 1) - egt0) / 100;
    oilt0 = oilt0 +(rpm0 / 25 + oat - oilt0) / 250;
  } else {
  if ( ! cht0  ) { cht0 = oat;}
  if ( ! egt0  ) { egt0 = oat;}
    if ( ! oilt0 ) { oilt0 = oat;}
  cht0 = cht0 + (oat - cht0)/100;
  egt0 = egt0 + (oat - egt0)/100;
    oilt0 = oilt0 + (oat - oilt0)/100;
  }
  #Engine 1
  if (run1) {
    cht1  = cht1 + (mp1 * 8 + oat - ias/3 - cht1) / 250;
    egt1  = egt1 + ((mp1 * 30 + cht1 * 2) * mp1 / (flow1 * 2 + 1) - egt1) / 100;
    oilt1 = oilt1 +(rpm1 / 25 + oat - oilt1) / 250;
  } else {
  if ( ! cht1  ) { cht1 = oat;}
  if ( ! egt1  ) { egt1 = oat;}
    if ( ! oilt1 ) { oilt1 = oat;}
  cht1 = cht1 + (oat - cht1)/100;
  egt1 = egt1 + (oat - egt1)/100;
    oilt1 = oilt1 + (oat - oilt1)/100;
  }
  
  setprop("/engines/engine[0]/cht-degc", cht0);
  setprop("/engines/engine[1]/cht-degc", cht1);
  setprop("/engines/engine[0]/oil-temperature", oilt0);
  setprop("/engines/engine[1]/oil-temperature", oilt1);
  setprop("/engines/engine[0]/egt-degc", egt0);
  setprop("/engines/engine[1]/egt-degc", egt1);
  setprop("/engines/engine[0]/egt-degf-calc", egt0 * 9/5 + 32);
  setprop("/engines/engine[1]/egt-degf-calc", egt1 * 9/5 + 32);
  setprop("/systems/electrical/amp", (rpm0 + rpm1) / 100 );
    
}
  
var pression= func(){

  var rpm0 = getprop("/engines/engine[0]/rpm");
  var rpm1 = getprop("/engines/engine[1]/rpm");
  
  #Engine 0
  if (rpm0 > 100.0) {
      var fuel_pres0 = rpm0 / 100;
      var oil_pres0 = rpm0 / 25; 
  }else{
          var fuel_pres0 = 0.0;
          var oil_pres0 = 0.0;
  }
    
  #Engine 1
  if (rpm1 > 100.0) {
      var fuel_pres1 = rpm1 / 100;
      var oil_pres1 = rpm1 / 25;
  } else { 
      var fuel_pres1 = 0.0;
      var oil_pres1 = 0.0;
  }
  
  setprop("/engines/engine[0]/oil-pressure-psi", oil_pres1);
  setprop("/engines/engine[1]/oil-pressure-psi", oil_pres0);
    
  setprop("/engines/engine[0]/fuel-pressure-psi", fuel_pres1);
  setprop("/engines/engine[1]/fuel-pressure-psi", fuel_pres0);  
      
}
