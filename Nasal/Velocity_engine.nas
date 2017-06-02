# Engine Management routines
#
# Gary Neely aka 'Buckaroo'
#
# Engine Management routines
#
# YASim's piston engine simulation is lacking, and really can't do well since so many variables and responses
# are engine specific. YASim's fuel consumption is typically higher than expected (a scalar of 0.7 gives
# passable low-fidelity results for some engines, but temperature values are hopeless or non-existent. YASim
# also reports manifold pressure in values that are much too low. JSBsim is better but not by a lot, allowing
# only the most basic engine parameters as inputs and giving results which at best may be in the ballpark but
# are hopeless to tune. Just look at the engine properties for the Flightgear flagship Cessna 172.
#
# Here I try a new approach to give more accurate fuel numbers and passably realistic EGT and CHT values.
# I calculate an air-fuel ratio (AFR) based on the engine specifications and possible factors like power
# enrichment and boost pumps, and use this to directly derive fuel consumption.
#
# To get EGT and CHT, I use the calculated AFR coupled with estimated power output to find values based on
# tabular inputs of known (or guessed at) EGT and CHT results. I don't try to simulate the actual process.
# The numbers can't be perfect because I need to create a relationship between YASim's functional engine
# settings and my mechanics, but with effort they can get pretty close to reasonable for most flight profiles.
# Since very few Flightgear piston planes give any meaningful EGT or CHT results, pretty close ain't bad.
#
# The goal is to generate meaningful numbers that pilots can use to simulate LOP/ROP operations. I really
# don't care if the numbers are off a little or even a lot-- the idea is to allow users to simulate real
# procedures with some expectation of suitable engine and fuel response results. Part of the idea of this
# strategy is that someone with real data can revise the tables and get numbers much closer to true.
#
# This scheme relies on 3 non-control engine values from YASim: torque-ftlb, RPM, and MP (modified). All
# other YASim engine values are ignored.
# 
# Some standard settings are in this nasal file, but most won't need to be changed for a given engine,
# provided that the engine is fairly conventional. The actual engine parameter settings should be placed
# in an XML file. Here I use:
#
#   Systems/Velocity-XL-RG-engine.xml
#
# See that file for a configuration example.
#
# Currently there are issues with AFRs in the very lean range (<0.06). This is mostly a problem at high
# altitudes (10000'+) where economy mixtures might be getting close to that range. Re-mapping mixture
# ranges or re-mapping AFRs at very lean mixture settings might resolve this, but it's a work in progress.
#
# This engine simulation could be applied to turbocharged engines, but I haven't explored that realm yet.
# The methods used here should be applicable to any conventional normally-aspirated piston engine,
# especially if you have numbers for the engine's performance.
#
# Version 1.2
#



var ENGINE_DATA		= "/sim/Velocity/engine/";		# Base location for engine data
var UPDATE_INTERVAL	= 0.2;					# Seconds. Set interval at largest value that gives reasonable
								# smooth instrument responses. Avoid using framerate (0 secs).

##############
# Interpolation tables used:
##############

var table_mix_ind	= [];					# mixture index values
var table_mix_opt	= [];					# corrected mixture dependent values
var table_afr		= [];					# Air-fuel ratio values
var table_egt		= [];					# EGT values
var table_cht		= [];					# CHT values
var table_cyldifs	= [];					# Cylinder EGT/CHT differential factors
var table_coolas	= [];					# CHT airspeed cooling index values
var table_cooldeg	= [];					# CHT airspeed cooling degrees
var table_dTas		= [];					# CHT airspeed cooldown index values
var table_dTdeg		= [];					# CHT airspeed cooldown degrees


##############
# Pre-fetch configuration data from engine configuration data
# and setup dependent values:
##############

