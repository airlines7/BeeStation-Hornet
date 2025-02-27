/datum/datacore
	var/medical[] = list()
	var/medicalPrintCount = 0
	var/general[] = list()
	var/security[] = list()
	var/securityPrintCount = 0
	var/securityCrimeCounter = 0
	//This list tracks characters spawned in the world and cannot be modified in-game. Currently referenced by respawn_character().
	var/locked[] = list()

/datum/data
	var/name = "data"

/datum/data/record
	name = "record"
	var/list/fields = list()

/datum/data/record/Destroy()
	GLOB.data_core.medical -= src
	GLOB.data_core.security -= src
	GLOB.data_core.general -= src
	GLOB.data_core.locked -= src
	. = ..()

/// A helper proc to get the front photo of a character from the record.
/// Handles calling `get_photo()`, read its documentation for more information.
/datum/data/record/proc/get_front_photo()
	return get_photo("photo_front", SOUTH)

/// A helper proc to get the side photo of a character from the record.
/// Handles calling `get_photo()`, read its documentation for more information.
/datum/data/record/proc/get_side_photo()
	return get_photo("photo_side", WEST)

/**
 * You shouldn't be calling this directly, use `get_front_photo()` or `get_side_photo()`
 * instead.
 *
 * This is the proc that handles either fetching (if it was already generated before) or
 * generating (if it wasn't) the specified photo from the specified record. This is only
 * intended to be used by records that used to try to access `fields["photo_front"]` or
 * `fields["photo_side"]`, and will return an empty icon if there isn't any of the necessary
 * fields.
 *
 * Arguments:
 * * field_name - The name of the key in the `fields` list, of the record itself.
 * * orientation - The direction in which you want the character appearance to be rotated
 * in the outputed photo.
 *
 * Returns an empty `/icon` if there was no `character_appearance` entry in the `fields` list,
 * returns the generated/cached photo otherwise.
 */
/datum/data/record/proc/get_photo(field_name, orientation)
	if(fields[field_name])
		return fields[field_name]

	if(!fields["character_appearance"])
		return new /icon()

	var/mutable_appearance/character_appearance = fields["character_appearance"]
	character_appearance.setDir(orientation)

	var/icon/picture_image = getFlatIcon(character_appearance)

	var/datum/picture/picture = new
	picture.picture_name = "[fields["name"]]"
	picture.picture_desc = "This is [fields["name"]]."
	picture.picture_image = picture_image

	var/obj/item/photo/photo = new(null, picture)
	fields[field_name] = photo
	return photo

/datum/data/crime
	name = "crime"
	var/crimeName = ""
	var/crimeDetails = ""
	var/author = ""
	var/time = ""
	var/fine = 0
	var/paid = 0
	var/dataId = 0

/datum/datacore/proc/createCrimeEntry(cname = "", cdetails = "", author = "", time = "", fine = 0)
	var/datum/data/crime/c = new /datum/data/crime
	c.crimeName = cname
	c.crimeDetails = cdetails
	c.author = author
	c.time = time
	c.fine = fine
	c.paid = 0
	c.dataId = ++securityCrimeCounter
	return c

/datum/datacore/proc/addCitation(id = "", datum/data/crime/crime)
	for(var/datum/data/record/R in security)
		if(R.fields["id"] == id)
			var/list/crimes = R.fields["citation"]
			crimes |= crime
			return

/datum/datacore/proc/removeCitation(id, cDataId)
	for(var/datum/data/record/R in security)
		if(R.fields["id"] == id)
			var/list/crimes = R.fields["citation"]
			for(var/datum/data/crime/crime in crimes)
				if(crime.dataId == text2num(cDataId))
					crimes -= crime
					return

/datum/datacore/proc/payCitation(id, cDataId, amount)
	for(var/datum/data/record/R in security)
		if(R.fields["id"] == id)
			var/list/crimes = R.fields["citation"]
			for(var/datum/data/crime/crime in crimes)
				if(crime.dataId == text2num(cDataId))
					crime.paid = crime.paid + amount
					var/datum/bank_account/D = SSeconomy.get_budget_account(ACCOUNT_SEC_ID)
					D.adjust_money(amount)
					return

/**
  * Adds crime to security record.
  *
  * Is used to add single crime to someone's security record.
  * Arguments:
  * * id - record id.
  * * datum/data/crime/crime - premade array containing every variable, usually created by createCrimeEntry.
  */
/datum/datacore/proc/addCrime(id = "", datum/data/crime/crime)
	for(var/datum/data/record/R in security)
		if(R.fields["id"] == id)
			var/list/crimes = R.fields["crim"]
			crimes |= crime
			return

/**
  * Deletes crime from security record.
  *
  * Is used to delete single crime to someone's security record.
  * Arguments:
  * * id - record id.
  * * cDataId - id of already existing crime.
  */
