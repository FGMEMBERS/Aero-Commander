# ***********************************************
# **** Forcer les rpm à 0 si moteur arrêté   ****
# **** BARANGER Emmanuel                2012 ****
# ****                                       ****
# **** Merci à Shinobi pour la correction    ****
# **** sur le second moteur                  ****
# ***********************************************
#* ;) De rien

var running0 = props.globals.getNode("/engines/engine[0]/running",1);
var starter0 = props.globals.getNode("/controls/engines/engine[0]/starter",1);
var enginerpm0 = props.globals.getNode("/engines/engine[0]/rpm");

var running1 = props.globals.getNode("/engines/engine[1]/running",1);
var starter1 = props.globals.getNode("/controls/engines/engine[1]/starter",1);
var enginerpm1 = props.globals.getNode("/engines/engine[1]/rpm");

var update_rpm = func 
{
  if (!(running0.getBoolValue()) and !(starter0.getBoolValue())) {
    enginerpm0.setValue(0);
  }
  if (!(running1.getBoolValue()) and !(starter1.getBoolValue())) {
    enginerpm1.setValue(0);
  }
}

var main_loop = func {
  update_rpm();
  settimer(main_loop, 0);
}

setlistener("/sim/signals/fdm-initialized", func {
  main_loop();
});
