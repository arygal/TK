//renwicks: fictional unit to describe shield strength
//a small meteor hit will deduct 1 renwick of strength from that shield tile
//light explosion range will do 1 renwick's damage
//medium explosion range will do 2 renwick's damage
//heavy explosion range will do 3 renwick's damage
//explosion damage is cumulative. if a tile is in range of light, medium and heavy damage, it will take a hit from all three

/obj/machinery/shield_gen
	name = "shield generator"
	desc = "Machine that generates an impenetrable field of energy when activated."
	icon = 'icons/obj/machines/shielding.dmi'
	icon_state = "generator0"
	var/active = 0
	var/field_radius = 3
	var/list/field
	density = TRUE
	var/locked = 0
	var/average_field_strength = 0
	var/strengthen_rate = 0.2
	var/max_strengthen_rate = 0.2
	var/powered = 0
	var/check_powered = 1
	var/obj/machinery/shield_capacitor/owned_capacitor
	var/target_field_strength = 10
	var/time_since_fail = 100
	var/energy_conversion_rate = 0.01	//how many renwicks per watt?
	//
	use_power = IDLE_POWER_USE			//0 use nothing
							//1 use idle power
							//2 use active power
	idle_power_usage = 20
	active_power_usage = 100
	required_skills = list(/datum/skill/engineering = SKILL_LEVEL_PRO)

/obj/machinery/shield_gen/atom_init()
	field = list()
	. = ..()

/obj/machinery/shield_gen/atom_init_late()
	for(var/obj/machinery/shield_capacitor/possible_cap in range(1, src))
		if(get_dir(possible_cap, src) == possible_cap.dir)
			owned_capacitor = possible_cap
			break

/obj/machinery/shield_gen/Destroy()
	for(var/obj/effect/energy_field/D in field)
		field.Remove(D)
		D.loc = null
	return ..()

/obj/machinery/shield_gen/attackby(obj/item/W, mob/user)
	if(istype(W, /obj/item/weapon/card/id))
		var/obj/item/weapon/card/id/C = W
		if((access_captain in C.access) || (access_security in C.access) || (access_engine in C.access))
			src.locked = !src.locked
			to_chat(user, "Controls are now [src.locked ? "locked." : "unlocked."]")
			updateDialog()
		else
			to_chat(user, "<span class='warning'>Access denied.</span>")

	else if(iswrenching(W))
		src.anchored = !src.anchored
		visible_message("<span class='notice'>[bicon(src)] [src] has been [anchored?"bolted to the floor":"unbolted from the floor"] by [user].</span>")

		if(active)
			toggle()
		if(anchored)
			spawn(0)
				for(var/obj/machinery/shield_capacitor/cap in range(1, src))
					if(cap.owned_gen)
						continue
					if(get_dir(cap, src) == cap.dir && src.anchored)
						owned_capacitor = cap
						owned_capacitor.owned_gen = src
						updateDialog()
						break
		else
			if(owned_capacitor && owned_capacitor.owned_gen == src)
				owned_capacitor.owned_gen = null
			owned_capacitor = null
	else
		..()

/obj/machinery/shield_gen/emag_act(mob/user)
	if(prob(75))
		src.locked = !src.locked
		to_chat(user, "Controls are now [src.locked ? "locked." : "unlocked."]")
		updateDialog()
	var/datum/effect/effect/system/spark_spread/s = new /datum/effect/effect/system/spark_spread
	s.set_up(5, 1, src)
	s.start()
	return TRUE

/obj/machinery/shield_gen/ui_interact(mob/user)
	if (!Adjacent(user) || stat & (BROKEN|NOPOWER))
		if (!issilicon(user) && !isobserver(user))
			user.unset_machine()
			user << browse(null, "window=shield_generator")
			return

	var/t = ""
	if(locked && !isobserver(user))
		t += "<div class='NoticeBox'>Swipe your ID card to begin.</div>"
	else
		t += "[owned_capacitor ? "<span class='green'>Charge capacitor connected.</span>" : "<span class='red'>Unable to locate charge capacitor!</span>"]<br>"
		t += "This generator is: [active ? "<span class='green'>Online</span>" : "<span class='red'>Offline</span>" ] <a href='byond://?src=\ref[src];toggle=1'>[active ? "Deactivate" : "Activate"]</a><br>"
		t += "[time_since_fail > 2 ? "<span class='green'>Field is stable.</span>" : "<span class='red'>Warning, field is unstable!</span>"]<br>"
		t += "Coverage diameter (restart required): \
		<a href='byond://?src=\ref[src];change_radius=-50'>---</a> \
		<a href='byond://?src=\ref[src];change_radius=-5'>--</a> \
		<a href='byond://?src=\ref[src];change_radius=-1'>-</a> \
		[field_radius * 2]m \
		<a href='byond://?src=\ref[src];change_radius=1'>+</a> \
		<a href='byond://?src=\ref[src];change_radius=5'>++</a> \
		<a href='byond://?src=\ref[src];change_radius=50'>+++</a><br>"
		t += "Overall field strength: [average_field_strength] Renwicks ([target_field_strength ? 100 * average_field_strength / target_field_strength : "NA"]%)<br>"
		t += "Upkeep energy: [field.len * average_field_strength / energy_conversion_rate] Watts/sec<br>"
		t += "Charge rate: <a href='byond://?src=\ref[src];strengthen_rate=-0.1'>--</a> \
		[strengthen_rate] Renwicks/sec \
		<a href='byond://?src=\ref[src];strengthen_rate=0.1'>++</a><br>"
		t += "Additional energy required to charge: [field.len * strengthen_rate / energy_conversion_rate] Watts/sec<br>"
		t += "Maximum field strength: \
		<a href='byond://?src=\ref[src];target_field_strength=-100'>min</a> \
		<a href='byond://?src=\ref[src];target_field_strength=-10'>--</a> \
		<a href='byond://?src=\ref[src];target_field_strength=-1'>-</a> \
		[target_field_strength] Renwicks \
		<a href='byond://?src=\ref[src];target_field_strength=1'>+</a> \
		<a href='byond://?src=\ref[src];target_field_strength=10'>++</a> \
		<a href='byond://?src=\ref[src];target_field_strength=100'>max</a><br>"
	t += "<hr>"
	t += "<A href='byond://?src=\ref[src]'>Refresh</A> "

	var/datum/browser/popup = new(user, "shield_generator", "Shield Generator Control Console", 500, 400)
	popup.set_content(t)
	popup.open()

