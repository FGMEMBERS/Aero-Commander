# Velocity XL RG
#
# Gary Neely aka 'Buckaroo'
#
# Fuel Update routines
#
# The Velocity XL has two 33 gallon tanks located in the strakes (inboard wing segments forward of the spar),
# and a 4 gallon sump tank located just forward of the firewall. The default factory setup is a simple system
# that has the two tanks feeding the sump with no control valves. As some inspections require an emergency fuel
# shutoff valve and it's often useful to be able to balance tank loads, I've incorporated a slightly more complex
# system that provides a shutoff position and allows feeding from one or both tanks. This setup is used on many
# real Velocities.
#
# Fuel tanks are ordered as follows:
#   0 - sump
#   1 - left
#   2 - right
#
# Tank selection switch values:
#  -1 - cutoff
#   0 - both
#   1 - left
#   2 - right
#
# Consumed fuel is always deducted from the sump. The consumed amount is then replenished from the selected tanks.
# The sump itself has 2.5 usable gallons, so anything under 1.5 gallons is considered out of fuel.
#
# IO-540-K full power fuel flow should get 24-25 GPH; YASim's is around 34 GPH. I calculate fuel flow using
# custom non-FDM engine management routines. See Velocity_engine.nas for more information.
# Dependent systems should use 'fuel-flow-gph-adj' rather than YASim's 'fuel-flow-gph'.
#
# Some necessary properties are defined in:
#
#   Systems/Velocity-XL-RG-engine.xml
#
# See that file for a configuration example.
#
# Standard fuel densities:
# JetA 6.72 (6.47-7.01) lb/gal, 0.775-0.840 kg/l @15C
# Avgas 6.02 lb/gal, 0.721 kg/l @15C
#
# Note that as of FG 2.4, fuel density is now handled by core Flightgear procedures. I work with the fuel pounds
# properties and allow the core handlers to update fuel volume (gallons).


var FUEL_UPDATE		= 0.3;						# Update interval in secs for main fuel routine
var FUEL_UPDATE_LONG	= 10;						# Update interval if fuel state frozen
var PPG			= 6.0;						# Standard fuel density
var MAX_TANKS		= 1;						# Standard tanks to consider, 0..MAX_TANKS
var MIN_SUMP		= 1.5;						# Minimum sump qty before considered unusable

var tank_list		= [];
var engine		= nil;
var fuel_freeze		= nil;
var total_gals		= nil;
var total_lbs		= nil;
var total_norm		= nil;

var selected_tank	= props.globals.getNode("/controls/fuel/selected-tank");
var fuel_pump		= props.globals.getNode("/systems/electrical/outputs/fuelpump");
var HP_MAX		= getprop("/sim/Velocity/engine/power-max");
var PRESSURE_MAX	= getprop("/sim/Velocity/engine/fuel-pressure-max");
var PRESSURE_IDLE	= getprop("/sim/Velocity/engine/fuel-pressure-idle");
var PRESSURE_MIN	= getprop("/sim/Velocity/engine/fuel-pressure-min");
var PRESSURE_BOOST	= getprop("/sim/Velocity/engine/fuel-pressure-boost");



									# Calculate a reasonable target fuel pressure given
var get_target_fuel_pressure = func {					# engine output and boost pump status 
  var pressure_target = 0;
  var hp_factor = engine.getNode("hp").getValue() / HP_MAX;		# Simple engine output factor for fuel pressure
  if (fuel_pump.getValue() and engine.getNode("running").getValue()) {
    var press_min = PRESSURE_IDLE + PRESSURE_BOOST * 0.1;		# The low end is kinda speculative
    var press_max = PRESSURE_MAX + PRESSURE_BOOST;
    pressure_target = (press_max - press_min) * hp_factor + press_min;
  }
  else {
    pressure_target = (PRESSURE_MAX - PRESSURE_IDLE) * hp_factor + PRESSURE_IDLE;
  }
  return pressure_target;
}



