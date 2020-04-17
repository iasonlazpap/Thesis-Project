/***
* Name: MyThesis
* Author: mpizi
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model MyThesis

global {
	//GIS Input//
	
	//map used to filter the object to build from the OSM file according to attributes. for an exhaustive list, see: http://wiki.openstreetmap.org/wiki/Map_Features
	map filtering <- (["highway"::["primary", "secondary", "tertiary", "motorway", "living_street","residential", "unclassified"], "building"::["yes"]]);
	
	//OSM file to load
	file<geometry> osmfile <-  file<geometry>(osm_file("C:/Users/mpizi/Downloads/map(2).osm", filtering))  ;
	
	//compute the size of the environment from the envelope of the OSM file
	geometry shape <- envelope(osmfile);
	
	float step <- 1 #mn; //every step is defined as 10 minutes
	
	int nb_people <- 100; //number of people in the simulation
	int nb_missing <- 1; //number of missing people (It will always be 1 in this simulation)
	int missing -> {length(missing_person)};
	
	int current_hour update: (time / #hour) mod 24; //the current hour of the simulation
	
	//the following are variables conserning the times that people go and leave work respectively
	int min_work_start <- 7;
	int max_work_start <- 9;
	int min_work_end <- 16; 
	int max_work_end <- 18;
	
	//the following are variables concerning the missing person
	int time_to_rest <- 3;
	
	//tho following are variables conserning the speed that the agents are traveling. Measured in km/h
	float min_speed <- 1.0 #km / #h;
	float max_speed <- 5.0 #km / #h; 
	
	//tho following are variables conserning the speed that the missing person agent will be traveling. Measured in km/h
	float min_speed_missing <- 1.0 #km / #h;
	float max_speed_missing <- 3.0 #km / #h; 
	
	graph the_graph; //initialize the graph that the agents will be moving on
	
	list missing_agents -> missing_person.population;
	agent the_missing_agent -> missing_agents at 0;
	
	float destroy <- 0.02; // burden on road if people agent moves through it

	
	init {
		
		//possibility to load all of the attibutes of the OSM data: for an exhaustive list, see: http://wiki.openstreetmap.org/wiki/Map_Features
		create osm_agent from:osmfile with: [highway_str::string(read("highway")), building_str::string(read("building"))];
		
		//from the created generic agents, creation of the selected agents
		ask osm_agent {
			if (length(shape.points) = 1 and highway_str != nil ) {
				create node_agent with: [shape ::shape, type:: highway_str]; 
			} else {
				if (highway_str != nil ) {
					create road with: [shape ::shape, type:: highway_str];
				} else if (building_str != nil){
					create building with: [shape ::shape];
				}  
			}
			//do the generic agent die
			do die;
		}
		
		
        map<road,float> weights_map <- road as_map (each:: (each.destruction_coeff * each.shape.perimeter));
        the_graph <- as_edge_graph(road) with_weights weights_map; //create the graph initialized above as an edge graph with weights
		
		//graph without traffic: the_graph <- as_edge_graph(road); //create the graph initialized above as an edge graph
		
		
		//the function that creates the people agents
		create people number: nb_people {
			
			//define the speed, start and end work time that each agent will have.
			//these values are random so it will be different in each simulation
			speed <- min_speed + rnd (max_speed - min_speed) ;
			start_work <- min_work_start + rnd (max_work_start - min_work_start) ;
			end_work <- min_work_end + rnd (max_work_end - min_work_end) ;
			
			//define a living and a working place for each agent from the imported buildings
			living_place <- one_of(building) ;
			working_place <- one_of(building) ;
			
			objective <- "resting"; //each agent will begin resting, until it's time for him/her to go to work
			
			location <- any_location_in (living_place); //the agents home is his/her starting location
			
		}
		
		//the function that creates the missing person agent
		create missing_person number: nb_missing {
			
			speed <- min_speed + rnd (max_speed - min_speed) ;
			
			//these are not used for the missing person agent
			/*
			start_work <- min_work_start + rnd (max_work_start - min_work_start) ;
			end_work <- min_work_end + rnd (max_work_end - min_work_end) ;
			*/
			
			
			//the following are similar to the normal agents parameters
			living_place <- one_of(building) ;
			objective <- "running";
			location <- any_location_in (living_place); 
			
			
		}
	}
	
	//the following stops the simulation when the missing person is found
	reflex stop_simulation when: missing = 0 {
		do pause;
	}
	
	reflex update_graph{
        map<road,float> weights_map <- road as_map (each:: (each.destruction_coeff * each.shape.perimeter));
        the_graph <- the_graph with_weights weights_map;
     }
}


species osm_agent {
	string highway_str;
	string building_str;
} 

species node_agent {
	string type;
	aspect default { 
		draw square(3) color: #red ;
	}
} 

//define the building species
species building {
	string type; 
	rgb color <- #gray  ; //the color of each building
	
	aspect base {
		draw shape color: color ;
	}
}

