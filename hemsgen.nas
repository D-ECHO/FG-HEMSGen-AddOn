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

#	Set up properties
var addon_settings = props.globals.getNode("/addons/by-id/org.flightgear.addons.HEMSGen/settings");
var min_dist_km = addon_settings.getNode("min-distance-km");
var max_dist_km = addon_settings.getNode("max-distance-km");
var type_probability = addon_settings.getNode("type-probability");
var guide_interval = addon_settings.getNode("guide-interval");

var this_addon =  addons.getAddon("org.flightgear.addons.HEMSGen");

#	Library of Models to use
io.load_nasal( this_addon.basePath ~ "/model-resources.nas", "hemsgen" );

var get_model = func( vector, path = "" ) {
	var random = rand();
	random = math.round( random * (size(vector) - 1) );
	# print( random );
	var el = vector[ random ];
	
	while( io.stat( getprop("/sim/fg-root") ~ "/" ~ path ~ el ) == nil and io.stat( getprop("/sim/terrasync/scenery-dir") ~ "/" ~ path ~ el ) == nil and random < size(vector)-1 ){
		print( path ~ el ~" does not exist, testing next entry!" );
		random += 1;
		el = vector[ random ];
	}
	
	return path ~ el;
}

var unload = func() {
	var m = pop( response.models );
	while( m != nil ){
		m.remove();
		m = pop( response.models );
	}
}

var response = {
	site: nil,
	type: nil,	# 0 = water, 1 = road, 2 = railway, 3 = city, 4 = farmland, 5 = other land
	code: "",
	diagnosis: "",
	models: [],
	appr_eval_done: 0,
};

# Model class, derived from ufo.nas
var init_prop = func(prop, value) {
	if (prop.getValue() != nil)
		value = prop.getValue();

	prop.setDoubleValue(value);
	return value;
}
var Model = {
	new : func(path, pos, hdg, pitch, roll) {
		var m = { parents: [Model] };
		m.pos = pos;
		m.path = path;
		m.selected = 1;
		m.visible = 1;

		var models = props.globals.getNode("/models", 1);
		for (var i = 0; 1; i += 1) {
			if (models.getChild("model", i, 0) == nil) {
				m.node = models.getChild("model", i, 1);
				break;
			}
		}

		m.node.getNode("legend", 1).setValue("");

		m.node.getNode( "path", 1).setValue(path);
		m.node.getNode( "latitude-deg", 1 ).setValue( pos.lat() );
		m.node.getNode( "longitude-deg", 1 ).setValue( pos.lon() );
		m.node.getNode( "elevation-ft", 1 ).setValue( pos.alt() * M2FT );
		m.node.getNode( "heading-deg", 1 ).setValue( hdg );
		m.node.getNode( "pitch-deg", 1 ).setValue( pitch );
		m.node.getNode( "roll-deg", 1 ).setValue( roll );
		m.node.getNode( "load", 1).remove();
		return m;
	},
	remove : func {
		me.node.remove();
	},
};

var guide_loop = func() {
	if( response.site == nil or response.type == nil ) { 
		guide_loop_timer.stop();
		return;
	}
	
	var current_pos = geo.aircraft_position();
	
	var course = current_pos.course_to( response.site );
	
	var distance = current_pos.distance_to( response.site );
	
	screen.log.write( "Fly heading "~ math.round( course, 10 ) ~ ", "~ sprintf("%5.2f", distance/1000) ~ "km to go");
	
	if( distance < 300 or response.appr_eval_done ){
		screen.log.write( "You should be able to see the response site now" );
		guide_loop_timer.stop();
	}
}

var guide_loop_timer = nil;