/obj/machinery/shield_gen/process()

	if(field.len)
		time_since_fail++
		var/stored_renwicks = 0
		var/target_strength_this_update = min(strengthen_rate + max(average_field_strength, 0), target_field_strength)

		if(active && owned_capacitor)
			var/required_energy = field.len * target_strength_this_update / energy_conversion_rate
			var/assumed_charge = min(owned_capacitor.stored_charge, required_energy)
			stored_renwicks = assumed_charge * energy_conversion_rate
			owned_capacitor.stored_charge -= assumed_charge

		average_field_strength = 0
		var/renwicks_per_field = 0
		if(stored_renwicks != 0)
			renwicks_per_field = stored_renwicks / field.len

		for(var/obj/effect/energy_field/E in field)
			if(active && renwicks_per_field > 0)
				var/amount_to_strengthen = min(renwicks_per_field - E.strength, strengthen_rate)
				if(E.ticks_recovering > 0 && amount_to_strengthen > 0)
					E.Strengthen( min(amount_to_strengthen / 10, 0.1) )
					E.ticks_recovering -= 1
				else
					E.Strengthen(amount_to_strengthen)
				average_field_strength += E.strength
			else
				E.Strengthen(-E.strength)

		average_field_strength /= field.len
		if(average_field_strength < 1)
			time_since_fail = 0
	else
		average_field_strength = 0

/obj/machinery/shield_gen/Topic(href, href_list[])
	. = ..()
	if(!.)
		return

	if( href_list["toggle"] )
		toggle()
	else if( href_list["change_radius"] )
		field_radius += text2num(href_list["change_radius"])
		if(field_radius > 200)
			field_radius = 200
		else if(field_radius < 0)
			field_radius = 0
	else if( href_list["strengthen_rate"] )
		strengthen_rate += text2num(href_list["strengthen_rate"])
		if(strengthen_rate > 1)
			strengthen_rate = 1
		else if(strengthen_rate < 0)
			strengthen_rate = 0
	else if( href_list["target_field_strength"] )
		target_field_strength += text2num(href_list["target_field_strength"])
		if(target_field_strength > 1000)
			target_field_strength = 1000
		else if(target_field_strength < 0)
			target_field_strength = 0

	updateDialog()

/obj/machinery/shield_gen/power_change()
	if(stat & BROKEN)
		icon_state = "broke"
	else
		if( powered() )
			if (src.active)
				icon_state = "generator1"
			else
				icon_state = "generator0"
			stat &= ~NOPOWER
		else
			spawn(rand(0, 15))
				src.icon_state = "generator0"
				stat |= NOPOWER
				update_power_use()
			if (src.active)
				toggle()
	update_power_use()

/obj/machinery/shield_gen/ex_act(severity)

	if(active)
		toggle()
	return ..()

/*
/obj/machinery/shield_gen/proc/check_powered()
	check_powered = 1
	if(!anchored)
		powered = 0
		return 0
	var/turf/T = src.loc
	var/obj/structure/cable/C = T.get_cable_node()
	var/net
	if (C)
		net = C.netnum		// find the powernet of the connected cable

	if(!net)
		powered = 0
		return 0
	var/datum/powernet/PN = powernets[net]			// find the powernet. Magic code, voodoo code.

	if(!PN)
		powered = 0
		return 0
	var/surplus = max(PN.avail-PN.load, 0)
	var/shieldload = min(rand(50,200), surplus)
	if(shieldload==0 && !storedpower)		// no cable or no power, and no power stored
		powered = 0
		return 0
	else
		powered = 1
		if(PN)
			storedpower += shieldload
			PN.newload += shieldload //uses powernet power.
			*/

/obj/machinery/shield_gen/proc/toggle()
	set background = 1
	active = !active
	power_change()
	if(active)
		var/list/covered_turfs = get_shielded_turfs()
		var/turf/T = get_turf(src)
		if(T in covered_turfs)
			covered_turfs.Remove(T)
		for(var/turf/O in covered_turfs)
			var/obj/effect/energy_field/E = new(O)
			field.Add(E)
		covered_turfs = null

		for(var/mob/M in view(5,src))
			to_chat(M, "[bicon(src)] You hear heavy droning start up.")
	else
		for(var/obj/effect/energy_field/D in field)
			field.Remove(D)
			D.loc = null

		for(var/mob/M in view(5,src))
			to_chat(M, "[bicon(src)] You hear heavy droning fade out.")

//grab the border tiles in a circle around this machine
/obj/machinery/shield_gen/proc/get_shielded_turfs()
	var/list/out = list()
	for(var/turf/T in range(field_radius, src))
		if(get_dist(src,T) == field_radius)
			out.Add(T)
	return out
