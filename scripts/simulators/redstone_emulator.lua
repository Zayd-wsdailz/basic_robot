-- REDSTONE EMULATOR & EDITOR 
--v 28/06/2018a, fixed 28/08/2022a

if not init then
	dout = function(text) say(text,"rnd") end
	seri = function(tab) 
		local out = {} for k,v in pairs(tab) do if type(v) ~= "function" then out[#out+1] = k .. " = " .. v end end 
		return "{"..table.concat(out,",") .."}"
	end
	local players = find_player(5);
	if not players then 
		name = "";
	else 
		name = players[1]
		player_ = puzzle.get_player(name)
		local inv = player_:get_inventory();
		inv:set_stack("main", 8, puzzle.ItemStack("basic_robot:control 1 0 \"@\"")) -- add controller in players inventory
		--add items for building
		inv:set_stack("main", 1, puzzle.ItemStack("default:pick_diamond"))
		inv:set_stack("main", 2, puzzle.ItemStack("basic_robot:button_283 999")) -- switch 9 = 283/284
		inv:set_stack("main", 3, puzzle.ItemStack("basic_robot:button_285 999")) -- button 7 = 285/286
		inv:set_stack("main", 4, puzzle.ItemStack("basic_robot:button_287 999")) -- equalizer 61 = 287
		inv:set_stack("main", 5, puzzle.ItemStack("basic_robot:button_288 999")) -- setter 15 = 288
		inv:set_stack("main", 6, puzzle.ItemStack("basic_robot:button_289 999")) -- piston 171 = 289
		inv:set_stack("main", 7, puzzle.ItemStack("basic_robot:button_292 999")) -- delayer 232 = 292
		inv:set_stack("main", 9, puzzle.ItemStack("basic_robot:button_291 999")) -- NOT 33 = 291
		inv:set_stack("main", 10, puzzle.ItemStack("basic_robot:button_290 999")) -- diode 175 = 290
		inv:set_stack("main", 11, puzzle.ItemStack("basic_robot:button_293 999")) -- platform 22 = 293
		inv:set_stack("main", 12, puzzle.ItemStack("basic_robot:button_294 999")) -- giver 23 150/294 
		inv:set_stack("main", 13, puzzle.ItemStack("basic_robot:button_295 999")) -- checker 24 151/295

		
		local round = math.floor; protector_position = function(pos) local r = 32;local ry = 2*r; return {x=round(pos.x/r+0.5)*r,y=round(pos.y/ry+0.5)*ry,z=round(pos.z/r+0.5)*r}; end
		local spawnblock = protector_position(self.spawnpos())
		
		local meta = puzzle.get_meta(spawnblock); 
		meta:set_string("shares", name) -- add player to protection!
		puzzle.chat_send_player(name,colorize("yellow","#EDITOR: if you need any blocks get them by using  'give me' in craft guide. you can now use controller to make links from pointed at blocks. In addition hold SHIFT to display infos. Reset block links by selecting block 2x"))
	end
	
	init = true
	self.listen_punch(self.pos()); -- attach punch listener
	self.spam(1)
	self.label(colorize("orange","REDSTONE EMULATOR/EDITOR"))
	
	


    -- 1. EMULATOR CODE
	
	
	TTL = 16 -- signal propagates so many steps before dissipate
	--self.label(colorize("red","REDSTONE")..colorize("yellow","EMULATOR"))
	opcount = 0;
	
    -- DEFINITIONS OF BLOCKS THAT CAN BE ACTIVATED 
	toggle_button_action = function(mode,pos,ttl) -- SIMPLE TOGGLE BUTTONS - SWITCH
		if not ttl or ttl <=0 then return end
		if mode == 1 then -- turn on
			puzzle.set_node(pos,{name = "basic_robot:button_284"})
			local meta = puzzle.get_meta(pos); 
			if not meta then return end
			local n = meta:get_int("n");
			for i = 1,n do activate(1,{x=meta:get_int("x"..i)+pos.x,y=meta:get_int("y"..i)+pos.y,z=meta:get_int("z"..i)+pos.z},ttl) end
		else -- turn off
			puzzle.set_node(pos,{name = "basic_robot:button_283"})
			local meta = puzzle.get_meta(pos); 
			if not meta then return end
			local n = meta:get_int("n");
			for i = 1,n do activate(0,{x=meta:get_int("x"..i)+pos.x,y=meta:get_int("y"..i)+pos.y,z=meta:get_int("z"..i)+pos.z},ttl) end
		end
	end
	

	button_action = function(mode,pos,ttl) 	-- SIMPLE ON BUTTON, TOGGLES BACK OFF after 1s
		if not ttl or ttl <=0 then return end
		if mode == 0 then return end
		puzzle.set_node(pos,{name = "basic_robot:button_286"})
		local meta = puzzle.get_meta(pos); 
		if not meta then return end
		local n = meta:get_int("n");
		
		minetest.after(1, function() 
			puzzle.set_node(pos,{name = "basic_robot:button_285"})
			for i = 1,n do activate(0,{x=meta:get_int("x"..i)+pos.x,y=meta:get_int("y"..i)+pos.y,z=meta:get_int("z"..i)+pos.z},ttl) end
		end)
		for i = 1,n do activate(1,{x=meta:get_int("x"..i)+pos.x,y=meta:get_int("y"..i)+pos.y,z=meta:get_int("z"..i)+pos.z},ttl) end
	end
	
	giver_action = function(mode,pos,ttl) 	-- GIVER: give block below it to player and activate targets
		local nodename = puzzle.get_node({x=pos.x,y=pos.y-1,z=pos.z}).name;
		if nodename == "air" then return end
		local objects =  minetest.get_objects_inside_radius(pos, 5);local player1;
		for _,obj in pairs(objects) do if obj:is_player() then player1 = obj; break end end
		if player1 then
			player1:get_inventory():add_item("main", puzzle.ItemStack(nodename))
			local meta = puzzle.get_meta(pos); 
			if not meta then return end
			local n = meta:get_int("n");
			for i = 1,n do activate(1,{x=meta:get_int("x"..i)+pos.x,y=meta:get_int("y"..i)+pos.y,z=meta:get_int("z"..i)+pos.z},ttl) end
		end
	end
	
	checker_action = function(mode,pos,ttl) 	-- CHECKER: check if player has block below it, then remove block from player and activate targets
		local nodename = puzzle.get_node({x=pos.x,y=pos.y-1,z=pos.z}).name;
		if nodename == air then return end
		local objects =  minetest.get_objects_inside_radius(pos, 5);local player1;
		for _,obj in pairs(objects) do if obj:is_player() then player1 = obj; break end end
		if player1 then
			local inv = player1:get_inventory();
			if inv:contains_item("main", puzzle.ItemStack(nodename)) then
				inv:remove_item("main",puzzle.ItemStack(nodename))
				local meta = puzzle.get_meta(pos);
				if not meta then return end
				local n = meta:get_int("n");
				for i = 1,n do activate(1,{x=meta:get_int("x"..i)+pos.x,y=meta:get_int("y"..i)+pos.y,z=meta:get_int("z"..i)+pos.z},ttl) end
			end
		end
	end
	
	equalizer_action = function(mode,pos,ttl) -- CHECK NODES AT TARGET1,TARGET2. IF EQUAL ACTIVATE TARGET3,TARGET4,...
		if not ttl or ttl <=0 then return end
		if mode == 0 then return end
		
		local meta = puzzle.get_meta(pos); 
		if not meta then return end
		local n = meta:get_int("n");
		local node1 = puzzle.get_node({x=meta:get_int("x1")+pos.x,y=meta:get_int("y1")+pos.y,z=meta:get_int("z1")+pos.z}).name
		local node2 = puzzle.get_node({x=meta:get_int("x2")+pos.x,y=meta:get_int("y2")+pos.y,z=meta:get_int("z2")+pos.z}).name
		
		
		if node1==node2 then 
			for i = 3,n do activate(1,{x=meta:get_int("x"..i)+pos.x,y=meta:get_int("y"..i)+pos.y,z=meta:get_int("z"..i)+pos.z},ttl) end
		else
			for i = 3,n do activate(0,{x=meta:get_int("x"..i)+pos.x,y=meta:get_int("y"..i)+pos.y,z=meta:get_int("z"..i)+pos.z},ttl) end
		end
	end
	
	delayer_action = function(mode,pos,ttl) -- DELAY FORWARD SIGNAL, delay determined by distance of target1 from delayer ( in seconds)
		if not ttl or ttl <=0 then return end
		local meta = puzzle.get_meta(pos);
		if not meta then return end

		local n = meta:get_int("n");
		local pos1 = {x=meta:get_int("x1"),y=meta:get_int("y1"),z=meta:get_int("z1")}
		local  delay = math.sqrt(pos1.x^2+pos1.y^2+pos1.z^2);
		
		if delay > 0 then 
			minetest.after(delay, function()
				if mode == 1 then
					for i = 2,n do activate(1,{x=meta:get_int("x"..i)+pos.x,y=meta:get_int("y"..i)+pos.y,z=meta:get_int("z"..i)+pos.z},ttl) end
				else
					for i = 2,n do activate(0,{x=meta:get_int("x"..i)+pos.x,y=meta:get_int("y"..i)+pos.y,z=meta:get_int("z"..i)+pos.z},ttl) end
				end
			end)
		end
	end
	
	diode_action = function(mode,pos,ttl) -- ONLY pass through ON signal
		if not ttl or ttl <=0 then return end
		if mode ~= 1 then return end
		local meta = puzzle.get_meta(pos);
		if not meta then return end
		local n = meta:get_int("n");
		for i = 1,n do activate(1,{x=meta:get_int("x"..i)+pos.x,y=meta:get_int("y"..i)+pos.y,z=meta:get_int("z"..i)+pos.z},ttl) end
	end
	
	not_action = function(mode,pos,ttl) -- negate signal: 0 <-> 1
		if not ttl or ttl <=0 then return end
		local meta = puzzle.get_meta(pos);
		if not meta then return end
		local n = meta:get_int("n");
		for i = 1,n do activate(1-mode,{x=meta:get_int("x"..i)+pos.x,y=meta:get_int("y"..i)+pos.y,z=meta:get_int("z"..i)+pos.z},ttl) end
	end
	
	setter_action = function(mode,pos,ttl) -- SETS NODES IN TARGET AREA TO PRESELECTED NODE
		if not ttl or ttl <=0 then return end
		if mode == 0 then return end
	
		local meta = puzzle.get_meta(pos);
		if not meta then return end
		local n = meta:get_int("n");
		if n ~= 3 then say("#setter: error, needs to be set with 3 links"); return end
		local node1 = puzzle.get_node({x=meta:get_int("x1")+pos.x,y=meta:get_int("y1")+pos.y,z=meta:get_int("z1")+pos.z})
		local pos1 = {x=meta:get_int("x2")+pos.x,y=meta:get_int("y2")+pos.y,z=meta:get_int("z2")+pos.z}
		local pos2 = {x=meta:get_int("x3")+pos.x,y=meta:get_int("y3")+pos.y,z=meta:get_int("z3")+pos.z}
		
		if pos1.x>pos2.x then pos1.x,pos2.x = pos2.x,pos1.x end
		if pos1.y>pos2.y then pos1.y,pos2.y = pos2.y,pos1.y end
		if pos1.z>pos2.z then pos1.z,pos2.z = pos2.z,pos1.z end
		
		local size = (pos2.x-pos1.x+1)*(pos2.y-pos1.y+1)*(pos2.z-pos1.z+1)
		if size > 27 then say("#setter: target area too large, more than 27 blocks!"); return end
		for x = pos1.x,pos2.x do
			for y = pos1.y,pos2.y do
				for z = pos1.z,pos2.z do
					puzzle.set_node({x=x,y=y,z=z},node1)
				end
			end
		end
	end
	
	local piston_displaceable_nodes = {["air"] = 1,["default:water_flowing"] = 1}
	
	piston_action = function(mode,pos,ttl) -- PUSH NODE AT TARGET1 AWAY FROM PISTON
		if not ttl or ttl <=0 then return end
		--if mode == 0 then return end
	
		local meta = puzzle.get_meta(pos);
		if not meta then return end
		local n = meta:get_int("n");
		if n < 1 or n>2 then say("#piston: error, needs to be set with at least link and most two"); return end
		local pos1 = {x=meta:get_int("x1")+pos.x,y=meta:get_int("y1")+pos.y,z=meta:get_int("z1")+pos.z}

		-- determine direction
		local dir = {x=pos1.x-pos.x, y= pos1.y-pos.y, z= pos1.z-pos.z};
		
		local dirabs = {x=math.abs(dir.x), y= math.abs(dir.y), z= math.abs(dir.z)};
		local dirmax = math.max(dirabs.x,dirabs.y,dirabs.z);
		
		if dirabs.x == dirmax then dir = { x = dir.x>0 and 1 or -1, y = 0,z = 0 }
		elseif dirabs.y == dirmax then dir = { x = 0, y = dir.y>0 and 1 or -1, z=0}
		else dir = {x = 0, y = 0, z = dir.z>0 and 1 or -1}
		end
		
		local pos2 = {x=pos1.x+dir.x,y=pos1.y+dir.y,z=pos1.z+dir.z};
		
		if mode == 0 then pos1,pos2 = pos2,pos1 end

		local node1 = puzzle.get_node(pos1)
		if node1.name == "air" then return end

		
		if piston_displaceable_nodes[puzzle.get_node(pos2).name] then
			puzzle.set_node(pos2, node1)
			puzzle.set_node(pos1, {name = "air"})
			minetest.check_for_falling(pos2)
			self.sound("doors_door_open",1,pos)
		end
	end
	
	platform_action = function(mode,pos,ttl) -- SPAWN MOVING PLATFORM
		
		if mode~=1 then return end
		local meta = puzzle.get_meta(pos);
		if not meta then return end
		local n = meta:get_int("n");
		if n ~= 2 then say("#platform: error, needs to be set  with 2 targets"); return end
		local pos1 = {x=meta:get_int("x1")+pos.x,y=meta:get_int("y1")+pos.y,z=meta:get_int("z1")+pos.z}
		local pos2 = {x=meta:get_int("x2")+pos.x,y=meta:get_int("y2")+pos.y,z=meta:get_int("z2")+pos.z}

		-- determine direction
		local dir = {x=pos2.x-pos1.x, y= pos2.y-pos1.y, z= pos2.z-pos1.z};
	
		local obj = minetest.add_entity(pos1, "basic_robot:projectile");
		
		if not obj then return end
		obj:setvelocity(dir);
		--obj:setacceleration({x=0,y=-gravity,z=0});
		local luaent = obj:get_luaentity();
		luaent.name = name;
		luaent.spawnpos = pos1;
		
		local nodename = puzzle.get_node({x=pos.x,y=pos.y-1,z=pos.z}).name;
		local tiles = minetest.registered_nodes[nodename].tiles; tiles = tiles or {};
		local texture = tiles[1] or "default_stone";
		obj:set_properties({visual = "cube",textures = {texture,texture,texture,texture,texture,texture},visual_size = {x=1,y=1},
		collisionbox={-0.5,-0.5,-0.5,0.5,0.5,0.5}})
	end
	
	
	-- HOW TO ACTIVATE TARGET ELEMENT - adds mesecons/basic machines compatibility
	activate = function(mode, pos, ttl)
		if not ttl or ttl <=0 then return end
		local nodename = puzzle.get_node(pos).name;
		local active_element = active_elements[nodename];
		opcount = opcount + 1
		if opcount > 64 then say("#puzzle error: opcount 64 exceeded. too many active connections."); error("#puzzle: abort") end
		
		if active_element then 
			active_element(mode,pos,ttl-1) 
		else -- try mesecons activate
			local nodename = puzzle.get_node(pos).name
			local table = minetest.registered_nodes[nodename];
			if table and table.mesecons then else return end
			
			local effector=table.mesecons.effector;
			
			if mode == 1 then
				if effector.action_on then 
					effector.action_on(pos,node,ttl)
				end
			else
				if effector.action_off then 
					effector.action_off(pos,node,ttl)
				end
			end
		end
	end
	
	-- THESE REACT WHEN PUNCHED
	interactive_elements = {
		[285] = {button_action,1}, -- BUTTON, 1 means it activates(ON) on punch
		[283] = {toggle_button_action,1}, -- TOGGLE BUTTON_OFF
		[284] = {toggle_button_action,0}, -- TOGGLE BUTTON_ON, 0 means it deactivates
		[294] = {giver_action,0}, -- GIVER: give player item below it when activated and activate targets after that
		[295] = {checker_action,0}, -- CHECKER: check if player has block below it in inventory, remove it and activate targets after that
	}
	
	-- THESE CAN BE ACTIVATED WITH SIGNAL
	active_elements = {
		["basic_robot:button_285"] = button_action, -- BUTTON, what action to do on activate
		["basic_robot:button_283"] = toggle_button_action, -- TOGGLE BUTTON_OFF
		["basic_robot:button_284"] = toggle_button_action, -- TOGGLE BUTTON_ON
		["basic_robot:button_288"] = setter_action, -- SETTER
		["basic_robot:button_287"] = equalizer_action, -- EQUALIZER
		["basic_robot:button_289"] = piston_action, -- PISTON
		["basic_robot:button_293"] = platform_action, -- PLATFORM
		["basic_robot:button_292"] = delayer_action, -- DELAYER
		["basic_robot:button_290"] = diode_action, -- DIODE
		["basic_robot:button_291"] = not_action, -- NOT
	}
	

	-- EDITOR CODE --
	
	edit = {};
	edit.state = 1; -- tool state
	edit.source = {}; edit.sourcenode = ""; -- selected source
	
	-- blocks that can be activated
	edit.active_elements = {
		["basic_robot:button_285"] = "button: now select one or more targets", -- button
		["basic_robot:button_283"] = "switch: now select one or more targets", -- switch OFF
		["basic_robot:button_284"] = "switch: now select one or more targets", -- switch ON
		["basic_robot:button_288"] = "setter: target1 defines what material wall will use, target2/3 defines where wall will be", -- setter
		["basic_robot:button_287"] = "equalizer: target1 and target2 are for comparison, other targets are activated", -- equalizer
		["basic_robot:button_289"] = "piston: push block at target1 in direction away from piston", -- equalizer
		["basic_robot:button_293"] = "platform: select target1 to set origin, target2 for direction", -- PLATFORM
		["basic_robot:button_292"] = "delayer: distance from delayer to target1 determines delay", -- delayer
		["basic_robot:button_290"] = "diode: only pass through ON signal",  -- DIODE
		["basic_robot:button_291"] = "NOT gate: negates the signal", -- NOT

		["basic_robot:button_294"] = "GIVER: give player item below it when activated and activate targets after that",
		["basic_robot:button_295"] = "CHECKER: check if player has block below it in inventory, remove it and activate targets after that",
	}
		
	linker_use = function(pos)
		if not pos then return end

		--say(serialize(player_:get_player_control()))
		if edit.state < 0 then -- link edit mode!
			local meta = puzzle.get_meta(edit.source);
			local i = -edit.state;
			meta:set_int("x" ..i, pos.x-edit.source.x); meta:set_int("y" ..i, pos.y-edit.source.y); meta:set_int("z" ..i, pos.z-edit.source.z)
			puzzle.chat_send_player(name, colorize("red", "EDIT ".. " target " .. i .. " changed"))
			edit.state = 1
			goto display_particle
		end
		
		if player_:get_player_control().sneak then -- SHOW LINKS
			local meta = puzzle.get_meta(pos);
			local n = meta:get_int("n"); 
			local nodename = puzzle.get_node(pos).name;
			local active_element = edit.active_elements[nodename]
			if active_element and edit.source.x == pos.x and edit.source.y == pos.y and edit.source.z == pos.z then -- gui with more info
				local form = "size[5,"..(0.75*n).."] label[0,-0.25; "..active_element .."]" ;
				for i = 1,n do -- add targets as lines
				  form = form .. 
				  "button[0,".. (0.75*i-0.5) .. ";1.25,1;".."S"..i..";" .. "show " .. i .. "]"..
				  "button_exit[1,".. (0.75*i-0.5) .. ";1,1;".."E"..i..";" .. "edit " .. "]" ..
				  "button_exit[2,".. (0.75*i-0.5) .. ";1.25,1;".."D"..i..";" .. "delete " .. "]"..
				  "label[3,".. (0.75*i-0.25) .. "; " .. meta:get_int("x"..i) .. " " .. meta:get_int("y"..i) .. " " .. meta:get_int("z"..i) .."]"
				end
				self.show_form(name,form);
				edit.state = 3;
				return
			end
			edit.source = {x=pos.x,y=pos.y, z=pos.z};
			edit.state = 1
			if not active_element then return end
			local i = string.find(active_element,":");
			if not i then return end
			puzzle.chat_send_player(name,colorize("red","#INFO ".. string.sub(active_element,1,i-1) ..":") .." has " .. n .. " targets. Select again for more info.")
			meta:set_string("infotext",string.sub(active_element,1,i-1)) -- write name of element on it!
			
			for i = 1, n do
				minetest.add_particle(
				{
					pos = {x=meta:get_int("x"..i)+pos.x,y=meta:get_int("y"..i)+pos.y,z=meta:get_int("z"..i)+pos.z},
					expirationtime = 5,
					velocity = {x=0, y=0,z=0},
					size = 18,
					texture = "puzzle_button_on.png",
					acceleration = {x=0,y=0,z=0},
					collisiondetection = true,
					collision_removal = true,			
				}
				)
			end
			return
		end
	
		if edit.state == 1 then -- SET SOURCE
			local nodename = puzzle.get_node(pos).name;
			local active_element = edit.active_elements[nodename]
			if not active_element then puzzle.chat_send_player(name,colorize("red","#ERROR linker:").. " source must be valid element like switch"); return end
			edit.source = {x=pos.x,y=pos.y, z=pos.z};
			sourcenode = nodename;
			puzzle.chat_send_player(name, colorize("yellow","SETUP " ..edit.state .. ": ").. active_element)
			edit.state = 2
		else -- SET TARGET
			local meta = puzzle.get_meta(edit.source);
			local n = meta:get_int("n"); 
			
			if edit.state == 2 and pos.x == edit.source.x and pos.y == edit.source.y and pos.z == edit.source.z then -- RESET LINK FOR SOURCE
				local meta = puzzle.get_meta(pos);meta:set_int("n",0) -- reset links
				puzzle.chat_send_player(name, colorize("red", "SETUP " .. edit.state .. ":") .. " resetted links for selected source.")
				edit.state = 1;return
			else
				n=n+1;
				meta:set_int("x"..n, pos.x-edit.source.x);meta:set_int("y"..n, pos.y-edit.source.y);meta:set_int("z"..n, pos.z-edit.source.z) -- relative to source!
				meta:set_int("n",n)
				puzzle.chat_send_player(name, colorize("red", "SETUP "..edit.state .. ":") .. " added target #"  .. n)
				edit.state = 1
			end
		end
		
		-- display
		::display_particle::
		
		minetest.add_particle(
		{
			pos = pos,
			expirationtime = 5,
			velocity = {x=0, y=0,z=0},
			size = 18,
			texture = "puzzle_button_off.png",
			acceleration = {x=0,y=0,z=0},
			collisiondetection = true,
			collision_removal = true,			
		}
		)
	end
	
	tools = {
		["basic_robot:control"] = linker_use
	}
	
	------ END OF EDIT PROGRAM
	
end

opcount = 0
event = keyboard.get() --  handle keyboard

if event and not player_:get_player_control().sneak then
	if event.type == 0 then -- EDITING
		if event.puncher == name then -- players in protection can edit -- not minetest.is_protected({x=event.x,y=event.y,z=event.z},event.puncher)
			local wield_item = player_:get_wielded_item():get_name()
			local tool = tools[wield_item]
			if tool then tool({x=event.x,y=event.y,z=event.z}) end
		end
	else -- EMULATOR
		local typ = event.type;
		local interactive_element = interactive_elements[typ]
		if interactive_element then 
			interactive_element[1](interactive_element[2],{x=event.x,y=event.y,z=event.z},TTL) 
			self.sound("doors_glass_door_open",1,{x=event.x,y=event.y,z=event.z})
		end		
	end
end


sender,fields = self.read_form() -- handle gui for editing
if sender then
	edit.state = 1
	for k,_ in pairs(fields) do
		local c = string.sub(k,1,1);
		local i = tonumber(string.sub(k,2)) or 1;
		if c == "S" then 

			local meta = puzzle.get_meta(edit.source);
			minetest.add_particle(
			{
				pos = {x=meta:get_int("x"..i)+edit.source.x,y=meta:get_int("y"..i)+edit.source.y,z=meta:get_int("z"..i)+edit.source.z},
				expirationtime = 5,
				velocity = {x=0, y=0,z=0},
				size = 18,
				texture = "puzzle_button_on.png",
				acceleration = {x=0,y=0,z=0},
				collisiondetection = true,
				collision_removal = true,			
			}
			)
		elseif c == "E" then
			edit.state =  -i;
			puzzle.chat_send_player(name, colorize("yellow", "#EDIT: select target " .. i));
		elseif c == "D" then
			local meta = puzzle.get_meta(edit.source);
			local n = meta:get_int("n")
			if n > 0 then
				for j = i,n-1 do
					meta:set_int("x"..j, meta:get_int("x"..(j+1)))
					meta:set_int("y"..j, meta:get_int("y"..(j+1)))
					meta:set_int("z"..j, meta:get_int("z"..(j+1)))
				end
				meta:set_int("n",n-1)
			end
			puzzle.chat_send_player(name, colorize("red", "#EDIT: target " .. i .. " deleted"));
		end
		--say(serialize(fields))
	end
end