var displacement_m3	= getprop(ENGINE_DATA~"displacement-in") * 0.0000164;	# inches to m^3
var vol_eff		= getprop(ENGINE_DATA~"volumetric-efficiency");
var cylinders		= getprop(ENGINE_DATA~"cylinders");
var cht_redline		= getprop(ENGINE_DATA~"cht-redline");
var thermal_eff		= getprop(ENGINE_DATA~"thermal-efficiency");
var HP_max		= getprop(ENGINE_DATA~"power-max");
var afr_base		= getprop(ENGINE_DATA~"afr-base");			# Unmodified full rich initial air-fuel ratio
var idle_min_inhg	= getprop(ENGINE_DATA~"idle-min-inhg");			# MP to seek at sea level idle
var MP_factor		= idle_min_inhg / getprop("/environment/pressure-sea-level-inhg");
var use_AMC		= getprop(ENGINE_DATA~"use-AMC");			# Automatic mixture control option
var use_AE		= getprop(ENGINE_DATA~"use-autoenrich");		# Autoenrich option
var AE_throttle_min	= getprop(ENGINE_DATA~"autoenrich-throttle-min");
var AE_gain		= getprop(ENGINE_DATA~"autoenrich-afr-gain");
var use_boostpump	= getprop(ENGINE_DATA~"use-boostpump");
var boostpump_gain	= getprop(ENGINE_DATA~"boostpump-afr-gain");
var use_cowlflaps	= getprop(ENGINE_DATA~"cowlflaps");
var EGT_max		= 0;
var EGT_min		= 0;
var EGT_dif		= 0;
var CHT_max		= 0;
var CHT_min		= 0;
var CHT_dif		= 0;
var timestamp		= [ 0 , 0 ];						# One for each engine
var DeltaTsecs		= 1.66;							# Seconds for CHT to change 1 degree when engine running

# Old version stuff for oil temps: Needs to be updated to use the engine configuration file,
# but I need to re-examine the calculation methods so I'm simply defining this stuff here:

var OILV_DELTA_WARMUP	= 0.001;						# Viscosity increment per cycle when warming up
var OILV_DELTA_COOLDN	= 0.0001;						# Viscosity decrement per cycle when cooling down
var MAX_OK_OILT		= 118;							# Maximum best oil temperature
var MIN_OK_OILT		= 60;							# Minimum best oil temperature
var MIN_OILP		= 25;							# Minimum acceptable oil pressure
var MAX_OILP		= 115;							# Highest value oil pressure will register
var MAX_OK_OILP		= 95;							# Maximum best oil pressure
var MIN_OK_OILP		= 55;							# Minimum best oil pressure
var oilt_target 	= (MAX_OK_OILT-MIN_OK_OILT)/2 + MIN_OK_OILT;		# Calculate a nice mid-range temp value to seek
var oilp_target 	= (MAX_OK_OILP-MIN_OK_OILP)/2 + MIN_OK_OILP;		# Calculate a nice mid-range pressure value to seek


##############
# Fahrenheit to Celsius:
##############

var CtoF = func (c) {
  return (1.8 * c) + 32;
}


##############
# Table interpolation:
# Interpolated look-up tables that work like the model animation 'interpolation' function
# Index table should be sorted ascending
#############

var interpolation_tables = func (x,ind,dep) {				# Index x, index table ind, dependent table dep
  if (size(ind) != size(dep)) {						# Both tables must have the same number of members
    print("Interpolation table size mis-match: check engine tables");
    return 0;
  }
  if (x <= ind[0]) { return dep[0]; }					# first element and out of range test
  if (x >= ind[size(ind)-1]) { return dep[size(dep)-1]; }		# Last element and out of range test
  for (var i=1; i<size(ind); i+=1) {
    if (x < ind[i]) {							# x is less than upper bound; Interpolate between
									# index values and apply ratio to dependent values
      return (x - ind[i-1])/(ind[i] - ind[i-1]) * (dep[i] - dep[i-1]) + dep[i-1];
    }
    if (x == ind[i]) {							# x matched upper bound
      return dep[i];
    }
  }
  return 0;								# Should never get here
}


#############
# Air density calculation:
# density = abs press (Pa) / (specific gas constant * abs temp (K))
# density (kg/m^3) = inHg * 3386.3886 / (287.058 * (273.15 + tempC))
#############

var get_air_density = func (inHg, tempC) {
  return inHg * 3386.3886 / (287.058 * (273.15 + tempC));
}


##############
# YASim manifold pressure fix:
# YASim idle MP is much too low, typically yielding AFR's way too rich to burn.
# Assuming no turbocharging, YASim calculates idle minimums of 0.092 * abs pressure.
# To allow YASim MP to drive engine settings, simply re-factor MP; not optimal but it works OK.
# Ex: re-factoring using 0.33 would get 10" idle minimum and bring AFR back to reasonable for idle.
# The actual re-factor value is automatically configured via XML by setting "idle_min_inhg".
##############

