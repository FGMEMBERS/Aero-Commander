# Autostart based on Jet and turboprop system for piston engines
#
# BARANGER Emmanuel (04/2024)

props.globals.initNode("/sim/autostart/started", 0, "BOOL");

var eng1fuelon = func { setprop("/controls/engines/engine[0]/cutoff", 0); }
var eng2fuelon = func { setprop("/controls/engines/engine[1]/cutoff", 0); }

var eng1fueloff = func {
  setprop("/controls/engines/engine[0]/cutoff", 1);
  setprop("/controls/engines/engine[0]/throttle", 0);
}
var eng2fueloff = func {
  setprop("/controls/engines/engine[1]/cutoff", 1);
  setprop("/controls/engines/engine[1]/throttle", 0);
}

var eng1starter = func { setprop("/controls/engines/engine[0]/starter", 1); }
var eng2starter = func { setprop("/controls/engines/engine[1]/starter", 1); }

var eng1staroff = func { setprop("/controls/engines/engine[0]/starter", 0); }
var eng2staroff = func { setprop("/controls/engines/engine[1]/starter", 0); }

var eng1start = func {
  gui.popupTip("*** Engine start 1 left ***");
  eng1fueloff();
  eng1starter();
  settimer(eng1fuelon, 2);
  settimer(eng1staroff, 4);
}

var eng2start = func {
  gui.popupTip("*** Engine start 2 right ***");
  eng2fueloff();
  eng2starter();
  settimer(eng2fuelon, 2);
  settimer(eng2staroff, 4);
}


var engstart = func {
  settimer(eng1start, 2);
  settimer(eng2start, 6);
}

var engstop = func {
  settimer(eng1fueloff, 1);
  settimer(eng2fueloff, 6);
}

var autostart = func {
  var startstatus = getprop("/sim/autostart/started");
  if ( startstatus == 0 ) {
    gui.popupTip("Autostarting...");
    setprop("/sim/model/autostart", 1);
    setprop("/sim/autostart/started", 1);
    settimer(engstart, 0.4);
    gui.popupTip("Starting Engines");
  }
  if ( startstatus == 1 ) {
    gui.popupTip("Shutting Down...");
    setprop("/sim/model/autostart", 0);
    setprop("/sim/autostart/started", 0);
    engstop();
  }
}