//define the road species
species road  {
	string type; 
	//rgb color <- #black ; //the color of each road
	
	//we will simulate traffeic with road_destruction
	float destruction_coeff <- 1.0 max 2.0;
    int colorValue <- int(255*(destruction_coeff - 1)) update: int(255*(destruction_coeff - 1));
    rgb color <- rgb(min([255, colorValue]),max ([0, 255 - colorValue]),0)  update: rgb(min([255, colorValue]),max ([0, 255 - colorValue]),0) ;
	
	aspect base {
		draw shape color: color ;
	}
}


//define the missing_person species
species missing_person skills:[moving] {
	rgb color <- #red;
	
	building living_place <- nil ;

	string objective <- "running" ; 
	point the_target <- nil ;
	int arrived <- 0;
	
		
	list people_nearby <- agents_at_distance(1); // people_nearby equals all the agents (excluding the caller) which distance to the caller is lower than 1
	
	int nb_of_agents_nearby -> {length(people_nearby)};
	
	//this reflex sets the variable "found" to true when the list "people_nearby" has contents.
	//If "people_nearby" has items in it, that means that there are agents nearby the missing person
	reflex is_found when: length(people_nearby) > 1{
		//do die;
	}
	
	//this reflex sets the target of the missing person to a random building
	reflex run when: objective = "running" and the_target = nil {
		the_target <- point(one_of(building));  // casted one_of(building) to point type!!! one_of(the_graph.vertices)
		people_nearby <- agents_at_distance(1);
	}
		
	reflex get_some_rest when: objective = "resting" and current_hour = arrived + time_to_rest{
		objective <- "running";
		
		
	}
	
	//this reflex defines how the missing person moves 
	reflex move when: the_target != nil {
		do goto target: the_target on: the_graph ; 
		if the_target = location {
			the_target <- nil ;
			objective <- "resting";
			arrived <- current_hour;
		}
	}
	
	//the visualisation of the missing person on the graph
	aspect base {
		draw circle(10) color: color border: #black;
	}
	
}


//define the people species
species people skills:[moving] {
	
	rgb color <- #yellow ;
	
	building living_place <- nil ;
	building working_place <- nil ;
	int start_work ;
	int end_work  ;
	
	string objective ; 
	point the_target <- nil ;
		
	//this reflex sets the target when it's time to work and changes the objective of the agent to working
	reflex time_to_work when: current_hour = start_work and objective = "resting"{
		objective <- "working" ;
		the_target <- any_location_in (working_place);
	}
		
	//this reflex sets the target when it's time to go home and changes the objective of the agent to resting
	reflex time_to_go_home when: current_hour = end_work and objective = "working"{
		objective <- "resting" ;
		the_target <- any_location_in (living_place); 
	} 				
	
	
	//this reflex defines how the people agent moves  
	reflex move when: the_target != nil {
   		path path_followed <- goto(target: the_target, on:the_graph, return_path: true);
    	list<geometry> segments <- path_followed.segments;
    	loop line over: segments {
        	float dist <- line.perimeter;
        	ask road(path_followed agent_from_geometry line) { 
        	destruction_coeff <- destruction_coeff + (destroy * dist / shape.perimeter);
        	}
    	}
		if the_target = location {
			the_target <- nil ;
		}
	}
	
	//the visualisation of the missing person on the graph
	aspect base {
		draw circle(10) color: color border: #black;
	}
}


experiment find_missing_person type: gui {
	parameter "Open Street Map File for area of simulation" var: osmfile category: "GIS" ;
	
	parameter "Number of people agents" var: nb_people category: "People" ;
	
	parameter "Earliest hour to start work" var: min_work_start category: "People" min: 2 max: 8;
    parameter "Latest hour to start work" var: max_work_start category: "People" min: 8 max: 12;
    parameter "Earliest hour to end work" var: min_work_end category: "People" min: 12 max: 16;
    parameter "Latest hour to end work" var: max_work_end category: "People" min: 16 max: 23;
    
	parameter "minimum speed" var: min_speed category: "People" min: 0.1 #km/#h ;
	parameter "maximum speed" var: max_speed category: "People" max: 50 #km/#h;
	
	parameter "Time for missiong person to rest" var: time_to_rest category: "People" ;
	
	parameter "minimum speed for missing person" var: min_speed_missing category: "People" min: 0.1 #km/#h ;
	parameter "maximum speed for missing person" var: max_speed_missing category: "People" max: 50 #km/#h;
	
	parameter "Value of destruction when a people agent takes a road" var: destroy category: "Road" ;
	
	output {
		
		display city_display type: opengl {
			
			// refresh is useful in cases of not moving agents, but here for some 
			//reason it messes with the relative positions of agents		
			species building aspect: base; //refresh: false;
			species road aspect: base; // refresh: false;
			species missing_person aspect: base ;
			species people aspect: base;
			
			
		}
		
		display chart_display refresh:every(10#cycles) {
			chart "People Objective" type: pie style: exploded size: {1, 0.5} position: {0, 0.5}{
                data "Working" value: people count (each.objective="working") color: #magenta ;
                data "Resting" value: people count (each.objective="resting") color: #blue ;
            }
            chart "Number of people nearby the missing person" type: series  size: {1, 0.5} position: {0,0} {
                data "Number of agents nearby" value: int(the_missing_agent get('nb_of_agents_nearby'))  color: #red;
            }
            
        }
       
        monitor "Current Hour" value: current_hour;
       
        
	}
}