var fix_MP = func (eprop) {
  var MPold = getprop(eprop~"mp-osi");
  var inHg = getprop("/environment/pressure-inhg");
  var MPminOld = inHg * 0.092;						# Old minimum MP was 2.76" at SL
  var MPminNew = inHg * MP_factor;					# MP_factor was 0.33, now derived from engine XML settings
  var MP = ((MPold - MPminOld) / (inHg - MPminOld)) * (inHg - MPminNew) + (MPminNew);
  setprop(eprop~"mp-inhg-adj",MP);
  return MP;
}


##############
# Primary engine routine:
##############

var engine_update = func (i) {						# i = engine number
  var eprop = "/engines/engine["~i~"]/";				# Engine base property
  var ecprop = "/controls/engines/engine["~i~"]/";			# Engine controls base property

  if (getprop(eprop~"running") == 1) {					# Is engine running?

									# Alter YASim's linear mixture control range, otherwise low-end lean
									# settings go much too lean. This also aligns YASim's best-power setting
									# to this scheme. See notes in the configuration file.
    var mixture = getprop(ecprop~"mixture");
    mixture = interpolation_tables(mixture,table_mix_ind,table_mix_opt);
    setprop(eprop~"mix-adj",mixture);

									# Get the basics and calculate air mass:
    var throttle = getprop(ecprop~"throttle");
    var tempC = getprop("/environment/temperature-degc");
    var RPM = getprop(eprop~"rpm");
    var MP = fix_MP(eprop);						# Revise MP range
    var HP = RPM * getprop(eprop~"torque-ftlb") / 5252;			# HP guestimate, 5252 comes from standard equations for deriving HP

    var volume = displacement_m3 * RPM / 120;				# (Displacment * RPM / 60) / 2, volume moved per second (1 intake per 2 revs)
    var mass = volume * get_air_density(MP, tempC) * vol_eff;		# Ideal mass of air volume factored by volumetric efficiency, kg/m^3/s
									# VE probably should use a table rather than a single value
									# but I'm still fumbling through this, might get fancy later

									# Air-fuel ratio calculations:
									# Fuel injector metering: fuel flow is proportional to intake volume,
									# usually accomplished by a pressure differential between an impact tube
									# and a venturi (measuring change in velocity). A fuel servo adjusts fuel flow
									# for RPM changes to maintain AFR-- since I'm doing the reverse, using AFR to
									# arrive at fuel flow, no calculations are necessary to balance volume changes.

    var afr = afr_base;							# Air-fuel ratio begins at base rich setting
    if (use_boostpump) {						# Many boost pump scenarios will richen AFR a bit. This is one reason why you should
									# always take off using full open throttle. Boosting increases inlet pressure, so
									# do this before other calculations.
      if (getprop("/systems/electrical/outputs/fuelpump")) { 
        afr = afr + boostpump_gain;
      }
    }
    if (!use_AMC) {							# No auto mixture control means we must adjust for current density conditions;
									# most typical engines won't have AMC
      var density_sl = get_air_density(getprop("/environment/pressure-sea-level-inhg"), tempC);
      var density = get_air_density(getprop("/environment/pressure-inhg"), tempC);
      afr = afr * density_sl / density;					# AFR rises proportional to reduction in air density (mixture richens with altitude)
    }
    afr = afr * mixture;						# Mixture control reduces the size of the metered fuel jet
    if (use_AE and (throttle > AE_throttle_min)) {			# Auto-enrich option for higher power settings:
									# Kicks in at some minimum throttle position (ex: 0.65) (configured in XML)
									# Gain to AFR is linearly interpolated up to max throttle. This fuel jet is in
									# parallel with the main metered jet, so it is not affected by mixture control.
      afr = afr + AE_gain * (throttle - AE_throttle_min)/(1 - AE_throttle_min);
    }
    setprop(eprop~"afr",afr);

									# Calculate fuel flow:
    var ff_kgs = mass * afr;						# Unadjusted fuel flow; this works OK as-is, coming in pretty close to real values,
									# ff could be tweaked by passing it through an optional interpolation table
    var ff = ff_kgs * 1318.39;						# fuel flow, kgs to gph
    setprop(eprop~"fuel-flow-gph-adj",ff);
									# Fuel consumption:
    var time = getprop("/sim/time/elapsed-sec");			# Find how much time passed since last calculation,
    var dT = time - timestamp[i];						# multiply by fuel flow, and add to current fuel-consumed
    timestamp[i] = time;							# Nasal fuel routines will reset fuel-consumed after deducting fuel
    var consumed = 2.2046 * ff_kgs * dT;
    setprop(eprop~"fuel-consumed-lbs-adj",getprop(eprop~"fuel-consumed-lbs-adj") + consumed);
    

    var hp_percent = HP/HP_max;						# hp_percent is used only for instrument display, comment out
    if (hp_percent > 0.99) { hp_percent = 0.99; }			# these three lines if not needed
    setprop(eprop~"hp",hp_percent);

									# EGT and CHT values:

									# Fetch EGT and CHT data from tables
    var egt = interpolation_tables(afr,table_afr,table_egt);
    var cht_target = interpolation_tables(afr,table_afr,table_cht);
									# Adjust for power; HP is handy for this
    egt = (egt - EGT_min) * (HP/HP_max) + EGT_min;
    cht_target = (cht_target - CHT_min) * (HP/HP_max) + CHT_min;
									# CHT target should be modified by airspeed cooling effects
									# This is terribly crude and simplistic, but one
									# can get close to real values if real data is known
    var cht_target = cht_target - interpolation_tables(getprop("/velocities/airspeed-kt"),table_coolas,table_cooldeg);
    #if (use_cowlflaps) {						# Temperature mods for cowlflaps (for future use)
    #}
									# CHT needs time to move to target temp
									# This needs work, might be better if deltaT increases with spread
									# between current temp and target temp rather than a constant deltaT
    interpolate(eprop~"chttempf", cht_target, abs(cht_target - getprop(eprop~"chttempf"))*DeltaTsecs);
    setprop(eprop~"egttempf",egt);					# EGT changes are effectively immediate

									# Setting cylinder variances:
									# This stuff is optional for radials but essential for in-lines,
									# even those with GAMIjectors:

    var egt_norm = (egt - EGT_min) / EGT_dif;				# Normalize engine base temps to max/min range
    var cht_norm = (getprop(eprop~"chttempf") - CHT_min) / CHT_dif;
    if (cht_norm < 0) { cht_norm = 0; }					# Essentially establishes a minimum reporting value (CHT would read
									# lower until engine warms up)
    for(var j=0; j<cylinders; j+=1) {					# Use cylinder differential table to vary temps for all cylinders
									# Result is normalized for animations
      setprop(eprop~"cyl["~j~"]/egt",egt_norm*table_cyldifs[j]);
      setprop(eprop~"cyl["~j~"]/cht",cht_norm*table_cyldifs[j]);
									# Set flag to indicate CHT is in the red zone
      setprop(eprop~"cyl["~j~"]/cht-redline",getprop(eprop~"chttempf")*table_cyldifs[j]>cht_redline?1:0);
    }



									# Simplified oil temp, viscosity, pressure
									# Note that viscosity is a dimensionless normalized value,
									# not a true viscosity number
    var oilv = getprop(eprop~"oil-visc");
    if (oilv > 0) {
      oilv = oilv - OILV_DELTA_WARMUP;					# Determine new oilv as necessary
      setprop(eprop~"oil-visc",oilv);					# Save viscosity
      var oilp = ((MAX_OILP - oilp_target) * oilv) + oilp_target;	# Viscosity determines position between max oilp and target best oilp
      setprop(eprop~"oil-press",oilp);					# Save oilp, probably not necessary to interpolate
									# Oilt rises from ambient as viscosity falls
      var envtemp = getprop("/environment/temperature-degc");
      var oilt = (oilt_target - envtemp) * (1-oilv) + envtemp;
      setprop(eprop~"oiltempc",oilt);					# Save oilt as deg C
    }

									# For prop animation, to get rid of at-rest windmilling
    setprop(eprop~"rpm-anim", getprop(eprop~"rpm"));
  }
  else {								# Engine not running
									# Return MP to environment
    var env = getprop("/environment/pressure-inhg");
    interpolate(eprop~"mp-inhg-adj",env,2*(env - getprop(eprop~"mp-inhg-adj"))/(env - 10));
									# CHT cooldown
    var cht_target = CtoF(getprop("/environment/temperature-degc"));
    var dT = interpolation_tables(getprop("/velocities/airspeed-kt"),table_dTas,table_dTdeg);
    interpolate(eprop~"chttempf", cht_target, abs(cht_target - getprop(eprop~"chttempf"))*dT);

									# Oil cool-down; see main oil section for notes
    var oilv = getprop(eprop~"oil-visc");
    var envtemp = getprop("/environment/temperature-degc");
    var oilt = (oilt_target - envtemp) * (1-oilv) + envtemp;
    setprop(eprop~"oiltempc",oilt);					# Save oilt as deg C
    if (oilv < 1) {
      var oilp = ((MAX_OILP - oilp_target) * oilv) + oilp_target;
      setprop(eprop~"oil-press",oilp);
      setprop(eprop~"oil-visc",oilv + OILV_DELTA_COOLDN);
    }
									# For prop animation, simple fix
									# to get rid of at-rest windmilling.
									# It takes about 80-90 kts of wind to start the
									# prop windmilling, but this covers ground cases
									# up to 30 kts or so, good enough for cosmetics.

    var rpm = getprop(eprop~"rpm");
    if (rpm < 30) {
      setprop(eprop~"rpm-anim", 0);
    }
    else {
      setprop(eprop~"rpm-anim", rpm);
    }
  } # end engines-not-running
}


