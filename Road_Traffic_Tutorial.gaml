/***
* Name: NewModel
* Author: mpizi
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model PreyPredatorTutorial

/* A tutorial of the Predator Prey simulation as found on Gama Platform Website */

global {
	
	/*these parameters are global for all preys so we define them in the global section */
	int nb_preys_init <- 200 ;
	float prey_max_energy <- 1.0;
	float prey_max_transfer <- 0.1;
	float prey_energy_consumption <- 0.05;
	
	int nb_predators_init <- 20;
	float predator_max_energy <- 1.0;
	float predator_energy_transfer <- 0.5;
	float predator_energy_consumption <- 0.01;
	
	int nb_preys -> {length(prey)};
	int nb_predators -> {length(predator)};
	
	float prey_proba_reproduce <- 0.01;
	int prey_nb_max_offsprings <- 5;
	float prey_energy_reproduce <- 0.75;
	
	float predator_proba_reproduce <- 0.01;
	int predator_nb_max_offsprings <- 3;
	float predator_energy_reproduce <- 0.5;
	
	file map_init <- image_file("C:/Users/mpizi/Documents/Διπλωματική/[Gama]Workspace/Test/includes/predator_prey_raster_map.png");
	
	init {
		create prey number: nb_preys_init ;
		create predator number: nb_predators_init;
		ask vegetation_cell {
			color <- rgb (map_init at {grid_x,grid_y});	
			food <- 1 - ((color as list) at 0) / 255;
			food_production <- food / 100;
		}
	}
	/*
	reflex save_result when: (nb_preys > 0) and (nb_predators > 0){
    save ("cycle: "+ cycle + "; nbPreys: " + nb_preys
      + "; minEnergyPreys: " + (prey min_of each.energy)
      + "; maxSizePreys: " + (prey max_of each.energy) 
      + "; nbPredators: " + nb_predators           
      + "; minEnergyPredators: " + (predator min_of each.energy)          
      + "; maxSizePredators: " + (predator max_of each.energy)) 
      to: "C:/Users/mpizi/Documents/Διπλωματική/[Gama]Workspace/Test/Save_results.txt" type: "text" ;
}
	*/
	/*
	reflex stop_sim when: (nb_preys = 0) or (nb_predators = 0){
		do pause;
	} */
	
}

grid vegetation_cell width: 50 height: 50 neighbors: 4 {
	float max_food <- 1.0;
	//float food_production <- 0;
	float food_production <- rnd (0.001);
	float food <- rnd (1.0) update: food + food_production max: max_food;
	
	rgb color <- rgb(int(255 * (1 - food)), 255, int (255 * (1 - food))) 
		update: rgb(int(255 * (1 - food)), 255, int (255 * (1 - food))) ;
	list<vegetation_cell> neighbors2 <- self neighbors_at 2;
	/*Note that the result of the operator neighbors_at dist depends on the type of topology of the agent applying this operator: */
	
}

species generic_species {
	
	float size <- 1.0;
	rgb color;
	float max_energy;
    float max_transfer;
    float energy_consumption;
    vegetation_cell my_cell <- one_of (vegetation_cell) ;
    vegetation_cell choose_cell {
    	return nil;
    }
    float energy; //<- rnd(1.0) update: energy - energy_consumption max: max_energy ;
    
    float proba_reproduce;
    int nb_max_offsprings;
    float energy_reproduce;
    
    image_file species_icon;
    
    init{
		location <- my_cell.location; 
	}
	
	reflex basic_move {
		my_cell <- choose_cell();
		location <- my_cell.location;
	}
	
	reflex eat when: my_cell.food >0 {
		energy <- energy + energy_from_eating();
	}
	
	reflex die when: energy <= 0 {
		do die;
	}
	
	reflex reproduce when: (energy >= energy_reproduce) and (flip(proba_reproduce)) {
		int nb_offsprings <- rnd(1,nb_max_offsprings);
		create species(self) number: nb_offsprings {
			my_cell <- myself.my_cell;
			location <- my_cell.location;
			energy <- myself.energy/nb_offsprings;
			
		}
		energy <- energy / nb_offsprings;
	}
	
	float energy_from_eating {
		return 0.0;
	}   
    
    aspect base {
		draw circle(size) color: color;
	}
	aspect icon {
		draw species_icon size: 2 * size;
	}
	aspect info {
		draw square(size) color: color;
		draw string(energy with_precision 2) size:3 color: #black;
	}
}

species prey parent: generic_species {
	
	rgb color <- #blue;
	float max_energy <- prey_max_energy;
	float max_transfer <- prey_max_transfer;
	float energy_consumption <- prey_energy_consumption;
	float energy <- rnd(max_energy) update: energy - energy_consumption max: max_energy;
	
	float proba_reproduce <- prey_proba_reproduce ;
 	int nb_max_offsprings <- prey_nb_max_offsprings ;
 	float energy_reproduce <- prey_energy_reproduce ;

	float energy_from_eating {
		float energy_transfer <- 0.0;
		if (my_cell.food > 0){
			energy_transfer <- min([max_transfer,my_cell.food]);
			my_cell.food <- my_cell.food - energy_transfer;
		}
		return energy_transfer;
	}
	
	vegetation_cell choose_cell {
		return (my_cell.neighbors2) with_max_of(each.food);
	}
	
	image_file species_icon <- image_file("C:/Users/mpizi/Documents/Διπλωματική/[Gama]Workspace/Test/includes/predator_prey_sheep.png");
}

