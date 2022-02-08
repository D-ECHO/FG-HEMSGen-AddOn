#	Quiz module, automatically creates a quiz dialog based on quiz-questions.xml

var base_property = props.globals.initNode("/addons/by-id/org.flightgear.addons.HEMSGen/questions");

var this_addon =  addons.getAddon("org.flightgear.addons.HEMSGen");

var letters = [ "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"];

var right_index = nil;
var right_answer = nil;

var name = "hemsgen-quiz";

#	Step 1: Load questions into property space
io.read_properties( this_addon.basePath ~ "/quiz-questions.xml", base_property );

#	Step 2: On-demand, create dialog

var showQuizDialog = func( i, ra ) {
	
	right_answer = ra;
	
	# Decide for a question to use
	var qs = base_property.getChildren();

	if( qs == nil ){
		die( "HEMSGen Quiz: No Questions defined");
	}
	
	var child = qs[ i ];
	var wrong = child.getChildren( "w" );
	
	# Decide the order of the possible answers
	var line_index = [];
	var line = [];
	for( var i = 0; i <= size( wrong ); i += 1 ){
		append( line, "" );
		append( line_index, nil );
	}
	
	# First set the index for the right answer
	right_index = math.round( rand() * size( line ) ) - 1;
	line[ right_index ] = right_answer;
	line_index[ right_index ] = -1;
	var n = 0;
	
			
	
	foreach( var el; wrong ){
		var i = nil;
		# create a random index, check the index isn't used already
		var done = 0;
		var n = 0;
		while( !done ){
			n += 1;
			if( n > 20 ){
				die( "No line number found after 20 tries." );
			}
			i = math.round( rand() * ( size(line_index) - 1 ) );
			done = 1;
			if( line_index[i] != nil ){
				 print( "Line "~ i ~" uses index "~ line_index[i] );
				done = 0;
			} else {
				 print( "Line "~ i ~" not used" );
			}
			 print( "Considered line number "~ i ~ " for answer "~ el.getValue() ~"; done:"~ done );
		}
		print( "done" );
		
		line[ i ] = el.getValue();
		line_index[ i ] = el.getIndex();
	}
	
	gui.dialog[name] = gui.Widget.new();
	gui.dialog[name].set("layout", "vbox");
	gui.dialog[name].set("default-padding", 0);
	gui.dialog[name].set("name", name);
	gui.dialog[name].set("width", 700);
	
	# title bar
	var titlebar = gui.dialog[name].addChild("group");
	titlebar.set("layout", "hbox");
	titlebar.addChild("empty").set("stretch", 1);
	titlebar.addChild("text").set("label", "HEMSGen Quiz");
	titlebar.addChild("empty").set("stretch", 1);
	
	var w = titlebar.addChild("button");
	w.set("pref-width", 16);
	w.set("pref-height", 16);
	w.set("legend", "");
	w.set("default", 1);
	w.set("key", "esc");
	w.setBinding("nasal", "delete(gui.dialog, \"" ~ name ~ "\")");
	w.setBinding("dialog-close");
	
	gui.dialog[name].addChild("hrule");
	
	var group_question = gui.dialog[name].addChild("group");
	group_question.set("layout", "vbox");
	group_question.addChild("empty").set("stretch", 1);
	var desc = child.getChildren( "desc" );
	foreach( var el; desc ){
		group_question.addChild("text").set("label", el.getValue() );
	}
	group_question.addChild("text").set("label", "Which of these is the most probable tentative diagnosis?");
	
	var group_answers = gui.dialog[name].addChild("group");
	group_answers.set( "layout", "vbox");
	group_answers.set( "width", 200 );
	#	Possible Answers
	var answers = [];
	for( var z = 0; z < size( line_index ); z += 1 ){
		append( answers, [ group_answers.addChild("group"), nil, nil ] );
		answers[ z ][0].set("layout", "hbox");
		answers[ z ][1] = answers[z][0].addChild("button");
		answers[ z ][2] = answers[z][0].addChild("text");
		answers[z][1].set("pref-width", 16);
		answers[z][1].set("pref-height", 16);
		answers[z][1].set("legend", letters[ z ] );
		answers[z][1].setBinding("nasal", "hemsgen_quiz.evaluate( "~ z ~" )");
		answers[z][2].set("label", line[ z ] );
	}
	
	gui.dialog[name].addChild("empty").set("stretch", 1);
	
	fgcommand("dialog-new", gui.dialog[name].prop());
	gui.showDialog(name);
}

var evaluate = func( i ){
	if( i == right_index ){
		screen.log.write( "Correct!" );
	} else {
		screen.log.write( "Wrong, the right answers is "~ right_answer );
	}
	
	screen.log.write( "Transport the patient to a hospital capable of treating "~ right_answer );
	
	fgcommand("dialog-close", props.Node.new({ "dialog-name": name }));
	delete(gui.dialog, name);
}
