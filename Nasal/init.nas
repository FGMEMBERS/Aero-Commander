setlistener("/sim/signals/fdm-initialized", func {
                                                                # Start the fuel system. The Velocity uses a customized
                                                                # fuel routine. See Velocity_fuel.nas
  setprop("/engines/engine[0]/mp-inhg-adj", 0);
  setprop("/engines/engine[1]/mp-inhg-adj", 0);
  setprop("/engines/engine[0]/oil-visc", 0);
  setprop("/engines/engine[1]/oil-visc", 0);
  setprop("/engines/engine[0]/fuel-consumed-lbs-adj", 0);
  setprop("/engines/engine[1]/fuel-consumed-lbs-adj", 0);
  setprop("/engines/engine[0]/chttempf", 0);
  setprop("/engines/engine[1]/chttempf", 0);
  #FuelInit();
  EngineInit();                                                 # See Velocity-engines.nas
  #Velocity_Savedata();
  #SoundInit();
  #stall_check();
});

