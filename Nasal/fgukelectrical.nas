##
# FGUK Electrical System in Nasal - Based on DH2 Electrial.
##

# Initialize internal values
#

var battery = nil;
var alternator = nil;

var last_time = 0.0;

var vbus_volts = 0.0;
var main_bus_volts = 0.0;
var essential_bus_volts = 0.0;
var avionic_bus_1_volts = 0.0;
var avionic_bus_2_volts = 0.0;
var ammeter_ave = 0.0;

##
# Initialize the electrical system
#

init_electrical = func {
    battery = BatteryClass.new();
    alternator = AlternatorClass.new();

###
### Initialise electrical stuff ###
### (move to electric system init once electrical system exists complete) ###
###
    props.globals.getNode("/systems/electrical/volts", 1).setDoubleValue(0.0);
    props.globals.getNode("/systems/electrical/amps", 1).setDoubleValue(0.0);
    props.globals.getNode("/systems/electrical/alternator", 1).setDoubleValue(0.0);

    props.globals.getNode("instrumentation/warning-panel/lovolt-norm", 1).setDoubleValue(0.0);
    props.globals.getNode("instrumentation/warning-panel/fuel-norm", 1).setDoubleValue(0.0);

    props.globals.getNode("controls/circuit-breakers/start-ctrl", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/start-ctrl", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/gen-ctrl", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/strobe-white", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/strobe-red", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/panel-lights", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/avionic-blower", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/pitot-heat", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/fuel-pump", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/eng-instr-2", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/gps", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/com2-nav2", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/avionic-bus-2", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/dme", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/audio-marker", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/att-indic-2", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/land-light", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/map-light", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/nav-lights", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/eng-instr-1", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/instr-lights", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/rpm-ind", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/lo-volt-warning", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/tands", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/fuel-lo-lev", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/att-indic-1", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/stall-warning", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/ess-bus", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/main-bus", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/gen", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/avionic-relay", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/flaps", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/mute", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/hsi", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/alt-encoder", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/transponder", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/nav1", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/com1", 1).setBoolValue(1);
    props.globals.getNode("controls/circuit-breakers/avionic-bus-1", 1).setBoolValue(1);

    props.globals.getNode("/controls/electric/battery-switch", 1).setBoolValue(0);
    props.globals.getNode("/controls/switches/avionic-master", 1).setBoolValue(0);
    props.globals.getNode("/controls/electric/engine/generator", 1).setBoolValue(0);
    props.globals.getNode("/controls/switches/landing-light", 1).setBoolValue(0);
    props.globals.getNode("/controls/switches/nav-lights", 1).setBoolValue(0);
    props.globals.getNode("/controls/switches/pitot-heat", 1).setBoolValue(0);
    props.globals.getNode("/controls/switches/strobes", 1).setIntValue(0);
    props.globals.getNode("/controls/anti-ice/engine/carb-heat", 1).setBoolValue(0);
    props.globals.getNode("/controls/switches/instr-lights", 1).setBoolValue(0);

    props.globals.getNode("/controls/lighting/instruments-dim", 1).setDoubleValue(0.0);
    props.globals.getNode("/controls/lighting/panel-dim", 1).setDoubleValue(0.0);
    props.globals.getNode("/controls/lighting/map-dim", 1).setDoubleValue(0.0);
    props.globals.getNode("/systems/electrical/outputs/start-ctrl", 1).setDoubleValue(0.0);
    props.globals.getNode("/systems/electrical/outputs/instrument-lights", 1).setDoubleValue(0.0);
    props.globals.getNode("/systems/electrical/outputs/lo-volt-warning", 1).setDoubleValue(0.0);
    props.globals.getNode("/systems/electrical/outputs/audio-marker", 1).setDoubleValue(0.0);

    print("Nasal Electrical System : initialised");
    props.globals.getNode("/sim/signals/electrical-initialized", 1).setBoolValue(0);

    # Request that the update fuction be called next frame
    settimer(update_electrical, 0);
}

BatteryClass = {};

BatteryClass.new = func {
    obj = { parents : [BatteryClass],
            ideal_volts : 24.0,
            ideal_amps : 30.0,
            amp_hours : 12.75,
            charge_percent : 1.0,
            charge_amps : 7.0 };
    return obj;
}


BatteryClass.apply_load = func( amps, dt ) {
    amphrs_used = amps * dt / 3600.0;
    percent_used = amphrs_used / me.amp_hours;
    me.charge_percent -= percent_used;
    if ( me.charge_percent < 0.0 ) {
        me.charge_percent = 0.0;
    } elsif ( me.charge_percent > 1.0 ) {
        me.charge_percent = 1.0;
    }
    # print( "battery percent = ", me.charge_percent);
    return me.amp_hours * me.charge_percent;
}


BatteryClass.get_output_volts = func {
    x = 1.0 - me.charge_percent;
    tmp = -(3.0 * x - 1.0);
    factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
    return me.ideal_volts * factor;
}


BatteryClass.get_output_amps = func {
    x = 1.0 - me.charge_percent;
    tmp = -(3.0 * x - 1.0);
    factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
    return me.ideal_amps * factor;
}


AlternatorClass = {};

AlternatorClass.new = func {
    obj = { parents : [AlternatorClass],
            rpm_source : "/engines/engine[0]/rpm",
            rpm_threshold : 600.0,
            ideal_volts : 28.0,
            ideal_amps : 60.0 };
    setprop( obj.rpm_source, 0.0 );
    return obj;
}


AlternatorClass.apply_load = func( amps, dt ) {
    # Scale alternator output for rpms < 600.  For rpms >= 600
    # give full output.  This is just a WAG, and probably not how
    # it really works but I'm keeping things "simple" to start.
    rpm = getprop( me.rpm_source );
    factor = rpm / me.rpm_threshold;
    if ( factor > 1.0 ) {
        factor = 1.0;
    }
    # print( "alternator amps = ", me.ideal_amps * factor );
    available_amps = me.ideal_amps * factor;
    return available_amps - amps;
}


AlternatorClass.get_output_volts = func {
    # scale alternator output for rpms < 600.  For rpms >= 600
    # give full output.  This is just a WAG, and probably not how
    # it really works but I'm keeping things "simple" to start.
    rpm = getprop( me.rpm_source );
    factor = rpm / me.rpm_threshold;
    if ( factor > 1.0 ) {
        factor = 1.0;
    }
    # print( "alternator volts = ", me.ideal_volts * factor );
    return me.ideal_volts * factor;
}


AlternatorClass.get_output_amps = func {
    # scale alternator output for rpms < 600.  For rpms >= 600
    # give full output.  This is just a WAG, and probably not how
    # it really works but I'm keeping things "simple" to start.
    rpm = getprop( me.rpm_source );
    factor = rpm / me.rpm_threshold;
    if ( factor > 1.0 ) {
        factor = 1.0;
    }
    # print( "alternator amps = ", ideal_amps * factor );
    return me.ideal_amps * factor;
}


update_electrical = func {
    time = getprop("/sim/time/elapsed-sec");
    dt = time - last_time;
    last_time = time;

    update_virtual_bus( dt );
    # Request that the update fuction be called again next frame
    settimer(update_electrical, 0);
}


update_virtual_bus = func( dt ) {
    battery_volts = battery.get_output_volts();
    alternator_volts = alternator.get_output_volts();
    external_volts = 0.0;
    load = 0.0;

    # switch state
    master_alt = getprop("/controls/switches/generator");

    # determine power source
    bus_volts = 0.0;
    power_source = "none";
    if ( getprop("/controls/electric/battery-switch") ) {
        bus_volts = battery_volts;
        power_source = "battery";
    }
    if ( getprop("/controls/switches/generator") and
         getprop("/controls/circuit-breakers/gen") and 
         (alternator_volts > bus_volts) ) {
        bus_volts = alternator_volts;
        power_source = "alternator";
    }
    if ( external_volts > bus_volts ) {
        bus_volts = external_volts;
        power_source = "external";
    }
    # print( "virtual bus volts = ", bus_volts );

    # starter
    if (getprop("/systems/electrical/outputs/start-ctrl") > 16 ) {
        setprop("/systems/electrical/outputs/starter[0]", bus_volts);
  if (getprop("/controls/switches/starter")==1) {
      load += 10.0;
  }
    } else {
        setprop("/systems/electrical/outputs/starter[0]", 0.0);
    }

    # flaps
    if ( getprop("/controls/circuit-breakers/flaps") ) {
  setprop("/systems/electrical/outputs/flaps", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/flaps", 0.0);
    }

    # bus network (1. these must be called in the right order, 2. the
    # bus routine itself determins where it draws power from.)
    load += main_bus();
    load += essential_bus();
    load += avionic_bus_1();
    load += avionic_bus_2();

    # system loads and ammeter gauge
    ammeter = 0.0;
    if ( bus_volts > 1.0 ) {

        # ammeter gauge
        if ( power_source == "battery" ) {
            ammeter = -load;
        } else {
            ammeter = battery.charge_amps;
        }
    }
    # print( "ammeter = ", ammeter );

    # charge/discharge the battery
    if ( power_source == "battery" ) {
        battery.apply_load( load, dt );
    } elsif ( bus_volts > battery_volts ) {
        battery.apply_load( -battery.charge_amps, dt );
    }

    # filter ammeter needle pos
    ammeter_ave = 0.8 * ammeter_ave + 0.2 * ammeter;

    # outputs
    setprop("/systems/electrical/amps", ammeter_ave);
    setprop("/systems/electrical/volts", bus_volts);
    setprop("/systems/electrical/alternator", alternator_volts);
    vbus_volts = bus_volts;

    return load;
}


main_bus = func() {

    # fed from the "virtual" bus via the main bus breaker (30A)
    if ( getprop("/controls/circuit-breakers/main-bus") ) {
      main_bus_volts = vbus_volts;
    } else {
  main_bus_volts = 0.0;
    } 

    load = 0.0;

    # Start Ctrl (7.5A)
    if ( getprop("/controls/circuit-breakers/start-ctrl") ) {
        setprop("/systems/electrical/outputs/start-ctrl", main_bus_volts);
  load += 0.5;
    } else {
        setprop("/systems/electrical/outputs/start-ctrl", 0.0);
    }

    # Gen Ctrl (3A)
    if ( getprop("/controls/circuit-breakers/gen-ctrl") ) {
        setprop("/systems/electrical/outputs/gen-ctrl", main_bus_volts);
  load += 0.25;
    } else {
        setprop("/systems/electrical/outputs/gen-ctrl", 0.0);
    }

    # White Strobe (10A)
    var strobeswitch=getprop("/controls/switches/strobes");
    if ( getprop("/controls/circuit-breakers/strobe-white") and
         strobeswitch==1 ) {
         setprop("/systems/electrical/outputs/white-strobe", main_bus_volts);
         load += 6.0;
    } else {
        setprop("/systems/electrical/outputs/white-strobe", 0.0);
    }
    
    # Red Strobe (7.5A)
    if ( getprop("/controls/circuit-breakers/strobe-red") and 
         strobeswitch==-1 ) {
        setprop("/systems/electrical/outputs/red-strobe", main_bus_volts);
  load += 3;
    } else {
        setprop("/systems/electrical/outputs/red-strobe", 0.0);
    }

    # Panel Lights (5A)
    if ( getprop("/controls/circuit-breakers/panel-lights") ) {
        setprop("/systems/electrical/outputs/panel-lights", main_bus_volts);
        setprop("/controls/lighting/panel-norm", getprop("/systems/electrical/outputs/panel-lights") * getprop("/controls/lighting/panel-dim") * 0.041666);
  load += 0.7*getprop("/controls/lighting/panel-dim");
    } else {
        setprop("/systems/electrical/outputs/panel-lights", 0.0);
  setprop("/controls/lighting/panel-norm", 0.0);
    }

    # Avionic Blower (1A)
    if ( getprop("/controls/circuit-breakers/avionic-blower") ) {
        setprop("/systems/electrical/outputs/avionic-blower", main_bus_volts);
  load += 0.45;
    } else {
        setprop("/systems/electrical/outputs/avionic-blower", 0.0);
    }

    # Pitot Heat (7.5A)
    if ( getprop("/controls/circuit-breakers/pitot-heat") and
         getprop("/controls/switches/pitot-heat") ) {
        setprop("/systems/electrical/outputs/pitot-heat", main_bus_volts);
  load += 2.5;
    } else {
        setprop("/systems/electrical/outputs/pitot-heat", 0.0);
    }

    # Fuel Pump (5A)
    if ( getprop("/controls/circuit-breakers/fuel-pump") and
         getprop("/controls/engines/engine/fuel-pump") ) {
        setprop("/systems/electrical/outputs/fuel-pump", main_bus_volts);
  load += 3;
    } else {
        setprop("/systems/electrical/outputs/fuel-pump", 0.0);
    }

    # Eng Instr 2 (3A)
    if ( getprop("/controls/circuit-breakers/eng-instr-2") ) {
        setprop("/systems/electrical/outputs/eng-instr-2", main_bus_volts);
  load += 0.12;
    } else {
        setprop("/systems/electrical/outputs/eng-instr-2", 0.0);
    }

    # pop breaker if over current
    if ( load>30.0 ) {
        setprop("/controls/circuit-breakers/main-bus",0);
    }

    # return cumulative load
    if ( getprop("/controls/circuit-breakers/main-bus") ) { 
   setprop("/systems/electrical/debug/main-load", load);
         setprop("/systems/electrical/debug/main-volts", main_bus_volts);
  return load;
    } else {
  return 0.0;
    }
}

essential_bus = func() {
    # fed from the "virtual" bus via the ess bus breaker (15A)
    if ( getprop("/controls/circuit-breakers/ess-bus") ) {
      essential_bus_volts = vbus_volts;
    } else {
  essential_bus_volts = 0.0;
    } 

    load = 0.0;

    # Landing Light (7.5A)
    if ( getprop("/controls/circuit-breakers/land-light") ) {
        setprop("/systems/electrical/outputs/land-light", essential_bus_volts);
  load += 3.5;
    } else {
        setprop("/systems/electrical/outputs/land-light", 0.0);
    }

    # Map Light (5A)
    if ( getprop("/controls/circuit-breakers/map-light") ) {
        setprop("/systems/electrical/outputs/map-light", essential_bus_volts);
        setprop("/controls/lighting/map-norm", essential_bus_volts * getprop("/controls/lighting/instruments-dim") * 0.041666);
  load += 0.3*getprop("/controls/lighting/map-dim");
    } else {
        setprop("/systems/electrical/outputs/map-light", 0.0);
    }

    # Nav Lights (7.5A)
    if ( getprop("/controls/circuit-breakers/nav-lights") and
   getprop("/controls/switches/nav-lights") ) {
        setprop("/systems/electrical/outputs/nav-lights", essential_bus_volts);
        setprop("/controls/lighting/nav-lights-norm", getprop("/systems/electrical/outputs/nav-lights") * 0.041666);
  load += 4.0;
    } else {
        setprop("/systems/electrical/outputs/nav-lights", 0.0);
        setprop("/controls/lighting/nav-lights-norm", 0.0);
    }

    # Eng Instr 1 (3A)
    if ( getprop("/controls/circuit-breakers/eng-instr-1") ) {
        setprop("/systems/electrical/outputs/eng-instr-1", essential_bus_volts);
  load += 0.05;
    } else {
        setprop("/systems/electrical/outputs/eng-instr-1", 0.0);
    }

    # Instr Lights (5A)
    if ( getprop("/controls/circuit-breakers/instr-lights") and
   getprop("/controls/switches/instr-lights") ) {
        setprop("/systems/electrical/outputs/instr-lights", essential_bus_volts);
        setprop("/controls/lighting/instruments-norm", getprop("/systems/electrical/outputs/instr-lights") * getprop("/controls/lighting/instruments-dim") * 0.041666);
  load += 1*getprop("/controls/lighting/instruments-dim");
    } else {
        setprop("/systems/electrical/outputs/instr-lights", 0.0);
  setprop("/controls/lighting/instruments-norm", 0.0);
    }

    # RPM Ind (3A)
    if ( getprop("/controls/circuit-breakers/rpm-ind") ) {
        setprop("/systems/electrical/outputs/rpm-ind", essential_bus_volts);
  load += 0.04;
    } else {
        setprop("/systems/electrical/outputs/rpm-ind", 0.0);
    }

    # Lo Volt Warning (3A)
    if ( getprop("/controls/circuit-breakers/lo-volt-warning") ) {
        setprop("/systems/electrical/outputs/lo-volt-warning", essential_bus_volts);
    } else {
        setprop("/systems/electrical/outputs/lo-volt-warning", 0.0);
    }
    if ( getprop("/instrumentation/warning-panel/lovolt-norm") > 0 ) {
  load += 0.02;
    }

    # T&S (5A)
    if ( getprop("/controls/circuit-breakers/tands") ) {
        setprop("/systems/electrical/outputs/turn-coordinator", essential_bus_volts);
  load += 0.3;
    } else {
        setprop("/systems/electrical/outputs/turn-coordinator", 0.0);
    }

    # Fuel Lo Lev (0.5A)
    if ( getprop("/controls/circuit-breakers/fuel-lo-lev") ) {
        setprop("/systems/electrical/outputs/fuel-lo-lev", essential_bus_volts);
    } else {
        setprop("/systems/electrical/outputs/fuel-lo-lev", 0.0);
    }
    if ( getprop("/instrumentation/warning-panel/fuel-norm") > 0 ) {
  load += 0.02;
    }

    # Att Indic 1 (3A)
    if ( getprop("/controls/circuit-breakers/att-indic-1") ) {
        setprop("/systems/electrical/outputs/att-indic-1", essential_bus_volts);
  load += 0.6;
    } else {
        setprop("/systems/electrical/outputs/att-indic-1", 0.0);
    }

    # pop breaker if over current
    if ( load>15.0 ) {
        setprop("/controls/circuit-breakers/ess-bus",0);
    }

    # return cumulative load
    if ( getprop("/controls/circuit-breakers/ess-bus") ) { 
   setprop("/systems/electrical/debug/ess-load", load);
         setprop("/systems/electrical/debug/ess-volts", main_bus_volts);
  return load;
    } else {
   setprop("/systems/electrical/debug/ess-load", 0);
         setprop("/systems/electrical/debug/ess-volts", 0);
  return 0.0;
    };
}

avionic_bus_1 = func() {
    # fed from the "virtual" bus via the avionic bus 1 breaker (15A)
    if ( getprop("/controls/circuit-breakers/avionic-bus-1") ) {
      avionic_bus_1_volts = vbus_volts;
    } else {
  main_bus_volts = 0.0;
    } 

    load = 0.0;

    # Mute (3A)
    if ( getprop("/controls/circuit-breakers/mute") ) {
        setprop("/systems/electrical/outputs/mute", avionic_bus_1_volts);
    } else {
        setprop("/systems/electrical/outputs/mute", 0.0);
    }

    # HSI (3A)
    if ( getprop("/controls/circuit-breakers/hsi") ) {
        setprop("/systems/electrical/outputs/hsi", avionic_bus_1_volts / 2);
  load += 1.5;
    } else {
        setprop("/systems/electrical/outputs/hsi", 0.0);
    }

    # Alt Encoder (1A)
    if ( getprop("/controls/circuit-breakers/alt-encoder") ) {
        setprop("/systems/electrical/outputs/alt-encoder", avionic_bus_1_volts);
  load += 1.2;
    } else {
        setprop("/systems/electrical/outputs/alt-encoder", 0.0);
    }

    # Xpdr (3A)
    if ( getprop("/controls/circuit-breakers/xpdr") ) {
        setprop("/systems/electrical/outputs/xpdr", avionic_bus_1_volts);
  load += 0.1;
    } else {
        setprop("/systems/electrical/outputs/xpdr", 0.0);
    }

    # Nav1 (3A)
    if ( getprop("/controls/circuit-breakers/nav1") ) {
        setprop("/systems/electrical/outputs/nav1", avionic_bus_1_volts);
  load += 0.35;
    } else {
        setprop("/systems/electrical/outputs/nav1", 0.0);
    }

    # Com1 (10A)
    if ( getprop("/controls/circuit-breakers/com1") ) {
        setprop("/systems/electrical/outputs/com1", avionic_bus_1_volts);
  # Rx 0.6A
  # Tx 8A
  load += 0.6;
    } else {
        setprop("/systems/electrical/outputs/com1", 0.0);
    }

    # pop breaker if over current
    if ( load>15.0 ) {
        setprop("/controls/circuit-breakers/avionic-bus-1",0);
    }

    # return cumulative load
    if ( getprop("/controls/circuit-breakers/avionic-bus-1") ) { 
   setprop("/systems/electrical/debug/ab1-load", load);
         setprop("/systems/electrical/debug/ab1-volts", avionic_bus_1_volts);
  return load;
    } else {
   setprop("/systems/electrical/debug/ab1-load", 0);
         setprop("/systems/electrical/debug/ab1-volts", 0);
  return 0.0;
    };

}

avionic_bus_2 = func() {
    # fed from the "virtual" bus via the avionic bus 2 breaker (15A)
    if ( getprop("/controls/circuit-breakers/avionic-bus-2") ) {
      avionic_bus_2_volts = vbus_volts;
    } else {
  avionic_bus_2_volts = 0.0;
    } 

    load = 0.0;

    # GPS (3A)
    if ( getprop("/controls/circuit-breakers/gps") ) {
        setprop("/systems/electrical/outputs/gps", avionic_bus_2_volts);
  load +=1;
    } else {
        setprop("/systems/electrical/outputs/gps", 0.0);
    }

    # Com2/Nav2 (10A)
    if ( getprop("/controls/circuit-breakers/com2nav2") ) {
        setprop("/systems/electrical/outputs/com2nav2", avionic_bus_2_volts);
  # Rx 0.6A
  # Tx 6A
  load += 0.6;
    } else {
        setprop("/systems/electrical/outputs/com2nav2", 0.0);
    }

    # DME (3A)
    if ( getprop("/controls/circuit-breakers/dme") ) {
        setprop("/systems/electrical/outputs/dme", avionic_bus_2_volts);
  load += 0.55;
    } else {
        setprop("/systems/electrical/outputs/dme", 0.0);
    }

    # Audio Marker (3A)
    if ( getprop("/controls/circuit-breakers/audio-marker") ) {
        setprop("/systems/electrical/outputs/audio-marker", avionic_bus_2_volts);
  # Keep Instrumentation/marker_beacon.cxx happy
  setprop("/systems/electrical/outputs/nav", avionic_bus_2_volts);
  load += 0.5;
    } else {
        setprop("/systems/electrical/outputs/audio-marker", 0.0);
    }

    # Att Indic 2 (3A)
    if ( getprop("/controls/circuit-breakers/att-indic-2") ) {
        setprop("/systems/electrical/outputs/att-indic-2", avionic_bus_2_volts);
  load += 1;
    } else {
        setprop("/systems/electrical/outputs/att-indic-2", 0.0);
    }

    # pop breaker if over current
    if ( load>15.0 ) {
        setprop("/controls/circuit-breakers/avionic-bus-2",0);
    }

    # return cumulative load
    if ( getprop("/controls/circuit-breakers/avionic-bus-2") ) { 
  setprop("/systems/electrical/debug/ab1-load", load);
        setprop("/systems/electrical/debug/ab1-volts", avionic_bus_2_volts);
  return load;
    } else {
   setprop("/systems/electrical/debug/ab1-load", 0);
         setprop("/systems/electrical/debug/ab1-volts", 0);
  return 0.0;
    };

}

# Setup a timer based call to initialized the electrical system as
# soon as possible.
setlistener("/sim/signals/fdm-initialized",init_electrical);