var fuel_update_loop = func {						# Subtract consumed fuel from tanks

  if (fuel_freeze) {							# Fuel simulation frozen, engines consume no fuel
    engine.getNode("fuel-consumed-lbs").setDoubleValue(0);		# Reset engine's consumed fuel
    settimer(fuel_update_loop, FUEL_UPDATE_LONG);			# Update leisurely
    return 0;
  }

  var selected = selected_tank.getValue();				# Get tank selection & fuel cutoff status

									# Fuel pressure:
									# A Lycoming 540 has a mechanical pump and an electric boost pump.
									# The mechanical pump is always on (unless it fails), and the
									# electric pump is effectively a back-up, but is required for
									# cold-start priming of the system (and sometimes hot starts).

  var fp = engine.getNode("fuel-press").getValue();
  if (fp > 0) {								# Fuel pressure present:
									# Kill pressure if fuel off
    if (selected == -1) {
      interpolate(engine.getNode("fuel-press"), 0, (fp/PRESSURE_MAX) * 10);
    }
									# Kill pressure if sump tank is empty of usable fuel
    elsif (tank_list[0].getChild("level-gal_us").getValue() < MIN_SUMP ) {
      interpolate(engine.getNode("fuel-press"), 0, (fp/PRESSURE_MAX) * 10);
    }
									# Kill pressure if no pumps active
    elsif (!fuel_pump.getValue() and !engine.getNode("running").getValue()) {
      interpolate(engine.getNode("fuel-press"), 0, (fp/PRESSURE_MAX) * 45);
    }
    else {								# All good, maintain pressure
      var pressure_target = get_target_fuel_pressure();
      interpolate(engine.getNode("fuel-press"), pressure_target, abs(pressure_target - fp)/pressure_target * 3);
    }
  }
  else {								# No fuel pressure:
									# Pressurize fuel if fuel present and 1+ pump active
    if (selected > -1 and
        tank_list[0].getChild("level-gal_us").getValue() >= MIN_SUMP and
        (fuel_pump.getValue() or engine.getNode("running").getValue())) {
      var pressure_target = get_target_fuel_pressure();
      interpolate(engine.getNode("fuel-press"), pressure_target, abs(pressure_target - fp)/pressure_target * 3);
    }
  }



									# Fuel consumption:

  if (engine.getNode("fuel-press").getValue() < PRESSURE_MIN) {		# No fuel pressure
    engine.getNode("out-of-fuel").setBoolValue(1);			# Kill engine
  }
  elsif (selected == -1) {						# Switch set to fuel cutoff position
    engine.getNode("out-of-fuel").setBoolValue(1);			# Kill engine
  }
  else {								# Attempt to draw fuel from a tank:
    var consumed = engine.getNode("fuel-consumed-lbs-adj").getValue();
									# Get sump's initial fuel load in lbs:
#    var sump_lbs = tank_list[0].getChild("level-gal_us").getValue() * PPG;
    var sump_lbs = tank_list[0].getChild("level-lbs").getValue();
									# Update engine's OOF status based on fuel pressure
    if (engine.getNode("out-of-fuel").getValue() and
        sump_lbs > 0 and
        engine.getNode("fuel-press").getValue() >= PRESSURE_MIN) {
      engine.getNode("out-of-fuel").setBoolValue(0);			# Reset fueled status
    }

    if (engine.getNode("running").getValue()) {
      var satisfied = 0;						# Value of 1 will indicate engine's fuel needs met

									# Subtract consumed fuel from sump. We might get a little freebie fuel
									# usage when a tank is almost empty, but it will be very small.
      sump_lbs -= consumed;
      if (sump_lbs >= MIN_SUMP) {					# Test for sump level at or above minimum
        satisfied = 1;							# If so, fuel usage was satisfied
      }
      if (!satisfied) {							# Engine's fuel needs met?
        engine.getNode("out-of-fuel").setBoolValue(1);			# If not, kill engine
      }
									# Now let's try to feed the sump
									# Build list of selected non-sump tanks having fuel remaining
      var fueled_tanks = [];
      if (tank_list[1].getChild("level-lbs").getValue() > 0 and (selected==1 or selected==0)) { append(fueled_tanks,1); }
      if (tank_list[2].getChild("level-lbs").getValue() > 0 and (selected==2 or selected==0)) { append(fueled_tanks,2); }
    
									# Replenish sump from tanks having fuel
      var fueled = size(fueled_tanks);					# Number of tanks having fuel
      for(var i=0; i<fueled; i+=1) {					# Foreach tank having fuel
        var portion = consumed / fueled;				# Divide fuel into portions to distribute evenly
        sump_lbs += portion;						# Add portion to sump
        var tank = fueled_tanks[i];					# Tank ID
#        var tank_lbs = tank_list[tank].getChild("level-gal_us").getValue() * PPG;
        var tank_lbs = tank_list[tank].getChild("level-lbs").getValue();
        tank_lbs -= portion;						# Deduct portion from tank qty
        if (tank_lbs < 0) {
          tank_lbs = 0;
        }
									# Update tank properties
#        tank_list[tank].getChild("level-gal_us").setDoubleValue(tank_lbs/PPG);
        tank_list[tank].getChild("level-lbs").setDoubleValue(tank_lbs);

      }
									# Update sump properties
#      tank_list[0].getChild("level-gal_us").setDoubleValue(sump_lbs/PPG);
      tank_list[0].getChild("level-lbs").setDoubleValue(sump_lbs);

    } # if engine running
  } # fuel draw routines
  engine.getNode("fuel-consumed-lbs-adj").setDoubleValue(0);		# Reset engine's consumed fuel

									# Total fuel properties
  var lbs = 0;
  var gals = 0;
  var cap = 0;
  for(var i=0; i<=MAX_TANKS; i+=1) {
    lbs += tank_list[i].getNode("level-lbs").getValue();
    gals += tank_list[i].getNode("level-gal_us").getValue();
    cap += tank_list[i].getNode("capacity-gal_us").getValue();
  }
  total_lbs.setDoubleValue(lbs);
  total_gals.setDoubleValue(gals);
  total_norm.setDoubleValue(gals / cap);				# Capacity will never reasonably be 0

  settimer(fuel_update_loop, FUEL_UPDATE);				# You go back, Jack, do it again...
}



