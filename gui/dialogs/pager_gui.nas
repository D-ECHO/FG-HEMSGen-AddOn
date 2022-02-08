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

var (width,height) = (512, 300);
var title = 'HEMSGen GUI';

var font_mapper = func(family, weight) {
	return "lcd.txf";
};
var canvas_objects = {};

var update_light_timer = nil;
var click = nil;

var window = nil;

var this_addon = hemsgen.this_addon;

var showDialog = func( code, pos ) {

	# create a new window, dimensions are WIDTH x HEIGHT, using the dialog decoration (i.e. titlebar)
	window = canvas.Window.new([width,height],"hemsgen_dialog").set('title',title);


	##
	# the del() function is the destructor of the Window
	# which will be called upon termination (dialog closing)
	# you can use this to do resource management (clean up timers, listeners or background threads)
	window.del = func() {
		print("Cleaning up window:",title,"\n");
		# explanation for the call() technique at: http://wiki.flightgear.org/Object_oriented_programming_in_Nasal#Making_safer_base-class_calls
		call(canvas.Window.del, [], me);
	};

	# adding a canvas to the new window and setting up background colors/transparency
	var thisCanvas = window.createCanvas().set("background", canvas.style.getColor("bg_color"));

	# Using specific css colors would also be possible:
	thisCanvas.set("background", "#ffaac0");

	# creating the top-level/root group which will contain all other elements/group
	var root = thisCanvas.createGroup();
	
	var svg_group = thisCanvas.createGroup();
	
	canvas.parsesvg(svg_group, this_addon.resourcePath("gui/dialogs/pager_gui.svg"), {'font-mapper': font_mapper});
	
	var my_keys = [ "text.alarm", "text.line1", "text.line2", "annun_light", "button.accept"];
		 
	foreach(var key; my_keys) {
		canvas_objects[ key ] = svg_group.getElementById(key);
	}
	
	canvas_objects[ "text.line1" ].setText( code );
	canvas_objects[ "text.line2" ].setText( "LON "~ sprintf("%5.3f", pos.lon() ) ~" LAT "~ sprintf("%5.3f", pos.lat() ) );
	
	update_light_timer.start();
	
	canvas_objects[ "button.accept" ].addEventListener("click", func click( "accept" ));
	
}

var closeDialog = func() {
	if( window != nil ){
		window.del();
		window = nil;
	}
}

var light_state = 0;

click = func( button ){
	if( button == "accept" ){
		update_light_timer.stop();
		light_state = 1;
		update_light();
		hemsgen_radio_gui.showDialog();
		settimer( closeDialog, 5 );
	}
}

var update_light = func() {
	light_state = !light_state;
	if( light_state == 1 ){
		canvas_objects[ "annun_light" ].setColorFill( 1, 0.1, 0.1 );
	} else {
		canvas_objects[ "annun_light" ].setColorFill( 0.2, 0.2, 0.2 );
	}
}
update_light_timer = maketimer( 0.5, update_light );
update_light_timer.simulatedTime = 1;
	