/datum/datacore/proc/removeCrime(id, cDataId)
	for(var/datum/data/record/R in security)
		if(R.fields["id"] == id)
			var/list/crimes = R.fields["crim"]
			for(var/datum/data/crime/crime in crimes)
				if(crime.dataId == text2num(cDataId))
					crimes -= crime
					return

/**
  * Adds details to a crime.
  *
  * Is used to add or replace details to already existing crime.
  * Arguments:
  * * id - record id.
  * * cDataId - id of already existing crime.
  * * details - data you want to add.
  */
/datum/datacore/proc/addCrimeDetails(id, cDataId, details)
	for(var/datum/data/record/R in security)
		if(R.fields["id"] == id)
			var/list/crimes = R.fields["crim"]
			for(var/datum/data/crime/crime in crimes)
				if(crime.dataId == text2num(cDataId))
					crime.crimeDetails = details
					return

/datum/datacore/proc/manifest()
	for(var/i in GLOB.new_player_list)
		var/mob/dead/new_player/N = i
		if(N.new_character)
			log_manifest(N.ckey,N.new_character.mind,N.new_character)
		if(ishuman(N.new_character))
			manifest_inject(N.new_character)
		CHECK_TICK

/datum/datacore/proc/manifest_modify(name, assignment, hudstate)
	var/datum/data/record/foundrecord = find_record("name", name, GLOB.data_core.general)
	if(foundrecord)
		foundrecord.fields["rank"] = assignment
		foundrecord.fields["hud"] = hudstate

/datum/datacore/proc/get_manifest()
	var/list/manifest_out = list()
	var/list/dept_list = list(
		"Command" = DEPT_BITFLAG_COM,
		"Very Important People" = DEPT_BITFLAG_VIP,
		"Security" = DEPT_BITFLAG_SEC,
		"Engineering" = DEPT_BITFLAG_ENG,
		"Medical" = DEPT_BITFLAG_MED,
		"Science" = DEPT_BITFLAG_SCI,
		"Supply" = DEPT_BITFLAG_CAR,
		"Service" = DEPT_BITFLAG_SRV,
		"Civilian" = DEPT_BITFLAG_CIV,
		"Silicon" = DEPT_BITFLAG_SILICON
	)
	for(var/datum/data/record/t in GLOB.data_core.general)
		var/name = t.fields["name"]
		var/rank = t.fields["rank"]
		var/dept_bitflags = t.fields["active_dept"]
		var/has_department = FALSE
		for(var/department in dept_list)
			if(dept_bitflags & dept_list[department])
				if(!manifest_out[department])
					manifest_out[department] = list()
				manifest_out[department] += list(list(
					"name" = name,
					"rank" = rank
				))
				has_department = TRUE
		if(!has_department)
			if(!manifest_out["Misc"])
				manifest_out["Misc"] = list()
			manifest_out["Misc"] += list(list(
				"name" = name,
				"rank" = rank
			))
	//Sort the list by 'departments' primarily so command is on top.
	var/list/sorted_out = list()
	for(var/department in (dept_list += "Misc"))
		if(!isnull(manifest_out[department]))
			sorted_out[department] = manifest_out[department]
	return sorted_out