##############
# Master engine loop:
##############

var engine_loop = func {
  engine_update(0);
  engine_update(1);
  settimer(engine_loop, UPDATE_INTERVAL);
}



##############
# Initialization:
##############

var engine_setup = func {
									# Load engine data tables
  var table = {};
  table = props.globals.getNode("/sim/Velocity/engine/table-mixture-correction").getChildren("mix");
  for(var i=0; i<size(table); i+=1) {
    append(table_mix_ind,table[i].getNode("mix-ind").getValue());
    append(table_mix_opt,table[i].getNode("mix-opt").getValue());
  }

  table = props.globals.getNode(ENGINE_DATA~"table-temps").getChildren("temps");
  for(var i=0; i<size(table); i+=1) {
    append(table_afr,table[i].getNode("afr").getValue());
    append(table_egt,table[i].getNode("egt").getValue());
    append(table_cht,table[i].getNode("cht").getValue());
    if (table_cht[i] > CHT_max) { CHT_max = table_cht[i]; }		# Determine maximum values
    if (table_egt[i] > EGT_max) { EGT_max = table_egt[i]; }
  }
  CHT_min = table_cht[0];						# Min values should be approx lean power limit
  EGT_min = table_egt[0];
  CHT_dif = CHT_max - CHT_min;						# High - low differentials, precalulating these
  EGT_dif = EGT_max - EGT_min;						# saves a calculation in main engine loop

  table = props.globals.getNode(ENGINE_DATA~"table-aircooling").getChildren("aircooling");
  for(var i=0; i<size(table); i+=1) {
    append(table_coolas,table[i].getNode("kias").getValue());
    append(table_cooldeg,table[i].getNode("degrees").getValue());
  }

  table = props.globals.getNode(ENGINE_DATA~"table-dT-cooldown").getChildren("aircooling");
  for(var i=0; i<size(table); i+=1) {
    append(table_dTas,table[i].getNode("kias").getValue());
    append(table_dTdeg,table[i].getNode("degrees").getValue());
  }

  table = props.globals.getNode(ENGINE_DATA~"table-cyldifs").getChildren("difs");
  for(var i=0; i<size(table); i+=1) {
    append(table_cyldifs,table[i].getNode("egt").getValue());
  }

									# Set engines to ambient temp on startup
  var envtemp = getprop("/environment/temperature-degc");
  setprop("/engines/engine[0]/egttempf",CtoF(envtemp));
  setprop("/engines/engine[0]/chttempf",CtoF(envtemp));
  setprop("/engines/engine[0]/oiltempc",envtemp);
  setprop("/engines/engine[1]/egttempf",CtoF(envtemp));
  setprop("/engines/engine[1]/chttempf",CtoF(envtemp));
  setprop("/engines/engine[1]/oiltempc",envtemp);

  engine_loop();							# Initiate the update loop
}


var EngineInit = func {
  settimer(engine_setup, 1);						# Give a few seconds for environment vars to initialize
									# Could probably use setlistener("/sim/signals/fdm-initialized"...) for this
}
