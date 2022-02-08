#This file is part of FlightGear.
#
#FlightGear is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 2 of the License, or
#(at your option) any later version.
#
#FlightGear is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with FlightGear.  If not, see <http://www.gnu.org/licenses/>.

#	Main GUI Dialog for this addon

var (width,height) = (318, 698);
var title = 'Radio GUI';

var font_mapper = func(family, weight) {
	return "lcd.txf";
};
var canvas_objects = {};

var update_light_timer = nil;
var click = nil;

var window = nil;

var this_addon = hemsgen.this_addon;

var status_code = props.globals.initNode("/addons/by-id/org.flightgear.addons.HEMSGen/radio/status", 2, "INT");



var showDialog = func(  ) {

	# create a new window, dimensions are WIDTH x HEIGHT, using the dialog decoration (i.e. titlebar)
	window = canvas.Window.new([width,height],"hemsgen_dialog").set('title',title);


	##
	# the del() function is the destructor of the Window
	# which will be called upon termination (dialog closing)
	# you can use this to do resource management (clean up timers, listeners or background threads)
	#window.del = func()
	#{
	#  print("Cleaning up window:",title,"\n");
	# explanation for the call() technique at: http://wiki.flightgear.org/Object_oriented_programming_in_Nasal#Making_safer_base-class_calls
	#  call(canvas.Window.del, [], me);
	#};

	# adding a canvas to the new window and setting up background colors/transparency
	var thisCanvas = window.createCanvas().set("background", canvas.style.getColor("bg_color"));

	# Using specific css colors would also be possible:
	thisCanvas.set("background", "#ffffff");

	# creating the top-level/root group which will contain all other elements/group
	var root = thisCanvas.createGroup();
	
	root.createChild("image").set("src", this_addon.resourcePath("gui/dialogs/handheld_radio.jpg") ).set("size[0]", width).set("size[1]", height);
	
	var svg_group = thisCanvas.createGroup();
	canvas.parsesvg(svg_group, this_addon.resourcePath("gui/dialogs/radio_gui.svg"), {'font-mapper': font_mapper});
	
	var my_keys = [ "text.status", "click.1", "click.2", "click.3", "click.4", "click.5", "click.6", "click.7", "click.8", "click.9", "click.0" ];
		 
	foreach(var key; my_keys) {
		canvas_objects[ key ] = svg_group.getElementById(key);
	}
	
	canvas_objects[ "text.status" ].setText( "Status " ~ status_code.getIntValue() );
	#canvas_objects[ "text.line2" ].setText( "LON "~ sprintf("%5.3f", pos.lon() ) ~" LAT "~ sprintf("%5.3f", pos.lat() ) );
	
	#update_light_timer.start();
	
	canvas_objects[ "click.1" ].addEventListener("click", func click( 1 ));
	canvas_objects[ "click.2" ].addEventListener("click", func click( 2 ));
	canvas_objects[ "click.3" ].addEventListener("click", func click( 3 ));
	canvas_objects[ "click.4" ].addEventListener("click", func click( 4 ));
	canvas_objects[ "click.5" ].addEventListener("click", func click( 5 ));
	canvas_objects[ "click.6" ].addEventListener("click", func click( 6 ));
	canvas_objects[ "click.7" ].addEventListener("click", func click( 7 ));
	canvas_objects[ "click.8" ].addEventListener("click", func click( 8 ));
	canvas_objects[ "click.9" ].addEventListener("click", func click( 9 ));
	canvas_objects[ "click.0" ].addEventListener("click", func click( 0 ));
	
	settimer( func () {canvas_objects[ "text.status" ].setText( "Status " ~ status_code.getIntValue() ) }, 0.1 );
}

var closeDialog = func() {
	if( window != nil ){
		window.del();
		window = nil;
	}
}

setlistener( status_code, func() {
	if( status_code == nil ) { return; }
	
	canvas_objects[ "text.status" ].setText( "Status " ~ status_code.getIntValue() or 0 );
	
	var status = status_code.getIntValue();
	if( status == 3 ){
		hemsgen.start_guide();
	} elsif( status == 4 ){
		hemsgen.appr_eval();
	}
});
	
var light_state = 0;

click = func( button ){
	if( isnum(button) ){
		status_code.setIntValue( button );
	}
}
