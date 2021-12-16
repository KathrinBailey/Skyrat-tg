/datum/opposing_force_objective
	/// The name of the objective
	var/title = "blank objective"
	/// The actual objective.
	var/description = "Input objective description here, be descriptive about what you want to do."
	/// The reason for the objective.
	var/justification = "Input objective justification here, ensure you have a good reason for this objective!"
	/// Was this specific objective approved by the admins?
	var/approved = FALSE
	/// How intense is this goal?
	var/intensity = 0

/datum/opposing_force
	/// A list of objectives.
	var/list/objectives = list()
	/// A list of items they want spawned.
	var/list/requested_items = list()
	/// Justification for wanting to do bad things.
	var/set_backstory = "Provide a description of why you want to do bad things. Include specifics such as what lead upto the events that made you want to do bad things, think of it as though you were your character, react appropriately."
	/// Has this been approved?
	var/approved = FALSE
	/// Hard ref to our mind.
	var/datum/mind/mind_reference
	var/client/holder
	/// For logging stuffs
	var/list/modification_log = list()

/datum/opposing_force/New(user, mind_reference)//user can either be a client or a mob due to byondcode(tm)
	if (istype(user, /client))
		var/client/user_client = user
		holder = user_client //if its a client, assign it to holder
	else
		var/mob/user_mob = user
		holder = user_mob.client //if its a mob, assign the mob's client to holder
	src.mind_reference = mind_reference

/datum/opposing_force/Destroy(force)
	mind_reference.memory_panel = null
	mind_reference = null
	holder = null
	SSopposing_force.remove_opfor(src)
	return ..()

/datum/opposing_force/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OpposingForcePanel")
		ui.open()

/datum/opposing_force/ui_state(mob/user)
	return GLOB.always_state

/datum/opposing_force/ui_data(mob/user)
	var/list/data = list()

	data["backstory"] = set_backstory

	data["objectives"] = list()
	var/objective_num
	for(var/datum/opposing_force_objective/opfor in objectives)
		var/list/objective_data = list(
			id = objective_num,
			ref = REF(opfor),
			title = opfor.title,
			description = opfor.description,
			intensity = opfor.intensity,
			justification = opfor.justification,
			approved = opfor.approved
			)
		objective_num++
		data["objectives"] += list(objective_data)

	return data

/datum/opposing_force/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/datum/opposing_force_objective/edited_objective
	if(params["objective_ref"])
		edited_objective = locate(params["objective_ref"]) in objectives
		if(!edited_objective)
			CRASH("Opposing_force passed a reference parameter to a goal that it could not locate!")

	switch(action)
		if("set_backstory")
			set_backstory(usr, params["backstory"])
		if("add_objective")
			add_objective(usr)
		if("remove_objective")
			remove_objective(usr, edited_objective)
		if("set_objective_title")
			set_objective_title(usr, edited_objective, params["title"])
		if("set_objective_description")
			set_objective_description(usr, edited_objective, params["new_desciprtion"])
		if("set_objective_justification")
			set_objective_justification(usr, edited_objective, params["new_justification"])

/datum/opposing_force/proc/set_objective_description(mob/user, datum/opposing_force_objective/opposing_force_objective, new_description)
	if(!opposing_force_objective)
		CRASH("[user] tried to update a non existent opfor objective!")
	var/sanitized_description = sanitize_text(new_description)
	opposing_force_objective.description = sanitized_description
	return TRUE

/datum/opposing_force/proc/set_objective_justification(mob/user, datum/opposing_force_objective/opposing_force_objective, new_justification)
	if(!opposing_force_objective)
		CRASH("[user] tried to update a non existent opfor objective!")
	var/sanitize_justification = sanitize_text(new_justification)
	opposing_force_objective.justification = sanitize_justification
	return TRUE

/datum/opposing_force/proc/remove_objective(mob/user, datum/opposing_force_objective/opposing_force_objective)
	if(!opposing_force_objective)
		CRASH("[user] tried to remove a non existent opfor objective!")
	objectives -= opposing_force_objective
	add_log(user.ckey, "Removed an objective: [opposing_force_objective.description]")
	qdel(opposing_force_objective)
	return TRUE

/datum/opposing_force/proc/add_objective(mob/user)
	if(LAZYLEN(objectives) >= OPFOR_MAX_OBJECTIVES)
		to_chat(user, span_warning("You have too many objectives, please remove one!"))
	objectives += new /datum/opposing_force_objective
	add_log(user.ckey, "Added a new blank objective")
	return TRUE

/datum/opposing_force/proc/set_objective_title(mob/user, datum/opposing_force_objective/opposing_force_objective, new_title)
	var/sanitized_title = sanitize_text(new_title)
	if(!opposing_force_objective)
		CRASH("[user] tried to update a non existent opfor objective!")
	add_log(user.ckey, "Updated objective from: [opposing_force_objective.title] to: [sanitized_title]")
	opposing_force_objective.title = sanitized_title
	return TRUE

/datum/opposing_force/proc/set_backstory(mob/user, incoming_backstory)
	var/sanitized_backstory = sanitize_text(incoming_backstory)
	add_log(user.ckey, "Updated backstory from: [set_backstory] to: [sanitized_backstory]")
	set_backstory = sanitized_backstory
	return TRUE

/datum/opposing_force/proc/add_log(ckey, new_log)
	modification_log += "[ckey ? ckey : "SYSTEM"] - [new_log]"

/mob/verb/opposing_force()
	set name = "Opposing Force"
	set category = "OOC"
	set desc = "View your opposing force panel, or request one."
	// Mind checks
	if(!mind)
		var/fail_message = "You have no mind!"
		if(isobserver(src))
			fail_message += " You have to be in the current round at some point to have one."
		to_chat(src, span_warning(fail_message))
		return
	// Subsystem checks, no point in bloating the system if it's not accepting more.
	var/availability = SSopposing_force.check_availability()
	if(availability != "success")
		to_chat(usr, span_warning("Error, the OPFOR subsystem rejected your request. Reason: <b>[availability]</b>"))
		return FALSE

	if(!mind.opposing_force)
		var/datum/opposing_force/opposing_force = new(usr, mind)
		mind.opposing_force = opposing_force
		SSopposing_force.add_opfor(opposing_force)
	mind.opposing_force.ui_interact(usr)

