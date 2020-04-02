/***
* Name: Corona
* Author: hqngh
* Description: 
* Tags: Tag1, Tag2, TagN
***/
model Global


import "species/Building.gaml"
import "species/Individual.gaml"
import "species/Hospital.gaml"
import "species/Activity.gaml"
import "species/Boundary.gaml"
import "species/Authority.gaml"
import "species/Activity.gaml"
import "Constants.gaml"
import "Parameters.gaml"

global {
	geometry shape <- envelope(shp_buildings);
	outside the_outside;
	
	action global_init {
		
		write "global init";
		if (shp_commune != nil) {
			create Boundary from: shp_commune;
		}
		if (shp_buildings != nil) {
			create Building from: shp_buildings with: [type::string(read("type"))];
		}
		
		create outside;
		the_outside <- first(outside);
		do create_activities;
		
		list<Building> homes <- Building where (each.type in possible_homes);
		map<string,list<Building>> buildings_per_activity <- Building group_by (each.type);
		
		map<Building,float> working_places;
		loop wp over: possible_workplaces.keys {
			if (wp in buildings_per_activity.keys) {
					working_places <- working_places +  (buildings_per_activity[wp] as_map (each:: (possible_workplaces[wp] * each.shape.area)));  
			}
		}
		
		int min_student_age <- retirement_age;
		int max_student_age <- 0;
		map<list<int>,map<Building,float>> schools;
		loop l over: possible_schools.keys {
			max_student_age <- max(max_student_age, max(l));
			min_student_age <- min(min_student_age, min(l));
			string type <- possible_schools[l];
			schools[l] <- (type in buildings_per_activity.keys) ? (buildings_per_activity[type] as_map (each:: each.shape.area)) : map<Building,float>([]);
		}
			
		ask homes {
			//father
			create Individual {
				age <- rnd(max_student_age + 1,retirement_age);
				sex <- 0;
				home <- myself;
			} 
			//mother
			create Individual {
				age <- rnd(max_student_age + 1,retirement_age);
				sex <- 1;
				home <- myself;
			}
			//children
			create Individual number: rnd(3) {
				last_activity <-first(staying_home);
				age <- rnd(0,max_student_age);
				sex <- rnd(1);
				home <- myself;
			}

		}
		ask (N_grandfather * length(Building)) among homes {
			create Individual {
				age <- rnd(retirement_age + 1, max_age);
				sex <- 0;
				home <- myself;
			}
		}

		ask (M_grandmother * length(Building)) among homes {
			create Individual {
				age <- rnd(retirement_age + 1, max_age);
				sex <- 1;
				home <- myself;
				
			}
		}
		
		do define_agenda(working_places,schools);
		

		ask num_infected_init among Individual {
			do defineNewCase;
		}
		
		total_number_individual <- length(Individual);

	}
	
	action define_agenda(map<Building,float> working_places,map<list<int>,map<Building,float>> schools) {
		int min_student_age <- retirement_age;
			int max_student_age <- 0;
			loop l over: possible_schools.keys {
				max_student_age <- max(max_student_age, max(l));
				min_student_age <- min(min_student_age, min(l));
			}
			
		ask Individual {
			last_activity <-first(staying_home);
			do enter_building(home);
			status <- susceptible;
			if (age >= min_student_age) {
				if (age <= max_student_age) {
					loop l over: schools.keys {
						if (age >= min(l) and age <= max(l)) {
							if (flip(proba_go_outside) or empty(schools[l])) {
								school <- the_outside;	
							} else {
								school <-schools[l].keys[rnd_choice(schools[l].values)];
							}
						}
					}
				} else if (age <= retirement_age) { 
					if (flip(proba_go_outside) or empty(working_places)) {
						working_place <- the_outside;	
					} else {
						working_place <-working_places.keys[rnd_choice(working_places.values)];
					}
					
				}
			}
		}
		Activity eating_act <- Activity first_with (each.name = act_eating);
		list<Activity> possible_activities_tot <- Activities.values - studying - working - staying_home;
		list<Activity> possible_activities_without_rel <- possible_activities_tot - visiting_friend;
		
		ask Individual where ((each.age <= retirement_age) and (each.age >= min_student_age))  {
			loop times: 6 {
				map<int,Activity> agenda_day;
				list<Activity> possible_activities <- empty(relatives) ? possible_activities_without_rel : possible_activities_tot;
				int current_hour;
				if (age <= max_student_age) {
					current_hour <- rnd(school_hours[0][0],school_hours[0][1]);
					agenda_day[current_hour] <- studying[0];
				} else {
					current_hour <-rnd(work_hours[0][0],work_hours[0][1]);
					agenda_day[current_hour] <- working[0];
				}
				if (flip(proba_lunch_outside_workplace)) {
					current_hour <- rnd(lunch_hours[0],lunch_hours[1]);
					if (not flip(proba_lunch_at_home) and (eating_act != nil) and not empty(eating_act.buildings)) {
						agenda_day[current_hour] <- eating_act;
					} else {
						agenda_day[current_hour] <- staying_home[0];
					}
					current_hour <- current_hour + rnd(1,2);
					if (age <= max_student_age) {
						agenda_day[current_hour] <- studying[0];
					} else {
						agenda_day[current_hour] <- working[0];
					}
				}
				if (age <= max_student_age) {
						current_hour <- rnd(school_hours[1][0],school_hours[1][1]);
				} else {
					current_hour <-rnd(work_hours[1][0],work_hours[1][1]);
				}
				agenda_day[current_hour] <- staying_home[0];
				current_hour <- current_hour + rnd(1,max_duration_lunch);
				
				if (age >= min_age_for_evening_act) and flip(proba_activity_evening) {
					agenda_day[current_hour] <- any(possible_activities);
					current_hour <- (current_hour + rnd(1,max_duration_default)) mod 24;
					agenda_day[current_hour] <- staying_home[0];
				}
				agenda_week << agenda_day;
			}
			map<int,Activity> agenda_day;
			list<Activity> possible_activities <- empty(relatives) ? possible_activities_without_rel : possible_activities_tot;
			int num_activity <- rnd(0,max_num_activity_for_non_working_day);
			int current_hour <- rnd(first_act_old_hours[0],first_act_old_hours[1]);
			loop times: num_activity {
				agenda_day[current_hour] <- any(possible_activities);
				current_hour <- (current_hour + rnd(1,max_duration_default)) mod 24;
				agenda_day[current_hour] <- staying_home[0];
				current_hour <- (current_hour + rnd(1,max_duration_default)) mod 24;
			}
			agenda_week << agenda_day;
		}
		ask Individual where (each.age > retirement_age) {
			loop times: 7 {
				map<int,Activity> agenda_day;
				list<Activity> possible_activities <- empty(relatives) ? possible_activities_without_rel : possible_activities_tot;
				int num_activity <- rnd(0,max_num_activity_for_old_people);
				int current_hour <- rnd(first_act_old_hours[0],first_act_old_hours[1]);
				loop times: num_activity {
					agenda_day[current_hour] <- any(possible_activities);
					current_hour <- (current_hour + rnd(1,max_duration_default)) mod 24;
					agenda_day[current_hour] <- staying_home[0];
					current_hour <- (current_hour + rnd(1,max_duration_default)) mod 24;
				}
				agenda_week << agenda_day;
			}
		}
		ask Individual where empty(each.agenda_week) {
			loop times:7 {
				agenda_week<<[];
			}
		} 
	}

}