species predator parent: generic_species {
	rgb color <- #red;
	float max_energy <- predator_max_energy;
	float energy_transfer <- predator_energy_transfer;
	float energy_consumption <- predator_energy_consumption;
	
	float proba_reproduce <- predator_proba_reproduce ;
    int nb_max_offsprings <- predator_nb_max_offsprings ;
    float energy_reproduce <- predator_energy_reproduce ;
	
	float energy <- rnd(1.0) update: energy - energy_consumption max: max_energy ;
	
	float energy_from_eating {
		list<prey> reachable_preys <- prey inside(my_cell);
		if(!empty(reachable_preys)){
			ask one_of(reachable_preys){
				do die;
		}
		return energy_transfer;
		}
		return 0.0;
	}
	
	vegetation_cell choose_cell {
		vegetation_cell temp_cell <- shuffle(my_cell.neighbors2) first_with (!empty(prey inside each));
		
		if temp_cell != nil {
			return temp_cell;
		}
		else{
			 return one_of(my_cell.neighbors2);
		}
		
	}
	
	image_file species_icon <- image_file("C:/Users/mpizi/Documents/Διπλωματική/[Gama]Workspace/Test/includes/predator_prey_wolf.png") ;
}

//Parameters are changeable by the user 

experiment prey_predator type: gui {
    parameter "Initial number of preys:" var: nb_preys_init min: 1 max: 1000 category: "Prey" ;
    parameter "Prey max energy" var: prey_max_energy category: "Prey";
    parameter "Prey max transfer" var: prey_max_transfer category: "Prey";
    parameter "Prey energy consumption" var: prey_energy_consumption category: "Prey";
    
    parameter "Initial number of predators:" var: nb_predators_init min: 1 max: 1000 category: "Predator" ;
    parameter "Predator max energy" var: predator_max_energy category: "Predator";
    parameter "Predator energy transfer" var: predator_energy_transfer category: "Predator";
    parameter "Predator energy consumption" var: predator_energy_consumption category: "Predator";
    
    parameter "Prey probability reproduce: " var: prey_proba_reproduce category: "Prey" ;
	parameter "Prey nb max offsprings: " var: prey_nb_max_offsprings category: "Prey" ;
	parameter "Prey energy reproduce: " var: prey_energy_reproduce category: "Prey" ;
	parameter "Predator probability reproduce: " var: predator_proba_reproduce category: "Predator" ;
	parameter "Predator nb max offsprings: " var: predator_nb_max_offsprings category: "Predator" ;
	parameter "Predator energy reproduce: " var: predator_energy_reproduce category: "Predator" ;
    
    
    output {
    	display main_display{
	    	grid vegetation_cell lines: #black;
			species prey aspect: icon;
			species predator aspect: icon;
		
		}  
		
		display info_display {
			grid vegetation_cell lines: #black;
			species prey aspect: info;
			species predator aspect: info;
		}
		
		display population_information {
			chart "species_evolution" type: series size: {1,0.5} position: {0,0} {
				data "number of preys" value: nb_preys color: #blue; 
				data "number of predators" value: nb_predators; 
			}
			chart "Prey Energy Distribution" type: histogram background: #lightgray size: {0.5,0.5} position: {0,0.5} {
				data "]0;0.25]" value: prey count (each.energy <= 0.25) color: #blue;
				data "]0.25;0.5]" value: prey count ((0.25 < each.energy) and (each.energy <= 0.5)) color: #blue;
				data "]0.5;0.75]" value: prey count ((0.5 < each.energy) and (each.energy <= 0.75)) color: #blue;	
				data "]0.75;1.0]" value: prey count (0.75 < each.energy) color: #blue;
				
			}
			chart "Predator Energy Distribution" type: histogram background: #lightgray size: {0.5,0.5} position: {0.5,0.5} {
				data "]0;0.25]" value: predator count (each.energy <= 0.25) color: #red;
				data "]0.25;0.5]" value: predator count ((0.25 < each.energy) and (each.energy <= 0.5)) color: #red;
				data "]0.5;0.75]" value: predator count ((0.5 < each.energy) and (each.energy <= 0.75)) color: #red;	
				data "]0.75;1.0]" value: predator count (0.75 < each.energy) color: #red;
				
				
			}
		}
		monitor "number of preys" value: nb_preys; 
		monitor "number of predators" value: nb_predators;
		 
	}

}
	
experiment Optimization type: batch repeat: 2 keep_seed: true until: (time > 200){
	parameter "Prey max transfer:" var: prey_max_transfer min: 0.05 max: 0.5 step: 0.05 ;
	parameter "Prey energy reproduce:" var: prey_energy_reproduce min: 0.05 max: 0.75 step: 0.05;
	parameter "Predator energy transfert:" var: predator_energy_transfer min: 0.1 max: 1.0 step: 0.1 ;
	parameter "Predator energy reproduce:" var: predator_energy_reproduce min: 0.1 max: 1.0 step: 0.1;
	
	method tabu maximize: nb_preys + nb_predators iter_max: 10 tabu_list_size: 3;
	
	reflex save_results_exploration {
		ask simulations {
			save [int(self), prey_max_transfer,prey_energy_reproduce,predator_energy_transfer,predator_energy_reproduce,self.nb_predators,self.nb_preys]
			to: "C:/Users/mpizi/Documents/Διπλωματική/[Gama]Workspace/Test/results2.csv" type: "csv" rewrite: (int(self) = 0) ? true : false header: true;
		}
	}
	
			
}
	
	