/datum/datacore/proc/get_manifest_html(monochrome = FALSE)
	var/list/manifest = get_manifest()
	var/dat = {"
	<head><style>
		.manifest {border-collapse:collapse;}
		.manifest td, th {border:1px solid [monochrome?"black":"#DEF; background-color:white; color:black"]; padding:.25em}
		.manifest th {height: 2em; [monochrome?"border-top-width: 3px":"background-color: #48C; color:white"]}
		.manifest tr.head th { [monochrome?"border-top-width: 1px":"background-color: #488;"] }
		.manifest tr.alt td {[monochrome?"border-top-width: 2px":"background-color: #DEF"]}
	</style></head>
	<table class="manifest" width='350px'>
	<tr class='head'><th>Name</th><th>Rank</th></tr>
	"}
	for(var/department in manifest)
		var/list/entries = manifest[department]
		dat += "<tr><th colspan=3>[department]</th></tr>"
		//JUST
		var/even = FALSE
		for(var/entry in entries)
			var/list/entry_list = entry
			dat += "<tr[even ? " class='alt'" : ""]><td>[entry_list["name"]]</td><td>[entry_list["rank"]]</td></tr>"
			even = !even

	dat += "</table>"
	dat = replacetext(dat, "\n", "")
	dat = replacetext(dat, "\t", "")
	return dat


/datum/datacore/proc/manifest_inject(mob/living/carbon/human/H)
	set waitfor = FALSE
	var/static/list/show_directions = list(SOUTH, WEST)
	if(H.mind && (H.mind.assigned_role != H.mind.special_role))
		var/assignment
		if(H.mind.assigned_role)
			assignment = H.mind.assigned_role
		else if(H.job)
			assignment = H.job
		else
			assignment = "Unassigned"

		var/static/record_id_num = 1001
		var/id = num2hex(record_id_num++,6)
		// We need to compile the overlays now, otherwise we're basically copying an empty icon.
		COMPILE_OVERLAYS(H)
		var/mutable_appearance/character_appearance = new(H.appearance)

		//These records should ~really~ be merged or something
		//General Record
		var/datum/data/record/G = new()
		G.fields["id"]			= id
		G.fields["name"]		= H.real_name
		G.fields["rank"]		= assignment
		G.fields["hud"]			= get_hud_by_jobname(assignment)
		G.fields["active_dept"]	= SSjob.GetJobActiveDepartment(assignment)
		G.fields["age"]			= H.age
		G.fields["species"]	= H.dna.species.name
		G.fields["fingerprint"]	= rustg_hash_string(RUSTG_HASH_MD5, H.dna.uni_identity)
		G.fields["p_stat"]		= "Active"
		G.fields["m_stat"]		= "Stable"
		switch(H.gender)
			if(MALE, FEMALE)
				G.fields["gender"] = capitalize(H.gender)
			if(PLURAL)
				G.fields["gender"] = "Other"
		G.fields["character_appearance"] = character_appearance
		general += G

		//Medical Record
		var/datum/data/record/M = new()
		M.fields["id"]			= id
		M.fields["name"]		= H.real_name
		M.fields["blood_type"]	= H.dna.blood_type
		M.fields["b_dna"]		= H.dna.unique_enzymes
		M.fields["mi_dis"]		= "None"
		M.fields["mi_dis_d"]	= "No minor disabilities have been declared."
		M.fields["ma_dis"]		= "None"
		M.fields["ma_dis_d"]	= "No major disabilities have been diagnosed."
		M.fields["alg"]			= "None"
		M.fields["alg_d"]		= "No allergies have been detected in this patient."
		M.fields["cdi"]			= "None"
		M.fields["cdi_d"]		= "No diseases have been diagnosed at the moment."
		M.fields["notes"]		= "No notes."
		medical += M

		//Security Record
		var/datum/data/record/S = new()
		S.fields["id"]			= id
		S.fields["name"]		= H.real_name
		S.fields["criminal"]	= "None"
		S.fields["citation"]	= list()
		S.fields["crim"]		= list()
		S.fields["notes"]		= "No notes."
		security += S

		//Locked Record
		var/datum/data/record/L = new()
		L.fields["id"]			= rustg_hash_string(RUSTG_HASH_MD5, "[H.real_name][H.mind.assigned_role]")	//surely this should just be id, like the others?
		L.fields["name"]		= H.real_name
		L.fields["rank"] 		= H.mind.assigned_role
		L.fields["age"]			= H.age
		switch(H.gender)
			if(MALE, FEMALE)
				L.fields["gender"] = capitalize(H.gender)
			if(PLURAL)
				L.fields["gender"] = "Other"
		L.fields["blood_type"]	= H.dna.blood_type
		L.fields["b_dna"]		= H.dna.unique_enzymes
		L.fields["identity"]	= H.dna.uni_identity
		L.fields["species"]		= H.dna.species.type
		L.fields["features"]	= H.dna.features
		L.fields["character_appearance"] = character_appearance
		L.fields["mindref"]		= H.mind
		locked += L
	return

/**
 * Supporing proc for getting general records
 * and using them as pAI ui data. This gets
 * medical information - or what I would deem
 * medical information - and sends it as a list.
 *
 * @return - list(general_records_out)
 */
/datum/datacore/proc/get_general_records()
	if(!GLOB.data_core.general)
		return list()
	/// The array of records
	var/list/general_records_out = list()
	for(var/datum/data/record/gen_record as anything in GLOB.data_core.general)
		/// The object containing the crew info
		var/list/crew_record = list()
		crew_record["ref"] = REF(gen_record)
		crew_record["name"] = gen_record.fields["name"]
		crew_record["physical_health"] = gen_record.fields["p_stat"]
		crew_record["mental_health"] = gen_record.fields["m_stat"]
		general_records_out += list(crew_record)
	return general_records_out

/**
 * Supporing proc for getting secrurity records
 * and using them as pAI ui data. Sends it as a
 * list.
 *
 * @return - list(security_records_out)
 */
/datum/datacore/proc/get_security_records()
	if(!GLOB.data_core.security)
		return list()
	/// The array of records
	var/list/security_records_out = list()
	for(var/datum/data/record/sec_record as anything in GLOB.data_core.security)
		/// The object containing the crew info
		var/list/crew_record = list()
		crew_record["ref"] = REF(sec_record)
		crew_record["name"] = sec_record.fields["name"]
		crew_record["status"] = sec_record.fields["criminal"] // wanted status
		crew_record["crimes"] = length(sec_record.fields["crim"])
		security_records_out += list(crew_record)
	return security_records_out

/datum/datacore/proc/get_id_photo(mob/living/carbon/human/human, show_directions = list(SOUTH))
	return get_flat_existing_human_icon(human, show_directions)
