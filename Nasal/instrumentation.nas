# **********************
# **** 5H1N0B1 2013 ****
# **********************

var initIns = func {
  temperature();
  pression();

  settimer(initIns, 0.5);
}


var temperature = func{
        
  setprop("engines/engine[0]/egt-degC", convertTemp(getprop("engines/engine[0]/egt-degf")));
  setprop("engines/engine[1]/egt-degC", convertTemp(getprop("engines/engine[1]/egt-degf")));
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

var pression= func(){

  var rpm0 = getprop("/engines/engine[0]/rpm");
  var rpm1 = getprop("/engines/engine[1]/rpm");
  
  #Engine 0
  if (rpm0 > 600.0) {
      var fuel_pres0 = rpm0 / 258.82 - 1.43;
      var oil_pres0 = rpm0 / 33.85 + 10.25; 
  }else{
          var fuel_pres0 = 0.0;
          var oil_pres0 = 0.0;
  }
    
  #Engine 1
  if (rpm1 > 600.0) {
      var fuel_pres1 = rpm1 / 258.82 - 1.43;
      var oil_pres1 = rpm1 / 33.85 + 10.25;
  } else { 
      var fuel_pres1 = 0.0;
      var oil_pres1 = 0.0;
  }
    
  setprop("/engines/engine[0]/oil-pressure-psi", oil_pres1);
  setprop("/engines/engine[1]/oil-pressure-psi", oil_pres0);
    
  setprop("/engines/engine[0]/fuel-pressure-psi", fuel_pres1);
  setprop("/engines/engine[1]/fuel-pressure-psi", fuel_pres0);  
    
}