var newPosition = func() {
	print("1");
	# Reset
	print("1.1");
	response.appr_eval_done = 0;
	print("1.2");
	hemsgen_pager_gui.closeDialog();
	print("1.3");
	hemsgen_radio_gui.closeDialog();
	
	print("2");
	if( response.site != nil ){
		var m = pop( response.models );
		while( m != nil ){
			m.remove();
			m = pop( response.models );
		}
	}
	
	print("3");
	var min_dist = min_dist_km.getIntValue();
	var max_dist = max_dist_km.getIntValue();
	
	if( max_dist < min_dist ){
		screen.log.write("Maximum distance is smaller than minimum distance, setting to minimum distance + 5");
		max_dist = min_dist + 5;
	}
	print("4");
	
	if( rand() < type_probability.getDoubleValue() ){
		# Determine site normally
		# print( "Mode 1" );	# Debug
		
		var once = 0;
		while( once == 0 or geodinfo( response.site.lat(), response.site.lon() ) == nil ){
			once = 1;
			response.site = geo.aircraft_position().apply_course_distance( rand() * 360, 1000 * ( min_dist + rand() * ( max_dist - min_dist ) ) );
		}
	} else {
		# Look specificially for Roads and Railroads
		# print( "Mode 2" );	# Debug
		var class = "";
		var n = 0;
		while( class != "Asphalt" and class != "Freeway" and left( class, 4 ) != "Road" and class != "Railroad" and n < 5000 ) {
			n += 1;
			response.site = geo.aircraft_position().apply_course_distance( rand() * 360, 1000 * ( min_dist + rand() * ( max_dist - min_dist ) ) );
			if( geodinfo( response.site.lat(), response.site.lon() ) != nil and geodinfo( response.site.lat(), response.site.lon() )[1] != nil ){
				class = geodinfo( response.site.lat(), response.site.lon() )[1].names[0];
			} else {
				class = "";
				n -= 1;
			}
		}
	}
			
	
	if( response.site.lat() == nil or response.site.lon() == nil ) { return; }
	
	# Debug
	# print( response.site.lat() );
	# print( response.site.lon() );
	
	var site_info =  geodinfo( response.site.lat(), response.site.lon() )[1];
	
	var site_class = site_info.names[0];	# only use the first possible landclass for now
	
	if( site_class == "Ocean" or site_class == "Lake" or site_class == "River" ){
		response.type = 0;
	} elsif( site_class == "Asphalt" or site_class == "Freeway" or left( site_class, 4 ) == "Road" ){
		response.type = 1;
	} elsif( site_class == "Railroad" ){
		response.type = 2;
	} elsif( site_class == "Urban" or site_class == "BuiltUp" or site_class == "Town" ){
		response.type = 3;
	} elsif( find( "Crop", site_class ) != -1 ){
		response.type = 4;
	} else {
		response.type = 5;
	}
	response.site.set_alt( geo.elevation( response.site.lat(), response.site.lon() ) );
	
	#	Populate the scene so it's easier to find
	if( response.type == 0 ){
		# Assume: Ship in distress
		response.code = "SHIP IN DISTRESS";
		append( response.models, Model.new( get_model( ships, "Models/Maritime/Civilian/" ), response.site, rand()*360, 0, 0 ) );
	} elsif( response.type == 1 ){
		# Assume: Car accident
		response.code = "TRAFFIC ACCIDENT";
		var car_site = response.site;
		car_site.set_alt( response.site.alt() + 1.5 );
		append( response.models, Model.new( get_model( cars, "Models/Transport/" ), car_site, rand()*360, 0, 180 ) );
		# Try to find out which direction the road is in
		var emerg_serv_pos = [];
		var emerg_serv_hdg = [];
		for( var x = 0; x <= 1; x += 1 ){
			print( "Searching Road..." );
			append( emerg_serv_hdg, nil );
			var i = 0;
			while( emerg_serv_hdg[ x ] == nil and i < 360 ){
				var probe_pos = geo.Coord.new( response.site ).apply_course_distance( i, 15 * ( x + 1) );
				var class = geodinfo( probe_pos.lat(), probe_pos.lon() )[1].names[0];
				if( class == "Asphalt" or class == "Freeway" or left( class, 4 ) == "Road" ){
					print("Success!");
					emerg_serv_hdg[ x ] = i;
					append( emerg_serv_pos, geo.Coord.new( probe_pos ) );
				}
				i += 10;
			}
			if( emerg_serv_hdg[ x ] == nil ){
				print("No Success!");
				emerg_serv_hdg[ x ] = rand()*360;
				append( emerg_serv_pos, geo.Coord.new( response.site ).apply_course_distance( road_heading, 15 ) );
			}
		}
		foreach( var el; emerg_serv_pos ){
			el.set_alt( geo.elevation( el.lat(), el.lon() ) );
		}
		append( response.models, Model.new( "Models/Airport/Vehicle/RTW_Sprinter_515_BL.xml",	emerg_serv_pos[0], emerg_serv_hdg[0], 0, 0 ) );
		append( response.models, Model.new( get_model( emergency_services ), 			emerg_serv_pos[1], emerg_serv_hdg[1], 0, 0 ) );
		
		# Add some people to the scene
		orientation = rand()*360;
		for( var i = 0; i <= 5; i += 1 ){
			var n_obj = geo.Coord.new( response.site );
			var dist = 3 + rand() * 5;
			n_obj.apply_course_distance( orientation + i * 45, dist );
			n_obj.set_alt( geo.elevation( n_obj.lat(), n_obj.lon() ) );
			append( response.models, Model.new( get_model( air_workers, "Models/Misc/" ) , n_obj, rand()*360, 0, 0 ) );
		}
	} elsif( response.type == 2 ){
		# Assume: Train accident
		response.code = "TRAIN ACCIDENT";
		append( response.models, Model.new( get_model( trains, "Models/Transport/" ), response.site, rand()*360, 0, rand()*90 ) );
		# There should be already some emergency vehicles at site
		var vehicles = [ ];
		var orientation = rand()*360;
		var i = 0;
		while( i < 8 ){
			append( vehicles, geo.Coord.new( response.site ) );
			vehicles[ i ].apply_course_distance( orientation + i * 45, 5 + rand() * 35 );
			vehicles[ i ].set_alt( geo.elevation( vehicles[i].lat(), vehicles[i].lon() ) );
			append( response.models, Model.new( get_model( emergency_services ), vehicles[i], rand()*360, 0, 0 ) );
			i += 1;
		}
			
	} elsif( response.type == 3 ){
		# Assume: Emergency at home
		var chance = rand();
		if( chance > 0.5 ){
			response.code = "ACS ACUTE CORONARY SYNDROME";
		} else if( chance > 0.2 ){
			response.code = "STROKE / TIA";
		} else {
			response.code = "TRAUMA // EXTREMITIES";
		}			
		append( response.models, Model.new( get_model( houses, "Models/Residential/" ), response.site, 0, 0, 0 ) );
	} elsif( response.type == 4 ){
		# Assume: Agricultural Accident
		response.code = "TRAUMA // EXTREMITIES";
		var farm = [ ];
		var orientation = rand()*360;
		for( var i = 0; i <= 4; i += 1 ){
			append( farm, geo.Coord.new( response.site ) );
			farm[ i ].apply_course_distance( orientation + i * 45, 3 + rand() * 12 );
			farm[ i ].set_alt( geo.elevation( farm[i].lat(), farm[i].lon() ) );
			# print( "Put new farm object "~ i ~ " at LAT "~ farm[i].lat() ~ " LON "~ farm[i].lon() );
			append( response.models, Model.new( get_model( farm_objects ), farm[i], rand()*360, 0, 0 ) );
		}
		# Decorate the scene with some nice hay bales :)
		orientation = rand()*360;
		for( var i = 0; i <= 10; i += 1 ){
			var n_obj = geo.Coord.new( response.site );
			var dist = 15 + rand() * 25;
			print( "Put Hay Bale at HDG "~ (orientation + i * 45) ~ ", distance "~ dist ~" from Response site "~ n_obj.lat() ~", "~ n_obj.lon() );
			n_obj.apply_course_distance( orientation + i * 45, dist );
			n_obj.set_alt( geo.elevation( n_obj.lat(), n_obj.lon() ) );
			append( response.models, Model.new( "Models/Agriculture/hay_bale.ac" , n_obj, rand()*360, 0, 0 ) );
		}
		if( rand() < 0.5 ){
			# Put a building some distance away
			var n_obj = geo.Coord.new( response.site );
			var course = rand() * 360;
			n_obj.apply_course_distance( course, 40 + rand() * 100 );
			n_obj.set_alt( geo.elevation( n_obj.lat(), n_obj.lon() ) );
			append( response.models, Model.new( get_model( farm_buildings ), n_obj, course + 90, 0, 0 ) );
		}
	} elsif( response.type == 5 ){
		# Assume: Helpless hikers
		response.code = "RESCUE / ASSISTANCE";
		var hk = [ ];
		var orientation = rand()*360;
		for( var i = 0; i <= 3; i += 1 ){
			append( hk, response.site );
			hk[ i ].apply_course_distance( orientation + i * 45, 1 + rand() * 3 );
			hk[ i ].set_alt( geo.elevation( hk[i].lat(), hk[i].lon() ) );
			# print( "Put new hiker "~ i ~ " at LAT "~ hk[i].lat() ~ " LON "~ hk[i].lon() );
			append( response.models, Model.new( get_model( hikers, "Models/Misc/" ), hk[i], rand()*360, 0, 0 ) );
		}
	}
	
	screen.log.write( "New response "~ response.code ~ " at lat "~ sprintf("%5.3f", response.site.lat()) ~ ", lon "~ sprintf("%5.3f", response.site.lon()) ~ ". Type: "~ response.type );
	
	
	var sound = { 
		path : this_addon.basePath ~ "/Sounds/", 
		file : "pager_alarm.wav" , 
		volume : 1.0};

	#fgcommand("play-audio-sample", props.Node.new(sound) );
	
	hemsgen_pager_gui.showDialog( response.code, response.site );
	
	guide_loop_timer = maketimer( guide_interval.getDoubleValue(), guide_loop );
	guide_loop_timer.simulatedTime = 1;
		
}