var fuel_startup = func {
									# Deal with fuel menu select boxes
									# Note that these are not cutoff valves;
									# Listeners are used to re-enable oof status
									# if the user plays with the selection boxes

  var tank0_select	= props.globals.getNode("/consumables/fuel/tank[0]/selected");
  var tank1_select	= props.globals.getNode("/consumables/fuel/tank[1]/selected");
  var tank2_select	= props.globals.getNode("/consumables/fuel/tank[2]/selected");
  
  setlistener(tank0_select, func {
    if (tank0_select.getValue() or tank1_select.getValue() or tank2_select.getValue()) { engine.getNode("out-of-fuel").setBoolValue(0); }
  });
  setlistener(tank1_select, func {
    if (tank0_select.getValue() or tank1_select.getValue() or tank2_select.getValue()) { engine.getNode("out-of-fuel").setBoolValue(0); }
  });
  setlistener(tank2_select, func {
    if (tank0_select.getValue() or tank1_select.getValue() or tank2_select.getValue()) { engine.getNode("out-of-fuel").setBoolValue(0); }
  });

  fuel_update_loop();							# Initiate fuel update sequence
}


									# Support for clean property initialization
									# For backward compatibility; FG 2+ has a better method
var init_double_prop = func(node, prop, val) {
  if (node.getNode(prop) != nil) {
    val = num(node.getNode(prop).getValue());
  }
  node.getNode(prop,1).setDoubleValue(val);
}


var FuelInit = func {
  fuel.update = func{};							# Remove default fuel fuel system
									# Listen for sim suspended fuel usage toggle
  setlistener("/sim/freeze/fuel", func(n) { fuel_freeze = n.getBoolValue() }, 1);
  									# Set up fuel summary properties
  total_gals = props.globals.getNode("/consumables/fuel/total-fuel-gals",1);
  total_lbs = props.globals.getNode("/consumables/fuel/total-fuel-lbs",1);
  total_norm = props.globals.getNode("/consumables/fuel/total-fuel-norm",1);
									# Set up fuel-related engine properties
  engine = props.globals.getNode("engines/engine[0]");
  engine.getNode("fuel-consumed-lbs",1).setDoubleValue(0);
  engine.getNode("out-of-fuel",1).setBoolValue(1);			# Begin with engines shutdown

									# Fetch the tank list:
  tank_list = props.globals.getNode("/consumables/fuel",1).getChildren("tank");
									# Set up tank properties
									# We only need to deal with the tanks that matter (0-MAX_TANKS),
									# the rest are FDM zombie tanks
  for(var i=0; i<=MAX_TANKS; i+=1) {
    init_double_prop(tank_list[i], "level-gal_us", 0);
    init_double_prop(tank_list[i], "level-lbs", 0);
    init_double_prop(tank_list[i], "capacity-gal_us", 0.01);		# Not zero (div/zero issue)
#    init_double_prop(tank_list[i], "density-ppg", PPG);
    if (tank_list[i].getNode("selected") == nil)			# This value should always be true
      tank_list[i].getNode("selected",1).setBoolValue(1);
  }

  settimer(fuel_startup, 2);						# Delay startup a bit to allow things to initialize
}

