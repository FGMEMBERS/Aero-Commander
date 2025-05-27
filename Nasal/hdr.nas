###########################################################################
##                           HDR detection                               ##
##                                                                       ##
## Thx to : Sergei "Skydive" Solyshko                                    ##
###########################################################################

props.globals.initNode("/sim/rendering/hdr/hdr-enabled", 0, "BOOL");

var myListener = setlistener("sim/signals/fdm-initialized", func
{
  ###########################################################################
  var hdr = getprop("/sim/rendering/default-compositor");
  if ( hdr == "Compositor/HDR/hdr" and hdr != nil) {
    setprop("/sim/rendering/hdr/hdr-enabled", 1);
  } else {
    setprop("/sim/rendering/hdr/hdr-enabled", 0);
  }
  removelistener(myListener);
}, 0, 0);