var createDiagnosis = func() {
	var i = 0;	#TODO replace by nil when all diagnoses have an index
	if( response.type == 0 ){
		response.diagnosis = "hypothermia";
		i = 0;
	} elsif( response.type == 1 or response.type == 2 ){
		var chance = rand();
		if( chance > 0.5 ){
			response.diagnosis = "multiple trauma";
			i = 1;
		} elsif( chance > 0.2 ){
			response.diagnosis = "whiplash";
			i = 2;
		} elsif( chance > 0.1 ){
			response.diagnosis = "traumatic brain injury";
			i = 3;
		}
	} elsif( response.type == 3 ){
		if( response.code == "ACS ACUTE CORONARY SYNDROME" ){
			if( rand() > 0.2 ){
				response.diagnosis = "myorcardial infarction";
				i = 4;
			} else {
				response.diagnosis = "pulmonary embolism";
				i = 5;
			}
		} elsif( response.code == "STROKE / TIA" ){
			var chance = rand();
			if( chance > 0.7 ){
				response.diagnosis = "stroke";
				i = 6;
			} elsif( chance > 0.3 ) {
				response.diagnosis = "hypoglycemia";
				i = 7;
			} else {
				response.diagnosis = "alcohol intoxication";
				i = 8;
			}
		} elsif( response.code == "TRAUMA // EXTREMITIES" ){
			var chance = rand();
			if( chance > 0.2 ){
				response.diagnosis = "lower arm fracture";
				i = 9;
			} else {
				response.diagnosis = "amputation";
				i = 10;
			}
		} else {
			die( "FATAL: Unknown Response Code" );
		}
	} elsif( response.type == 4 ){
		var chance = rand();
		if( chance > 0.2 ){
			response.diagnosis = "lower arm fracture";
			i = 9;
		} else {
			response.diagnosis = "amputation";
			i = 10;
		}
	} elsif( response.type == 5 ){
		var chance = rand();
		if( chance > 0.3 ){
			response.diagnosis = "hypothermia";
			i = 11;
		} else {
			response.diagnosis = "exsiccosis";
			i = 12;
		}
	}
	hemsgen_quiz.showQuizDialog( i, response.diagnosis );
}
			

var start_guide = func() {
	screen.log.write( "I will guide you:");
	guide_loop();
	guide_loop_timer.start();
}

var appr_eval = func() {
	if( response.appr_eval_done ) { return; }
	
	var distance = geo.aircraft_position().distance_to( response.site );
	screen.log.write( "You landed "~ sprintf("%3d", math.round( distance ) ) ~"m from the site" );
	response.appr_eval_done = 1;
	
	fgcommand("dialog-show", props.Node.new({ "dialog-name": "hemsgen-info-4" }))
}
