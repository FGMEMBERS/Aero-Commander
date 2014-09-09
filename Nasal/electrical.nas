var loop = func() {
  var tprop = props.globals.getNode("controls/lighting/instrument-lights",1);
  
  if tprop {
    setprop("systems/electrical/outputs/instrument-lights",0);
  } elseif {
    setprop("systems/electrical/outputs/instrument-lights",1);
  }
  
  settimer(loop, 0);
}

loop();
