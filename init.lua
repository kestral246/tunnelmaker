-- tunnelmaker
-- Another tunnel digging mod for minetest.
-- Digs tunnels and builds simple bridges for advtrains track, supporting
-- all 16 track directions, along with slopes up and down.
-- 
-- by David G (kestral246@gmail.com)
-- and by Mikola

-- Version 2.2.1 - 2022-12-28
--   Add German translations from xenonca.
--   Another minor remove references issue.

-- Version 2.2.0 - 2022-08-15
--   Pull request from rlars: Allow access to dig_tunnel for other mods.
--   Validate tunnel_lights setting, and if invalid use default:torch instead.

-- Controls for operation
-------------------------
-- Left-click: dig one node.
-- Shift left-click: bring up User Options menu. (Or use Aux right-click in Android.)
-- Right-click: dig tunnel based on direction player pointing.
-- Shift right-click: cycle through vertical digging directions.

-- Icon display based on compassgps 2.7 and compass 0.5

-- To the extent possible under law, the author(s) have dedicated all copyright and related
-- and neighboring rights to this software to the public domain worldwide. This software is
-- distributed without any warranty.

-- You should have received a copy of the CC0 Public Domain Dedication along with this
-- software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.


-- User Options defaults (for minetest.conf)
-------------------------------------------
-- Initial digging mode for User Options (1, 2, or 3).
-- 1 = General purpose, 2 = Advanced trains, 3 = Bike paths.
local tunnel_mode_default = tonumber(minetest.settings:get("tunnel_digging_mode") or 2)

-- Train tunnels can be lined with a coating.
local add_lined_tunnels_default = minetest.settings:get_bool("add_lined_tunnels", false)

-- Continuous updown digging, which allows digging up/down multiple times without resetting mode.
local continuous_updown_default = minetest.settings:get_bool("continuous_updown_digging", false)

-- Enable desert mode - can use different materials when in the desert. Requires Minetest 5.0+.
-- When desert mode is enabled, user gets additional option to Lock desert mode to current state
-- of being in desert or not. Useful to define materials used when in desert transition regions.
local add_desert_material = minetest.settings:get_bool("add_desert_material", false)

-- Can use other lights in tunnels instead of torches.
local lighting_raw = minetest.settings:get("tunnel_lights") or "default:torch"

-- Determine is light specifies param2. This allows lights such as mydefaultlights:ceiling_light_white,20 where ,20 specifies ceiling orientation in param2
local lighting = lighting_raw
local lighting_p2 = 0
local p2 = string.find(lighting_raw, ',')
if p2 ~= nil then
	lighting = string.sub(lighting_raw, 1, p2-1)
	lighting_p2 = tonumber(string.sub(lighting_raw, p2+1) or 0)
end

-- Set height for train tunnels (5 to 8). Currently matching version 1.
local tunnel_height_train = tonumber(minetest.settings:get("train_tunnel_height") or 5)

-- Train tunnels (only) can have "arches" along the sides.
local add_arches_config = minetest.settings:get_bool("train_tunnel_arches", true)

-- Configuration variables
-- (If you'd really like some of these available to minetest.conf, request them.)
--------------------------
-- Tunnel height, can vary for each digging mode.
local tunnel_height_general = 4
local tunnel_height_bike = 5

-- Material for walls and floors (general and train path beyond embankment).
local tunnel_material = "default:stone"
local tunnel_material_desert = "default:desert_stone"

-- Material for train track embankment
local embankment = "default:gravel"

-- Material for reference marks to help laying advtrains track.
-- This should be a fairly uncommon material with a distinctive look.
-- If this is changed, old reference marks won't be able to be removed by tunnelmaker tool.
local reference_marks = "default:stone_block"

-- Time that reference marks are removed when this command enabled by the user.
local remove_refs_enable_time = 120

-- Material for bike paths.
local bike_path_material = "default:cobble"
local slab_not_desert = "stairs:slab_cobble"
local angled_slab_not_desert = "angledstairs:angled_slab_left_cobble"
local angled_stair_not_desert = "angledstairs:angled_stair_left_cobble"

local bike_path_material_desert = "default:desert_cobble"
local slab_desert = "stairs:slab_desert_cobble"
local angled_slab_desert = "angledstairs:angled_slab_left_desert_cobble"
local angled_stair_desert = "angledstairs:angled_stair_left_desert_cobble"

-- Material for coating for walls in the water.
local glass_walls = "default:glass"

-- Max height to clear trees and other brush, when clear tree cover enabled.
local clear_trees_max = 30

-- Lights are placed in tunnel ceilings to light the way.
local add_lighting = true

-- Light spacing: 1 for default:torch, 2 for brighter lights like default:mese_post_light.
-- Checked after mods loaded, so lights in mods don't need to be a dependency.
local lighting_search_radius = 1

-- Angledstairs mod gives much nicer bike path diagonal slopes.
local angledstairs_exists = false
if minetest.registered_nodes["angledstairs:angled_slab_left_cobble"] then
	angledstairs_exists = true
end

-- Determine if lights for tunnels support multiple orientations like torches.
-- Ceiling version should be defined in minetest.conf, but don't want other orientations to be deleted either.
local multi_orient = false
local base_lighting = ""
-- End of configuration


-- Require "tunneling" priviledge to be able to user tunnelmaker tool.
minetest.register_privilege("tunneling", {description = "Allow use of tunnelmaker tool"})

-- Support client-side translations
local S = minetest.get_translator(minetest.get_current_modname())

-- Define top level variable to maintain per player state
tunnelmaker = {}
local user_config = {}

-- Adjust light spacing and deal with multi-orientation lights.
minetest.register_on_mods_loaded(function()
	if minetest.registered_nodes[lighting] == nil then
		minetest.log("warning", "Tunnelmaker: Setting for tunnel_lights ("..lighting..") invalid. Using default:torch instead.")
		lighting = "default:torch"
		lighting_p2 = 0
	end
	if minetest.registered_nodes[lighting].light_source > 13 then
		lighting_search_radius = 2
	end
	if minetest.registered_nodes[lighting].drop then
		multi_orient = true
		base_lighting = minetest.registered_nodes[lighting].drop
		-- minetest.debug("base = "..base_lighting)  -- debug
	end
end)

-- Initialize player's state when player joins
minetest.register_on_joinplayer(function(player)
	local pname = player:get_player_name()
	tunnelmaker[pname] = {updown = 0, lastdir = -1, lastpos = {x = 0, y = 0, z = 0}}
	if tunnel_mode_default == 1 then
		user_config[pname] = {
			digging_mode = 1,  -- General purpose mode
			height = tunnel_height_general,
			add_arches = false,
			add_embankment = false,
			add_refs = false,
			add_floors = add_lined_tunnels_default,
			add_wide_floors = add_lined_tunnels_default,
			add_bike_ramps = false,
			add_lined_tunnels = add_lined_tunnels_default,
			continuous_updown = continuous_updown_default,
			lock_desert_mode = false,
			clear_trees = 0,
			remove_refs = 0,
			use_desert_material = add_desert_material and minetest.get_biome_data and
				string.match(minetest.get_biome_name(minetest.get_biome_data(player:get_pos()).biome), "desert"),
			coating_not_desert = tunnel_material,
			coating_desert = tunnel_material_desert,
		}
	elseif tunnel_mode_default == 2 then
		user_config[pname] = {
			digging_mode = 2,  -- Advanced train mode
			height = tunnel_height_train,
			add_arches = add_arches_config,
			add_embankment = true,
			add_refs = true,
			add_floors = true,
			add_wide_floors = add_lined_tunnels_default,
			add_bike_ramps = false,
			add_lined_tunnels = add_lined_tunnels_default,
			continuous_updown = continuous_updown_default,
			lock_desert_mode = false,
			clear_trees = 0,
			remove_refs = 0,
			use_desert_material = add_desert_material and minetest.get_biome_data and
				string.match(minetest.get_biome_name(minetest.get_biome_data(player:get_pos()).biome), "desert"),
			coating_not_desert = tunnel_material,
			coating_desert = tunnel_material_desert,
		}
	else
		user_config[pname] = {
			digging_mode = 3,  -- Bike path mode
			height = tunnel_height_bike,
			add_arches = false,
			add_embankment = false,
			add_refs = true,
			add_floors = true,
			add_wide_floors = add_lined_tunnels_default,
			add_bike_ramps = true,
			add_lined_tunnels = add_lined_tunnels_default,
			continuous_updown = continuous_updown_default,
			lock_desert_mode = false,
			clear_trees = 0,
			remove_refs = 0,
			use_desert_material = add_desert_material and minetest.get_biome_data and
				string.match(minetest.get_biome_name(minetest.get_biome_data(player:get_pos()).biome), "desert"),
			coating_not_desert = bike_path_material,
			coating_desert = bike_path_material_desert,
		}
	end
end)

-- Delete player's state when player leaves
minetest.register_on_leaveplayer(function(player)
	local pname = player:get_player_name()
	if tunnelmaker[pname] then tunnelmaker[pname] = nil end
	if user_config[pname] then user_config[pname] = nil end
end)

local activewidth=8  -- until I can find some way to get it from minetest

minetest.register_globalstep(function(dtime)
	local players  = minetest.get_connected_players()
	for i,player in ipairs(players) do

		local gotatunnelmaker=false
		local wielded=false
		local activeinv=nil
		local stackidx=0
		-- first check to see if the user has a tunnelmaker, because if they don't
		-- there is no reason to waste time calculating bookmarks or spawnpoints.
		local wielded_item = player:get_wielded_item():get_name()
		if string.sub(wielded_item, 0, 16) == "tunnelmaker:tool" then
			-- if the player is wielding a tunnelmaker, change the wielded image
			wielded=true
			stackidx=player:get_wield_index()
			gotatunnelmaker=true
		else
			-- check to see if tunnelmaker is in active inventory
			if player:get_inventory() then
				-- is there a way to only check the activewidth items instead of entire list?
				-- problem being that arrays are not sorted in lua
				for i,stack in ipairs(player:get_inventory():get_list("main")) do
					if i<=activewidth and string.sub(stack:get_name(), 0, 16) == "tunnelmaker:tool" then
						activeinv=stack  -- store the stack so we can update it later with new image
						stackidx=i  -- store the index so we can add image at correct location
						gotatunnelmaker=true
						break
					end
				end
			end
		end

		-- don't mess with the rest of this if they don't have a tunnelmaker
		if gotatunnelmaker then
			local pname = player:get_player_name()
			local dir = player:get_look_horizontal()
			local angle_relative = math.deg(dir)
			local rawdir = math.floor((angle_relative/22.5) + 0.5)%16
			local distance2 = function(x, y, z)
				return x*x + y*y + z*z
			end
			-- Calculate distance player has moved since setting up or down
			local delta = distance2((player:get_pos().x - tunnelmaker[pname].lastpos.x),
									(player:get_pos().y - tunnelmaker[pname].lastpos.y),
									(player:get_pos().z - tunnelmaker[pname].lastpos.z))
			
			-- If rotate to different direction, or move far enough from set position, reset to horizontal
			if rawdir ~= tunnelmaker[pname].lastdir or (not user_config[pname].continuous_updown and delta > 0.2) then  -- tune to make distance moved feel right
				tunnelmaker[pname].lastdir = rawdir
				-- tunnelmaker[pname].lastpos = pos
				tunnelmaker[pname].updown = 0  -- reset updown to horizontal
			end
			local tunnelmaker_image = rawdir  -- horizontal digging maps to 0-15
			if tunnelmaker[pname].updown ~= 0 and rawdir % 2 == 0 then  -- only 0,45,90 are updown capable (U:16-23,D:24-31)
				tunnelmaker_image = 16 + (tunnelmaker[pname].updown - 1) * 8 + (rawdir / 2)
			end
			-- update tunnelmaker image to point at target
			if wielded then
				player:set_wielded_item("tunnelmaker:tool"..tunnelmaker_image)
			elseif activeinv then
				player:get_inventory():set_stack("main",stackidx,"tunnelmaker:tool"..tunnelmaker_image)
			end
		end
	end
end)

local images = {
		"tunnelmaker_0.png", "tunnelmaker_1.png", "tunnelmaker_2.png", "tunnelmaker_3.png",
		"tunnelmaker_4.png", "tunnelmaker_5.png", "tunnelmaker_6.png", "tunnelmaker_7.png",
		"tunnelmaker_8.png", "tunnelmaker_9.png", "tunnelmaker_10.png", "tunnelmaker_11.png",
		"tunnelmaker_12.png", "tunnelmaker_13.png", "tunnelmaker_14.png", "tunnelmaker_15.png",
		-- up [0, 2, .., 14]
		"tunnelmaker_16.png", "tunnelmaker_17.png", "tunnelmaker_18.png", "tunnelmaker_19.png",
		"tunnelmaker_20.png", "tunnelmaker_21.png", "tunnelmaker_22.png", "tunnelmaker_23.png",
		-- down [0, 2, .., 14]
		"tunnelmaker_24.png", "tunnelmaker_25.png", "tunnelmaker_26.png", "tunnelmaker_27.png",
		"tunnelmaker_28.png", "tunnelmaker_29.png", "tunnelmaker_30.png", "tunnelmaker_31.png",
}

-- Tests whether position is in desert-type biomes, such as desert, sandstone_desert, cold_desert, etc.
-- Always just returns false if can't determine biome (i.e., using 0.4.x version).
local is_desert = function(user, pos)
	local pname = user:get_player_name()
	if add_desert_material and minetest.get_biome_data then
		if user_config[pname].lock_desert_mode then
			return user_config[pname].use_desert_material
		else
			local cur_biome = minetest.get_biome_name( minetest.get_biome_data(pos).biome )
			return string.match(cur_biome, "desert")
		end
	else
		return false
	end
end

-- Returns correct lining material based on whether to use desert or not.
local lining_material = function(user, pos)
	local pname = user:get_player_name()
	if is_desert(user, pos) then
		return user_config[pname].coating_desert
	else
		return user_config[pname].coating_not_desert
	end
end

-- Tests whether node is flammable, mainly vegetation.
local is_flammable = function(name)
	local group_flammable = false
	if minetest.registered_nodes[name] then
		group_flammable = minetest.registered_nodes[name].groups.flammable and minetest.registered_nodes[name].groups.flammable > 0
	end
	return group_flammable
end

-- Test for torch or defined tunnel_lights (including multi-orientation versions).
local is_light = function(name)
	local light = false
	if minetest.registered_nodes[name] then
		if minetest.registered_nodes[name].drop then  -- multi-orient light, so compare with base light
			local base = minetest.registered_nodes[name].drop
			light = (base == "default:torch") or (multi_orient and base == base_lighting)
		else  -- not multi-orient or is base light
			light = (name == lighting) or (name == base_lighting)
		end
	end
	return light
end

-- Combine all the checks to determine if digging should be allowed.
-- Currently supports area protection, unbreakable, and can_dig(). Others TBD.
local ok_to_tunnel = function(user, pos, name)
	if minetest.is_protected(pos, user:get_player_name()) then
		--minetest.debug("Protection error")
		return false
	elseif not (minetest.get_item_group(name, "unbreakable") == 0) then  -- Unbreakable
		--minetest.debug("Unbreakable node = "..name)
		return false
	elseif minetest.registered_nodes[name] and minetest.registered_nodes[name].can_dig ~= nil then
		--minetest.debug("Test can_dig = "..name)
		return minetest.registered_nodes[name].can_dig(pos, user)
	else
		return true
	end
end

-- Support on_dignodes callbacks like used in borders mod for barriers.
local call_on_dignodes = function(pos, node, user)
	for _, callback in ipairs(core.registered_on_dignodes) do
		local pos_copy = {x=pos.x, y=pos.y, z=pos.z}
		local node_copy = {name=node.name, param1=node.param1, param2=node.param2}
		callback(pos_copy, node_copy, user)
	end
end

-- Lookup table to map direction to appropriate rotation for angled_stair_left nodes.
local astairs_lu = {
	[-1] ={[2]=1,[6]=0,[10]=3,[14]=2},  -- down
	[1] = {[2]=3,[6]=2,[10]=1,[14]=0}  -- up
}

local region  -- Declare so I can use these functions recursively.
region = {
	[0] =  -- Null.
		function(x, y, z, dir, user, pointed_thing)
		end,
	[1] =  -- Air. Don't delete lights or track. (Works with torches, but not with ceiling mounted lamps.)
		function(x, y, z, dir, user, pointed_thing)
			local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
			local node = minetest.get_node(pos)
			--if ok_to_tunnel(user, pos, node.name) then
				if not (node.name == "air" or is_light(node.name) or string.match(node.name, "dtrack")) then
					minetest.set_node(pos, {name = "air"})
					call_on_dignodes(pos, node, user)
				end
			--end
		end,
	[2] =  -- Ceiling.
		function(x, y, z, dir, user, pointed_thing)
			local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
			local node = minetest.get_node(pos)
			--if ok_to_tunnel(user, pos, node.name) then
				local pname = user:get_player_name()
				if string.match(node.name, "water") then  -- Always line water with glass.
					minetest.set_node(pos, {name = glass_walls})
					call_on_dignodes(pos, node, user)
				elseif user_config[pname].add_lined_tunnels and user_config[pname].digging_mode ~= 3 then  -- Line tunnel ...
					if not (node.name == "air" or node.name == glass_walls or node.name == "default:snow" or is_flammable(node.name)) then  -- except for these.
						minetest.set_node(pos, {name = lining_material(user, pos)})
						call_on_dignodes(pos, node, user)
					end
				else  -- Don't line tunnel, but convert sand to sandstone and gravel to cobble.
					if string.match(node.name, "default:sand") then
						minetest.set_node(pos, {name = "default:sandstone"})
						call_on_dignodes(pos, node, user)
					elseif string.match(node.name, "default:desert_sand") then
						minetest.set_node(pos, {name = "default:desert_sandstone"})
						call_on_dignodes(pos, node, user)
					elseif string.match(node.name, "default:silver_sand") then
						minetest.set_node(pos, {name = "default:silver_sandstone"})
						call_on_dignodes(pos, node, user)
					elseif string.match(node.name, "default:gravel") then
						minetest.set_node(pos, {name = "default:cobble"})
						call_on_dignodes(pos, node, user)
					end
				end
				if user_config[pname].clear_trees > 0 then  -- Check if need to clear tree cover above dig.
					for i = y, clear_trees_max do
						local posi = vector.add(pointed_thing.under, {x=x, y=i, z=z})
						local nodei = minetest.get_node(posi)
						-- Add check for protection above tunnel.
						if ok_to_tunnel(user, posi, nodei.name) then
							if nodei.name == "default:snow" or is_flammable(nodei.name) then
								minetest.set_node(posi, {name = "air"})
								call_on_dignodes(posi, nodei, user)
							elseif nodei.name ~= "air" then
								break
							end
						else
							user_config[pname].clear_trees = 0  -- Disable clear_trees on protection error.
							minetest.chat_send_player(pname, "Tunnelmaker can't clear trees—area above protected.")
							minetest.log("action", pname.." tried to use tunnelmaker to clear trees at protected position "..minetest.pos_to_string(pointed_thing.under))
							break
						end
					end
				end
			--end
		end,
	[3] =  -- Side walls.
		function(x, y, z, dir, user, pointed_thing)
			local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
			local node = minetest.get_node(pos)
			--if ok_to_tunnel(user, pos, node.name) then
				local pname = user:get_player_name()
				if string.match(node.name, "water") then
					minetest.set_node(pos, {name = glass_walls})  -- Always line water with glass.
					call_on_dignodes(pos, node, user)
				elseif user_config[pname].add_lined_tunnels and user_config[pname].digging_mode ~= 3 then  -- Line tunnel ...
					if not (node.name == "air" or node.name == glass_walls or node.name == "default:snow" or is_flammable(node.name) or string.match(node.name, "dtrack")) then  -- except for these.
						minetest.set_node(pos, {name = lining_material(user,pos)})
						call_on_dignodes(pos, node, user)
					end
				end
			--end
		end,
	[4] =  -- Temporary endcaps.
		function(x, y, z, dir, user, pointed_thing)
			local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
			local node = minetest.get_node(pos)
			--if ok_to_tunnel(user, pos, node.name) then
				if string.match(node.name, "water") then  -- Place temporary endcap if water.
					minetest.set_node(pos, {name = glass_walls})
					call_on_dignodes(pos, node, user)
				end
			--end
		end,
	[5] =  -- Reference markers.
		function(x, y, z, dir, user, pointed_thing)
			local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
			local node = minetest.get_node(pos)
			--if ok_to_tunnel(user, pos, node.name) then
				local pname = user:get_player_name()
				-- Figure out what replacement material should be.
				local rep_mat
				if user_config[pname].add_refs then  -- Add reference marks.
					if user_config[pname].add_embankment then
						rep_mat = embankment
					else
						rep_mat = lining_material(user, pos)
					end
					minetest.set_node(pos, {name = reference_marks})
					call_on_dignodes(pos, node, user)
					local meta = minetest.get_meta(pos)
					meta:set_string("replace_with", rep_mat)
				else  -- No refs.
					if user_config[pname].add_floors or string.match(node.name, "water") or node.name == "air" or node.name == glass_walls or node.name == "default:snow" or is_flammable(node.name) then
						minetest.set_node(pos, {name = lining_material(user, pos)})
						call_on_dignodes(pos, node, user)
					end
				end
			--end
		end,
	[6] =  -- Embankment area.
		function(x, y, z, dir, user, pointed_thing)
			local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
			local node = minetest.get_node(pos)
			--if ok_to_tunnel(user, pos, node.name) then
				local pname = user:get_player_name()
				if user_config[pname].add_floors then  -- Going to set all.
					if user_config[pname].add_embankment then
						minetest.set_node(pos, {name = embankment, param2 = 42})
						call_on_dignodes(pos, node, user)
					else
						minetest.set_node(pos, {name = lining_material(user, pos)})
						call_on_dignodes(pos, node, user)
					end
				else  -- Only fill holes.
					if string.match(node.name, "water") or node.name == "air" or node.name == glass_walls or node.name == "default:snow" or is_flammable(node.name) then
						minetest.set_node(pos, {name = lining_material(user, pos)})
						call_on_dignodes(pos, node, user)
					end
				end
			--end
		end,
	[7] =  -- Wide floors. (starting to refine)
		function(x, y, z, dir, user, pointed_thing)
			local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
			local node = minetest.get_node(pos)
			--if ok_to_tunnel(user, pos, node.name) then
				local pname = user:get_player_name()
				if user_config[pname].add_floors and user_config[pname].add_wide_floors then
					local pos0 = vector.add(pos, {x=0, y=-1, z=0})
					local node0 = minetest.get_node(pos0)
					if not ((node0.name == user_config[pname].coating_desert or node0.name == user_config[pname].coating_not_desert) and node0.param2 == 7) and  -- Exception to match diagonal up and down digging.
							not (user_config[pname].add_embankment and ((node.name == embankment and node.param2 == 42) or node.name == reference_marks)) and  -- Don't overwrite embankment or refs in train mode.
							not (user_config[pname].add_bike_ramps and node.name == reference_marks) then  -- Don't overwrite refs in bike mode.
						minetest.set_node(pos, {name = lining_material(user, pos), param2 = 7})
						call_on_dignodes(pos, node, user)
					end
				else  -- Not wide. However, this makes double-wide glass when digging at water surface level.
					if string.match(node.name, "water") then
						minetest.set_node(pos, {name = glass_walls})
						call_on_dignodes(pos, node, user)
					end
				end
			--end
		end,
	[8] =  -- Underfloor, only used directly for slope up and slope down where embankment or brace is always needed.
		function(x, y, z, dir, user, pointed_thing)
			local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
			local node = minetest.get_node(pos)
			--if ok_to_tunnel(user, pos, node.name) then
				minetest.set_node(pos, {name = lining_material(user, pos)})
				call_on_dignodes(pos, node, user)
			--end
		end,
	[10] =  -- Bike slope down narrow (air or angled slab).
		function(x, y, z, dir, user, pointed_thing)
			local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
			local pname = user:get_player_name()
			local name = minetest.get_node(pos).name
			if user_config[pname].add_bike_ramps and angledstairs_exists then
				if not (name == angled_slab_desert or name == angled_slab_not_desert) then  -- Don't overwrite angled_slab on ref when going diagonally down.
					region[1](x, y, z, dir, user, pointed_thing)
				end
			else
				region[1](x, y, z, dir, user, pointed_thing)
			end
		end,
	[11] =  -- Bike slope up or down narrow (air or angled slab).
		function(x, y, z, dir, user, pointed_thing)
			local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
			local node = minetest.get_node(pos)
			--if ok_to_tunnel(user, pos, node.name) then
				local pname = user:get_player_name()
				if user_config[pname].add_bike_ramps and angledstairs_exists then
					if is_desert(user, pos) then
						minetest.set_node(pos, {name = angled_slab_desert, param2 = astairs_lu[dir.vert][dir.horiz]})
						call_on_dignodes(pos, node, user)
					else
						minetest.set_node(pos, {name = angled_slab_not_desert, param2 = astairs_lu[dir.vert][dir.horiz]})
						call_on_dignodes(pos, node, user)
					end
				else
					region[1](x, y, z, dir, user, pointed_thing)
				end
			--end
		end,
	[12] =  -- Bike slope up or down narrow (slab or angled stair).
		function(x, y, z, dir, user, pointed_thing)
			local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
			local node = minetest.get_node(pos)
			--if ok_to_tunnel(user, pos, node.name) then
				local pname = user:get_player_name()
				if user_config[pname].add_bike_ramps then
					if angledstairs_exists and math.fmod(dir.horiz, 4) == 2 then  -- diagonal slope
						if is_desert(user, pos) then
							minetest.set_node(pos, {name = angled_stair_desert, param2 = astairs_lu[dir.vert][dir.horiz]})
							call_on_dignodes(pos, node, user)
						else
							minetest.set_node(pos, {name = angled_stair_not_desert, param2 = astairs_lu[dir.vert][dir.horiz]})
							call_on_dignodes(pos, node, user)
						end
					else  -- no angledstairs
						if is_desert(user, pos) then
							minetest.set_node(pos, {name = slab_desert, param2 = 2})
							call_on_dignodes(pos, node, user)
						else
							minetest.set_node(pos, {name = slab_not_desert, param2 = 2})
							call_on_dignodes(pos, node, user)
						end
					end
				else
					region[1](x, y, z, dir, user, pointed_thing)
				end
			--end
		end,
	[13] =  -- Bike slope wide up or down (slabs).
		function(x, y, z, dir, user, pointed_thing)
			local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
			local node = minetest.get_node(pos)
			--if ok_to_tunnel(user, pos, node.name) then
				local pname = user:get_player_name()
				if user_config[pname].add_bike_ramps and user_config[pname].add_wide_floors then
					if is_desert(user, pos) then
						minetest.set_node(pos, {name = slab_desert, param2 = 2})
						call_on_dignodes(pos, node, user)
					else
						minetest.set_node(pos, {name = slab_not_desert, param2 = 2})
						call_on_dignodes(pos, node, user)
					end
				else
					region[1](x, y, z, dir, user, pointed_thing)
				end
			--end
		end,
	[19] =  -- Bike slopes. Don't remove bike slopes placed by previous down slope.
		function(x, y, z, dir, user, pointed_thing)
			local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
			local pname = user:get_player_name()
			local node = minetest.get_node(pos)
			if not user_config[pname].add_bike_ramps or
					(user_config[pname].add_bike_ramps and
					not ((node.name == slab_not_desert or node.name == slab_desert) and node.param2 == 2) and
					not (node.name == angled_slab_not_desert or node.name == angled_slab_desert)) then
				region[1](x, y, z, dir, user, pointed_thing)
			end
		end,
	[21] =  -- Arch or air, (use for arch).
		function(x, y, z, dir, user, pointed_thing)
			local pname = user:get_player_name()
			if user_config[pname].add_arches then  -- arches
				region[2](x, y, z, dir, user, pointed_thing)
			else
				region[1](x, y, z, dir, user, pointed_thing)
			end
		end,
	[30] =  -- Wall or null (based on arches).
		function(x, y, z, dir, user, pointed_thing)
			local pname = user:get_player_name()
			if not user_config[pname].add_arches then
				region[3](x, y, z, dir, user, pointed_thing)
			end
		end,
	[32] =  -- Wall or ceiling, (use above arch).
		function(x, y, z, dir, user, pointed_thing)
			local pname = user:get_player_name()
			if user_config[pname].add_arches then
				region[3](x, y, z, dir, user, pointed_thing)
			else
				region[2](x, y, z, dir, user, pointed_thing)
			end
		end,
	[37] =  -- Floor under wall. Only place floor under wall if wall right above floor.
		function(x, y, z, dir, user, pointed_thing)
			local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
			local node = minetest.get_node(pos)
			--if ok_to_tunnel(user, pos, node.name) then
				local pname = user:get_player_name()
				local pos1 = vector.add(pos, {x=0, y=1, z=0})
				local name1 = minetest.get_node(pos1).name
				if string.match(node.name, "water") then
					minetest.set_node(pos, {name = glass_walls})
					call_on_dignodes(pos, node, user)
				elseif name1 == user_config[pname].coating_not_desert or name1 == user_config[pname].coating_desert then
					minetest.set_node(pos, {name = lining_material(user, pos)})
					call_on_dignodes(pos, node, user)
				end
			--end
		end,
	[40] =  -- Endcap or null (based on arches).
		function(x, y, z, dir, user, pointed_thing)
			local pname = user:get_player_name()
			if not user_config[pname].add_arches then
				region[4](x, y, z, dir, user, pointed_thing)
			end
		end,
	[77] =  -- Add light.
		function(x, y, z, dir, user, pointed_thing)
			local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
			local name = minetest.get_node(pos).name
			--if ok_to_tunnel(user, pos, name) then
				region[1](x, y, z, dir, user, pointed_thing)
				name = minetest.get_node(pos).name  -- Should now be air, unless undiggable.
				if add_lighting and name == "air" then
					local pname = user:get_player_name()
					local pos1 = vector.add(pos, {x=0, y=1, z=0})
					local name1 = minetest.get_node(pos1).name
					if name1 == "air" then  -- Sometimes ceiling is one node higher.
						local name2 = minetest.get_node(vector.add(pos1, {x=0, y=1, z=0})).name
						if (name2 == user_config[pname].coating_not_desert or name2 == "default:stone" or name2 == user_config[pname].coating_desert or name2 == "default:desert_stone" or name2 == glass_walls) and
									minetest.find_node_near(pos1, lighting_search_radius, {name = lighting}) == nil then
							minetest.set_node(pos1, {name = lighting, param2 = lighting_p2})
						end
					else  -- Regular height ceiling.
						if (name1 == user_config[pname].coating_not_desert or name1 == "default:stone" or name1 == user_config[pname].coating_desert or name1 == "default:desert_stone" or name1 == glass_walls) and
								minetest.find_node_near(pos, lighting_search_radius, {name = lighting}) == nil then
							minetest.set_node(pos, {name = lighting, param2 = lighting_p2})
						end
					end
				end
			--end
		end,
	[86] =  -- Underfloor under embankment.
		function(x, y, z, dir, user, pointed_thing)
			local pname = user:get_player_name()
			if user_config[pname].add_floors and user_config[pname].add_embankment then
				region[8](x, y, z, dir, user, pointed_thing)
			end
		end,
	[87] =  -- Underfloor under wide floor.
		function(x, y, z, dir, user, pointed_thing)
			local pname = user:get_player_name()
			if user_config[pname].add_floors and user_config[pname].add_wide_floors then
				region[8](x, y, z, dir, user, pointed_thing)
			end
		end,
}

-- Add flips and rotates so I only need to define the seven basic digging patterns.
-- For flip: 1 = vertical, -1 = horizontal, 2 = both.
-- For rotate: 1 = clockwise, -1 = counterclockwise.

local fliprot = function(xzpos, f, r)
	local xzres = {xzpos[1], xzpos[2]}  -- identity
	if f == 2 then  -- double flip
		xzres[1] = -xzpos[1]
		xzres[2] = -xzpos[2]
	elseif f ~= 0 and r == 0 then  -- single flip
		xzres[1] = f * xzpos[1]
		xzres[2] = -f * xzpos[2]
	elseif f == 0 and r ~= 0 then  -- rotate
		xzres[1] = r * xzpos[2]
		xzres[2] = -r * xzpos[1]
	elseif f ~= 0 and r ~= 0 then  -- flip + rotate
		xzres[1] = f * r * xzpos[2]
		xzres[2] = f * r * xzpos[1]
	end
	return xzres
end

local run_list = function(dir_list, f, r, dir, user, pointed_thing)
	local pname = user:get_player_name()
	local height = user_config[pname].height
	for _,v in ipairs(dir_list) do
		local newpos = fliprot(v[1], f, r)
		for i = 9, 6, -1 do  -- ceiling
			region[v[2][i]](newpos[1], i + height - 7, newpos[2], dir, user, pointed_thing)
		end
		for y = (height - 2), 2, -1 do  -- variable mid region repeats element 5
			region[v[2][5]](newpos[1], y, newpos[2], dir, user, pointed_thing)
		end
		for i = 4, 1, -1 do  -- floor
			region[v[2][i]](newpos[1], i-3, newpos[2], dir, user, pointed_thing)
		end
	end
end

-- Test that region allows digging.
local region_test = function(x, y, z, dir, user, pointed_thing)
	local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
	local node = minetest.get_node(pos)
	return ok_to_tunnel(user, pos, node.name)
end

-- Check all dig locations before doing any digging.
local run_test = function(dir_list, f, r, dir, user, pointed_thing)
	local pname = user:get_player_name()
	local height = user_config[pname].height
	local ok = true
	for _,v in ipairs(dir_list) do
		local newpos = fliprot(v[1], f, r)
		for i = 9, 6, -1 do  -- ceiling
			ok = region_test(newpos[1], i + height - 7, newpos[2], dir, user, pointed_thing)
			if ok == false then return false end  -- not ok to dig
		end
		for y = (height - 2), 2, -1 do  -- variable mid region repeats element 5
			ok = region_test(newpos[1], y, newpos[2], dir, user, pointed_thing)
			if ok == false then return false end  -- not ok to dig
		end
		for i = 4, 1, -1 do  -- floor
			ok = region_test(newpos[1], i-3, newpos[2], dir, user, pointed_thing)
			if ok == false then return false end  -- not ok to dig
		end
	end
	return true  -- everything ok to dig
end

-- Dig tunnel based on direction given.
	-- [9] = h + 2  (up ceiling)
	-- [8] = h + 1 (default ceiling)
	--
	-- [7] = h  (default arch)
	-- [6] = h - 1  (down arch)
	-- [5] = 2 to h - 2 (middle repeated, hmin = 3, zero instances,)
	-- [4] = 1   (up floor)
	--
	-- [3] = 0   (default floor)
	-- [2] = -1  (default base, down floor,)
	-- [1] = -2  (down base)
local dig_tunnel = function(cdir, user, pointed_thing)
	local dig_patterns = {
		-- Orthogonal (north reference).
		[1] = { {{-3, 3},{0,0, 4, 4,4,4,4, 40,0}}, {{-2, 3},{0,0,4, 4,4,4, 4,  4,0}}, {{-1, 3},{0, 0,4, 4,4,4,4, 4,0}}, {{ 0, 3},{0, 0,4, 4,4,4, 4, 4,0}}, {{ 1, 3},{0, 0,4, 4,4,4,4, 4,0}}, {{ 2, 3},{0,0,4, 4,4,4, 4,  4,0}}, {{ 3, 3},{0,0, 4, 4,4,4,4, 40,0}},
				{{-3, 2},{0,0,37, 3,3,3,3, 30,0}}, {{-2, 2},{0,0,7, 1,1,1,21, 32,0}}, {{-1, 2},{0,86,6, 1,1,1,1, 2,0}}, {{ 0, 2},{0,86,5, 1,1,1, 1, 2,0}}, {{ 1, 2},{0,86,6, 1,1,1,1, 2,0}}, {{ 2, 2},{0,0,7, 1,1,1,21, 32,0}}, {{ 3, 2},{0,0,37, 3,3,3,3, 30,0}},
				{{-3, 1},{0,0,37, 3,3,3,3, 30,0}}, {{-2, 1},{0,0,7, 1,1,1,21, 32,0}}, {{-1, 1},{0,86,6, 1,1,1,1, 2,0}}, {{ 0, 1},{0,86,6, 1,1,1,77, 2,0}}, {{ 1, 1},{0,86,6, 1,1,1,1, 2,0}}, {{ 2, 1},{0,0,7, 1,1,1,21, 32,0}}, {{ 3, 1},{0,0,37, 3,3,3,3, 30,0}},
				{{-3, 0},{0,0,37, 3,3,3,3, 30,0}}, {{-2, 0},{0,0,7, 1,1,1,21, 32,0}}, {{-1, 0},{0,86,6, 1,1,1,1, 2,0}}, {{ 0, 0},{0,86,5, 1,1,1, 1, 2,0}}, {{ 1, 0},{0,86,6, 1,1,1,1, 2,0}}, {{ 2, 0},{0,0,7, 1,1,1,21, 32,0}}, {{ 3, 0},{0,0,37, 3,3,3,3, 30,0}},
				{{-3,-1},{0,0, 4, 4,4,4,4, 40,0}}, {{-2,-1},{0,0,4, 4,4,4, 4,  4,0}}, {{-1,-1},{0, 0,4, 4,4,4,4, 4,0}}, {{ 0,-1},{0, 0,4, 4,4,4, 4, 4,0}}, {{ 1,-1},{0, 0,4, 4,4,4,4, 4,0}}, {{ 2,-1},{0,0,4, 4,4,4, 4,  4,0}}, {{ 3,-1},{0,0, 4, 4,4,4,4, 40,0}},
			},

		-- Knight move (north-northwest reference).
		[2] = { {{-4, 3},{0,0, 4, 4,4,4,4, 40,0}}, {{-3, 3},{0,0, 4, 4,4,4, 4,  4,0}}, {{-2, 3},{0, 0,4, 4,4,4, 4,  4,0}}, {{-1, 3},{0, 0,4, 4,4,4, 4, 4,0}}, {{ 0, 3},{0, 0,4, 4,4,4,4, 4,0}}, {{ 1, 3},{0, 0,4, 4,4,4, 4,  4,0}}, {{ 2, 3},{0,0,37,  3,3,3, 3, 30,0}},
				{{-4, 2},{0,0,37, 3,3,3,3, 30,0}}, {{-3, 2},{0,0, 7, 1,1,1,21, 32,0}}, {{-2, 2},{0,86,6, 1,1,1, 1,  2,0}}, {{-1, 2},{0,86,5, 1,1,1,77, 2,0}}, {{ 0, 2},{0,86,6, 1,1,1,1, 2,0}}, {{ 1, 2},{0, 0,7, 1,1,1,21, 32,0}}, {{ 2, 2},{0,0,37,  3,3,3, 3,  3,0}}, {{ 3, 2},{0,0,37, 3,3,3,3, 30,0}},
				{{-4, 1},{0,0,37, 3,3,3,3, 30,0}}, {{-3, 1},{0,0, 7, 1,1,1,21, 32,0}}, {{-2, 1},{0,86,6, 1,1,1, 1,  2,0}}, {{-1, 1},{0,86,6, 1,1,1, 1, 2,0}}, {{ 0, 1},{0,86,6, 1,1,1,1, 2,0}}, {{ 1, 1},{0,86,6, 1,1,1, 1,  2,0}}, {{ 2, 1},{0,0, 7,  1,1,1,21, 32,0}}, {{ 3, 1},{0,0,37, 3,3,3,3, 30,0}},
				{{-4, 0},{0,0,37, 3,3,3,3, 30,0}}, {{-3, 0},{0,0,37, 3,3,3, 3,  3,0}}, {{-2, 0},{0, 0,7, 1,1,1,21, 32,0}}, {{-1, 0},{0,86,6, 1,1,1, 1, 2,0}}, {{ 0, 0},{0,86,5, 1,1,1,1, 2,0}}, {{ 1, 0},{0,86,6, 1,1,1, 1,  2,0}}, {{ 2, 0},{0,0, 7, 19,1,1,21, 32,0}}, {{ 3, 0},{0,0,37, 3,3,3,3, 30,0}},
												   {{-3,-1},{0,0,37, 3,3,3, 3, 30,0}}, {{-2,-1},{0, 0,4, 4,4,4, 4,  4,0}}, {{-1,-1},{0, 0,4, 4,4,4, 4, 4,0}}, {{ 0,-1},{0, 0,4, 4,4,4,4, 4,0}}, {{ 1,-1},{0, 0,4, 4,4,4, 4,  4,0}}, {{ 2,-1},{0,0, 4,  4,4,4, 4,  4,0}}, {{ 3,-1},{0,0, 4, 4,4,4,4, 40,0}},
			},

		-- Diagonal (northwest reference).
		[3] = {                                                                                                             {{-1, 4},{0, 0, 4,  4,4,4, 4, 40,0}}, {{ 0, 4},{0, 0,37,  3,3,3, 3, 30,0}}, {{ 1, 4},{0, 0,37,  3,3,3, 3, 30,0}},
																					   {{-2, 3},{0, 0, 4, 4,4,4, 4,  4,0}}, {{-1, 3},{0, 0, 4,  4,4,4, 4,  4,0}}, {{ 0, 3},{0, 0, 7,  1,1,1,21, 32,0}}, {{ 1, 3},{0, 0,37,  3,3,3, 3,  2,0}}, {{ 2, 3},{0,0,37,  3,3,3,3,  30,0}},
												   {{-3, 2},{0,0, 4, 4,4,4, 4,  4,0}}, {{-2, 2},{0, 0, 4, 4,4,4, 4,  4,0}}, {{-1, 2},{0, 0, 4,  4,4,4, 4,  4,0}}, {{ 0, 2},{0,86, 6,  1,1,1, 1,  2,0}}, {{ 1, 2},{0, 0, 7,  1,1,1,21, 32,0}}, {{ 2, 2},{0,0,37,  3,3,3,3,   2,0}}, {{ 3, 2},{0,0,37, 3,3,3,3, 30,0}},
				{{-4, 1},{0,0, 4, 4,4,4,4, 40,0}}, {{-3, 1},{0,0, 4, 4,4,4, 4,  4,0}}, {{-2, 1},{0, 0, 4, 4,4,4, 4,  4,0}}, {{-1, 1},{0,86, 5,  1,1,1, 1,  2,0}}, {{ 0, 1},{0,86, 6,  1,1,1, 1,  2,0}}, {{ 1, 1},{0,86, 6, 10,1,1, 1,  2,0}}, {{ 2, 1},{0,0, 7, 19,1,1,21, 32,0}}, {{ 3, 1},{0,0,37, 3,3,3,3, 30,0}},
				{{-4, 0},{0,0,37, 3,3,3,3, 30,0}}, {{-3, 0},{0,0, 7, 1,1,1,21, 32,0}}, {{-2, 0},{0,86, 6, 1,1,1, 1,  2,0}}, {{-1, 0},{0,86, 6,  1,1,1, 1,  2,0}}, {{ 0, 0},{0,86, 5, 10,1,1,77,  2,0}}, {{ 1, 0},{0, 0, 4,  4,4,4, 4,  4,0}}, {{ 2, 0},{0,0, 4,  4,4,4,4,   4,0}}, {{ 3, 0},{0,0, 4, 4,4,4,4, 40,0}},
				{{-4,-1},{0,0,37, 3,3,3,3, 30,0}}, {{-3,-1},{0,0,37, 3,3,3, 3,  2,0}}, {{-2,-1},{0, 0, 7, 1,1,1,21, 32,0}}, {{-1,-1},{0,86, 6, 10,1,1, 1,  2,0}}, {{ 0,-1},{0, 0, 4,  4,4,4, 4,  4,0}}, {{ 1,-1},{0, 0, 4,  4,4,4, 4,  4,0}},
												   {{-3,-2},{0,0,37, 3,3,3, 3, 30,0}}, {{-2,-2},{0, 0,37, 3,3,3, 3,  2,0}}, {{-1,-2},{0, 0, 7, 19,1,1,21, 32,0}}, {{ 0,-2},{0, 0, 4,  4,4,4, 4,  4,0}},
																					   {{-2,-3},{0, 0,37, 3,3,3, 3, 30,0}}, {{-1,-3},{0, 0,37,  3,3,3, 3, 30,0}}, {{ 0,-3},{0, 0, 4,  4,4,4, 4, 40,0}},
			},

		-- Orthogonal slope down (north reference).
		-- Review water tunnel (-3,0), (-2,0), (2,0), (3,0) all 1 below ref level (0 and 87) -- not solid seal, but water's not going to go up.
		[10] = {{{-3, 3},{0, 4, 4, 4,4,4,40,  0,0}}, {{-2, 3},{0, 4, 4, 4,4, 4, 4,  0,0}}, {{-1, 3},{ 0,4, 4, 4,4,4,4, 0,0}}, {{ 0, 3},{ 0,4, 4, 4,4,4, 4, 0,0}}, {{ 1, 3},{ 0,4, 4, 4,4,4,4, 0,0}}, {{ 2, 3},{0, 4, 4, 4,4, 4, 4,  0,0}}, {{ 3, 3},{0, 4, 4, 4,4,4,40,  0,0}},
				{{-3, 2},{0,37, 3, 3,3,3, 3, 30,0}}, {{-2, 2},{0, 7, 1, 1,1,21,32, 32,0}}, {{-1, 2},{86,6, 1, 1,1,1,2, 2,0}}, {{ 0, 2},{86,5, 1, 1,1,1, 2, 2,0}}, {{ 1, 2},{86,6, 1, 1,1,1,2, 2,0}}, {{ 2, 2},{0, 7, 1, 1,1,21,32, 32,0}}, {{ 3, 2},{0,37, 3, 3,3,3, 3, 30,0}},
				{{-3, 1},{0,37, 3, 3,3,3, 3, 30,0}}, {{-2, 1},{0, 7,13, 1,1, 1,21, 32,0}}, {{-1, 1},{86,6,12, 1,1,1,1, 2,0}}, {{ 0, 1},{86,6,12, 1,1,1,77, 2,0}}, {{ 1, 1},{86,6,12, 1,1,1,1, 2,0}}, {{ 2, 1},{0, 7,13, 1,1, 1,21, 32,0}}, {{ 3, 1},{0,37, 3, 3,3,3, 3, 30,0}},
				{{-3, 0},{0, 0,37, 3,3,3, 3, 30,0}}, {{-2, 0},{0,87, 7, 1,1, 1,21, 32,0}}, {{-1, 0},{86,8, 6, 1,1,1,1, 2,0}}, {{ 0, 0},{86,8, 5, 1,1,1, 1, 2,0}}, {{ 1, 0},{86,8, 6, 1,1,1,1, 2,0}}, {{ 2, 0},{0,87, 7, 1,1, 1,21, 32,0}}, {{ 3, 0},{0, 0,37, 3,3,3, 3, 30,0}},
				{{-3,-1},{0, 0, 4, 4,4,4, 4, 40,0}}, {{-2,-1},{0, 0, 4, 4,4, 4, 4,  4,0}}, {{-1,-1},{ 0,0, 4, 4,4,4,4, 4,0}}, {{ 0,-1},{ 0,0, 4, 4,4,4, 4, 4,0}}, {{ 1,-1},{ 0,0, 4, 4,4,4,4, 4,0}}, {{ 2,-1},{0, 0, 4, 4,4, 4, 4,  4,0}}, {{ 3,-1},{0, 0, 4, 4,4,4, 4, 40,0}},
			},

		-- Orthogonal slope up (north reference).
		-- Review water tunnel (-3,2), (-2,2), (2,2), 3,2) all at ref level (0 and 87) -- not solid seal, but water's not going to go up.
		[11] = {{{-3, 3},{0,0, 0,  4,4,4,4,  4,40}}, {{-2, 3},{0,0, 0,  4,4,4, 4,  4, 4}}, {{-1, 3},{0, 0,0,  4,4,4,4, 4,4}}, {{ 0, 3},{0, 0,0,  4,4,4,4,  4,4}}, {{ 1, 3},{0, 0,0,  4,4,4,4, 4,4}}, {{ 2, 3},{0,0, 0,  4,4,4, 4,  4, 4}}, {{ 3, 3},{0,0, 0,  4,4,4,4,  4,40}},
				{{-3, 2},{0,0, 0, 37,3,3,3,  3,30}}, {{-2, 2},{0,0,87,  7,1,1, 1, 21,32}}, {{-1, 2},{0,86,8,  6,1,1,1, 1,2}}, {{ 0, 2},{0,86,8,  5,1,1,1,  1,2}}, {{ 1, 2},{0,86,8,  6,1,1,1, 1,2}}, {{ 2, 2},{0,0,87,  7,1,1, 1, 21,32}}, {{ 3, 2},{0,0, 0, 37,3,3,3,  3,30}},
				{{-3, 1},{0,0,37,  3,3,3,3,  3,30}}, {{-2, 1},{0,0, 7, 13,1,1, 1, 21,32}}, {{-1, 1},{0,86,6, 12,1,1,1, 1,2}}, {{ 0, 1},{0,86,6, 12,1,1,1, 77,2}}, {{ 1, 1},{0,86,6, 12,1,1,1, 1,2}}, {{ 2, 1},{0,0, 7, 13,1,1, 1, 21,32}}, {{ 3, 1},{0,0,37,  3,3,3,3,  3,30}},
				{{-3, 0},{0,0,37,  3,3,3,3,  3,30}}, {{-2, 0},{0,0, 7,  1,1,1,21, 32, 4}}, {{-1, 0},{0,86,6,  1,1,1,1, 2,4}}, {{ 0, 0},{0,86,5,  1,1,1,1,  2,4}}, {{ 1, 0},{0,86,6,  1,1,1,1, 2,4}}, {{ 2, 0},{0,0, 7,  1,1,1,21, 32, 4}}, {{ 3, 0},{0,0,37,  3,3,3,3,  3,30}},
				{{-3,-1},{0,0, 4,  4,4,4,4, 40, 0}}, {{-2,-1},{0,0, 4,  4,4,4, 4,  4, 0}}, {{-1,-1},{0, 0,4,  4,4,4,4, 4,0}}, {{ 0,-1},{0, 0,4,  4,4,4,4,  4,0}}, {{ 1,-1},{0, 0,4,  4,4,4,4, 4,0}}, {{ 2,-1},{0,0, 4,  4,4,4, 4,  4, 0}}, {{ 3,-1},{0,0, 4,  4,4,4,4, 40, 0}},
			},

		-- Diagonal slope down (northwest reference).
		-- Review water tunnel (-3,0), (0,3) stacked 32 -- with arch, overdoing seal, could raise height of 21 or remove top 32.
		-- Review water tunnel (-1,-2), (2,1) -- not solid seal, but water's not going to go up.
		[30] = {                                                                                                             {{-1, 4},{ 0, 4, 4,  4,4,4, 4,  0,0}}, {{ 0, 4},{ 0,37, 3,  3,3, 3, 3,  0,0}}, {{ 1, 4},{ 0,37, 3,  3,3,3, 3,  0,0}},
																															 {{-1, 3},{ 0, 4, 4,  4,4,4, 4,  4,0}}, {{ 0, 3},{ 0, 7, 1,  1,1,21,32, 32,0}}, {{ 1, 3},{ 0,37, 3,  3,3,3, 3,  2,0}}, {{ 2, 3},{0,37,3,  3,3,3, 3, 30,0}},
																					   {{-2, 2},{ 0, 4, 4, 4,4,4, 4,  4,0}}, {{-1, 2},{ 0, 4, 4,  4,4,4, 4,  4,0}}, {{ 0, 2},{86, 6,11,  1,1, 1, 1,  2,0}}, {{ 1, 2},{ 0, 7,13,  1,1,1,21, 32,0}}, {{ 2, 2},{0,37,3,  3,3,3, 3,  2,0}}, {{ 3, 2},{0,0,37, 3,3,3,3, 30,0}},
				{{-4, 1},{0, 4,4, 4,4,4,4, 0,0}}, {{-3, 1},{0, 4,4, 4,4, 4, 4,  4,0}}, {{-2, 1},{ 0, 4, 4, 4,4,4, 4,  4,0}}, {{-1, 1},{86, 5,11,  1,1,1, 1,  2,0}}, {{ 0, 1},{86, 6,12,  1,1, 1, 1,  2,0}}, {{ 1, 1},{86, 8, 6, 10,1,1, 1,  2,0}}, {{ 2, 1},{0,87,7, 19,1,1,21, 32,0}}, {{ 3, 1},{0,0,37, 3,3,3,3, 30,0}},
				{{-4, 0},{0,37,3, 3,3,3,3, 0,0}}, {{-3, 0},{0, 7,1, 1,1,21,32, 32,0}}, {{-2, 0},{86, 6,11, 1,1,1, 1,  2,0}}, {{-1, 0},{86, 6,12,  1,1,1, 1,  2,0}}, {{ 0, 0},{86, 8, 5, 10,1, 1,77,  2,0}}, {{ 1, 0},{ 0, 0, 4,  4,4,4, 4,  4,0}}, {{ 2, 0},{0, 0,4,  4,4,4, 4,  4,0}}, {{ 3, 0},{0,0, 4, 4,4,4,4, 40,0}},
				{{-4,-1},{0,37,3, 3,3,3,3, 0,0}}, {{-3,-1},{0,37,3, 3,3, 3, 3,  2,0}}, {{-2,-1},{ 0, 7,13, 1,1,1,21, 32,0}}, {{-1,-1},{86, 8, 6, 10,1,1, 1,  2,0}}, {{ 0,-1},{ 0, 0, 4,  4,4, 4, 4,  4,0}}, {{ 1,-1},{ 0, 0, 4,  4,4,4, 4,  4,0}},
												  {{-3,-2},{0,37,3, 3,3, 3, 3, 30,0}}, {{-2,-2},{ 0,37, 3, 3,3,3, 3,  2,0}}, {{-1,-2},{ 0,87, 7, 19,1,1,21, 32,0}}, {{ 0,-2},{ 0, 0, 4,  4,4, 4, 4,  4,0}},
																					   {{-2,-3},{ 0, 0,37, 3,3,3, 3, 30,0}}, {{-1,-3},{ 0, 0,37,  3,3,3, 3, 30,0}}, {{ 0,-3},{ 0, 0, 4,  4,4, 4, 4, 40,0}},
			},

		-- Diagonal slope up (northwest reference).
		-- Review water tunnel (-2,-3), (-1,-3), (0,-3), (3,0), (3,1), (3,2) -- without arch, same as slope down, overdoing seal.
		-- Review water tunnel (-3,0), (0,3) -- not solid seal, but water's not going to go up.
		[31] = {                                                                                                             {{-1, 4},{0, 0, 0,  4,4,4, 4,  4,40}}, {{ 0, 4},{0, 0, 0, 37,3,3,3,  3,30}}, {{ 1, 4},{0, 0,37,  3,3,3,3,  3,30}},
																															 {{-1, 3},{0, 0, 0,  4,4,4, 4,  4, 4}}, {{ 0, 3},{0, 0,87,  7,1,1,1, 21,32}}, {{ 1, 3},{0, 0,37,  3,3,3,3,  3, 3}}, {{ 2, 3},{0,0,37, 3,3,3,3,   3,30}},
																					   {{-2, 2},{0, 0, 0,  4,4,4,4,  4, 4}}, {{-1, 2},{0, 0, 0,  4,4,4, 4,  4, 4}}, {{ 0, 2},{0,86, 8,  6,1,1,1,  1, 2}}, {{ 1, 2},{0, 0, 7, 13,1,1,1, 21,32}}, {{ 2, 2},{0,0,37, 3,3,3,3,   3, 3}}, {{ 3, 2},{0,0,37, 3,3,3,3, 3,0}},
				{{-4, 1},{0,0,0,  4,4,4,4, 4,40}}, {{-3, 1},{0,0, 0, 4,4,4,4,  4, 4}}, {{-2, 1},{0, 0, 0,  4,4,4,4,  4, 4}}, {{-1, 1},{0,86, 8,  5,1,1, 1,  1, 2}}, {{ 0, 1},{0,86, 6, 12,1,1,1,  1, 2}}, {{ 1, 1},{0,86, 6, 11,1,1,1,  1, 2}}, {{ 2, 1},{0,0, 7, 1,1,1,21, 32, 4}}, {{ 3, 1},{0,0,37, 3,3,3,3, 3,0}},
				{{-4, 0},{0,0,0, 37,3,3,3, 3,30}}, {{-3, 0},{0,0,87, 7,1,1,1, 21,32}}, {{-2, 0},{0,86, 8,  6,1,1,1,  1, 2}}, {{-1, 0},{0,86, 6, 12,1,1, 1,  1, 2}}, {{ 0, 0},{0,86, 5, 11,1,1,1, 77, 2}}, {{ 1, 0},{0, 0, 4,  4,4,4,4,  4, 4}}, {{ 2, 0},{0,0, 4, 4,4,4,4,   4, 4}}, {{ 3, 0},{0,0, 4, 4,4,4,4, 4,0}},
				{{-4,-1},{0,0,3, 37,3,3,3, 3,30}}, {{-3,-1},{0,0,37, 3,3,3,3,  3, 3}}, {{-2,-1},{0, 0, 7, 13,1,1,1, 21,32}}, {{-1,-1},{0,86, 6, 11,1,1, 1,  1, 2}}, {{ 0,-1},{0, 0, 4,  4,4,4,4,  4, 4}}, {{ 1,-1},{0, 0, 4,  4,4,4,4,  4, 4}},
												   {{-3,-2},{0,0,37, 3,3,3,3,  3,30}}, {{-2,-2},{0, 0,37,  3,3,3,3,  3, 3}}, {{-1,-2},{0, 0, 7,  1,1,1,21, 32, 4}}, {{ 0,-2},{0, 0, 4,  4,4,4,4,  4, 4}},
																					   {{-2,-3},{0, 0,37,  3,3,3,3,  3, 0}}, {{-1,-3},{0, 0,37,  3,3,3, 3,  3, 0}}, {{ 0,-3},{0, 0, 4,  4,4,4,4,  4, 0}},
			},
	}

	local dig_lookup = {  -- Defines dig pattern, flip, and rotation for each direction.
		[0] = {1, 0, 0}, [1] = {2, 0, 0}, [2] = {3, 0, 0}, [3] = {2, 1, -1},
		[4] = {1, 0, -1}, [5] = {2, 0, -1}, [6] = {3, 1, 0}, [7] = {2, 1, 0},
		[8] = {1, 1, 0}, [9] = {2, 2, 0}, [10] = {3, 2, 0}, [11] = {2, 1, 1},
		[12] = {1, 0, 1}, [13] = {2, 0, 1}, [14] = {3, 0, 1}, [15] = {2, -1, 0},
		[16] = {11, 0, 0}, [17] = {31, 0, 0}, [18] = {11, 0, -1}, [19] = {31, 1, 0},
		[20] = {11, 1, 0}, [21] = {31, 2, 0}, [22] = {11, 0, 1}, [23] = {31, -1, 0},
		[24] = {10, 0, 0}, [25] = {30, 0, 0}, [26] = {10, 0, -1}, [27] = {30, 1, 0},
		[28] = {10, 1, 0}, [29] = {30, 2, 0}, [30] = {10, 0, 1}, [31] = {30, -1, 0}
	}

	-- Pass horizontal and vertical directions to region functions.
	-- Horizontal needed for angledstairs nodes, vertical helped combine functions.
	local dir = {}
	if cdir >= 24 then
		dir.horiz = (cdir - 24) * 2
		dir.vert = -1
	elseif cdir >= 16 then
		dir.horiz = (cdir - 16) * 2
		dir.vert = 1
	else
		dir.horiz = cdir
		dir.vert = 0
	end

	local dig_list = dig_patterns[dig_lookup[cdir][1]]
	local flip = dig_lookup[cdir][2]
	local rotation = dig_lookup[cdir][3]
	-- Check that all nodes are ok to dig before digging any of them.
	-- If you want these translated, contribute the translations.
	if run_test(dig_list, flip, rotation, dir, user, pointed_thing) then
		run_list(dig_list, flip, rotation, dir, user, pointed_thing)
		minetest.log("action", user:get_player_name().." uses tunnelmaker at "..minetest.pos_to_string(pointed_thing.under))
	else
		minetest.chat_send_player(user:get_player_name(), "Tunnelmaker can't dig—area protected.")
		minetest.log("action", user:get_player_name().." tried to use tunnelmaker at protected position "..minetest.pos_to_string(pointed_thing.under))
	end
end

-- Display User Options menu.
local display_menu = function(player)
	local pname = player:get_player_name()
	local remove_refs_on = false
	if user_config[pname].remove_refs > 0 then
		remove_refs_on = true
	end
	local clear_trees_on = false
	if user_config[pname].clear_trees > 0 then
		clear_trees_on = true
	end
	local formspec = "size[6.0,6.5]"..
		"label[0.25,0.25;"..S("Tunnelmaker - User Options").."]"..
		"dropdown[0.25,1.00;4;digging_mode;"..S("General purpose mode")..","..S("Advanced trains mode")..","..S("Bike path mode")..";"..tostring(user_config[pname].digging_mode).."]"..
		"checkbox[0.25,1.75;add_lined_tunnels;"..S("Wide paths / lined tunnels")..";"..tostring(user_config[pname].add_lined_tunnels).."]"..
		"checkbox[0.25,2.20;continuous_updown;"..S("Continuous up/down digging")..";"..tostring(user_config[pname].continuous_updown).."]"..
		"checkbox[0.25,2.75;clear_trees;"..S("Clear tree cover").."*;"..tostring(clear_trees_on).."]"..
		"checkbox[0.25,3.20;remove_refs;"..S("Remove reference nodes").."*;"..tostring(remove_refs_on).."]"..
		"button_exit[2,5.00;2,0.4;exit;"..S("Exit").."]"..
		"label[0.25,5.75;"..minetest.colorize("#888","* "..S("Automatically disabled after 2 min.")).."]"
	local formspec_dm = ""
	local dmat = ""
	local use_desert_material = user_config[pname].use_desert_material
	if add_desert_material and minetest.get_biome_data then
		if not user_config[pname].lock_desert_mode then
			use_desert_material = string.match(minetest.get_biome_name(minetest.get_biome_data(player:get_pos()).biome), "desert")
			user_config[pname].use_desert_material = use_desert_material
		end
		if use_desert_material then
			dmat = S("Desert")
		else
			dmat = S("Non-desert")
		end
		formspec_dm = "checkbox[0.25,3.75;lock_desert_mode;"..S("Lock desert mode to:").." "..dmat..";"..tostring(user_config[pname].lock_desert_mode).."]"
	end
	minetest.show_formspec(pname, "tunnelmaker:form", formspec..formspec_dm)
end

local i
for i,img in ipairs(images) do
	local inv = 1
	if i == 2 then
		inv = 0
	end

	minetest.register_tool("tunnelmaker:tool"..(i-1),
	{
		description = "Tunnel Maker",
		groups = {not_in_creative_inventory=inv},
		inventory_image = img,
		wield_image = img,
		stack_max = 1,
		range = 7.0,

		-- Dig single node with left mouse click.
		on_use = function(itemstack, player, pointed_thing)
			if minetest.check_player_privs(player, "tunneling") then  -- Must have tunneling privs.
				local pname = player:get_player_name()
				local pos = pointed_thing.under
				local key_stats = player:get_player_control()
				if key_stats.sneak then  -- Bring up User Options formspec.
					display_menu(player)
				else  -- Dig single node, if pointing to one
					if pos ~= nil then
						minetest.node_dig(pos, minetest.get_node(pos), player)
						minetest.sound_play("default_dig_dig_immediate", {pos=pos, max_hear_distance = 8, gain = 0.5})
					end
				end
			end
		end,

		-- Dig tunnel with right mouse click (double tap on android)
		on_place = function(itemstack, placer, pointed_thing)
			if minetest.check_player_privs(placer, "tunneling") then  -- Must have tunneling privs.
				local pname = placer:get_player_name()
				local key_stats = placer:get_player_control()
				if key_stats.sneak then  -- Toggle up/down digging direction.
					tunnelmaker[pname].updown = (tunnelmaker[pname].updown + 1) % 3
					tunnelmaker[pname].lastpos = { x = placer:get_pos().x, y = placer:get_pos().y, z = placer:get_pos().z }
				elseif key_stats.aux1 then  -- Bring up User Options menu. Alternative for Android.
					display_menu(placer)
				-- Otherwise dig tunnel based on direction pointed and current updown direction
				elseif pointed_thing.type=="node" then
					-- if advtrains_track, I lower positions of pointed_thing to right below track, but keep name the same. Same with snow cover.
					local name = minetest.get_node(pointed_thing.under).name
					-- if minetest.registered_nodes[name].groups.advtrains_track == 1 then
					if string.match(name, "dtrack") or name == "default:snow" or name == angled_slab_not_desert or name == angled_slab_desert then
						pointed_thing.under = vector.add(pointed_thing.under, {x=0, y=-1, z=0})
						--pointed_thing.above = vector.add(pointed_thing.above, {x=0, y=-1, z=0})  -- don't currently use this
					end
					minetest.sound_play("default_dig_dig_immediate", {pos=pointed_thing.under, max_hear_distance = 8, gain = 1.0})
					dig_tunnel(i-1, placer, pointed_thing)
					if not user_config[pname].continuous_updown then
						tunnelmaker[pname].updown = 0   -- reset to horizontal after one use
					end
				end
			end
		end,

		-- Also bring up User Options menu, when not pointing to anything. Alternative for Android.
		on_secondary_use = function(itemstack, placer, pointed_thing)
			if minetest.check_player_privs(placer, "tunneling") then  -- Must have tunneling privs.
				if placer:get_player_control().aux1 then
					display_menu(placer)
				end
			end
		end,
	}
	)
end

-- Register configuration callback
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "tunnelmaker:form" then
		return false
	end
	local pname = player:get_player_name()
	if fields.continuous_updown == "true" then
		user_config[pname].continuous_updown = true
	elseif fields.continuous_updown == "false" then
		user_config[pname].continuous_updown = false
	elseif fields.add_lined_tunnels == "true" then
		user_config[pname].add_lined_tunnels = true
		user_config[pname].add_floors = true
		user_config[pname].add_wide_floors = true
	elseif fields.add_lined_tunnels == "false" then
		user_config[pname].add_lined_tunnels = false
		user_config[pname].add_floors = user_config[pname].digging_mode ~= 1  -- gp no floors when not lined
		user_config[pname].add_wide_floors = false
	elseif fields.clear_trees == "true" then
		user_config[pname].clear_trees = remove_refs_enable_time
	elseif fields.clear_trees == "false" then
		user_config[pname].clear_trees = 0
	elseif fields.remove_refs == "true" then
		user_config[pname].remove_refs = remove_refs_enable_time
	elseif fields.remove_refs == "false" then
		user_config[pname].remove_refs = 0
	elseif fields.lock_desert_mode == "false" then
		user_config[pname].lock_desert_mode = false
	elseif fields.lock_desert_mode == "true" then
		user_config[pname].lock_desert_mode = true
	elseif fields.digging_mode == S("General purpose mode") then
		user_config[pname].digging_mode = 1
		user_config[pname].height = tunnel_height_general
		user_config[pname].add_arches = false
		user_config[pname].add_embankment = false
		user_config[pname].add_refs = false
		user_config[pname].add_floors = user_config[pname].add_lined_tunnels
		user_config[pname].add_wide_floors = user_config[pname].add_lined_tunnels
		user_config[pname].add_bike_ramps = false
		user_config[pname].coating_not_desert = tunnel_material
		user_config[pname].coating_desert = tunnel_material_desert
	elseif fields.digging_mode == S("Advanced trains mode") then
		user_config[pname].digging_mode = 2
		user_config[pname].height = tunnel_height_train
		user_config[pname].add_arches = add_arches_config
		user_config[pname].add_embankment = true
		user_config[pname].add_refs = true
		user_config[pname].add_floors = true
		user_config[pname].add_wide_floors = user_config[pname].add_lined_tunnels
		user_config[pname].add_bike_ramps = false
		user_config[pname].coating_not_desert = tunnel_material
		user_config[pname].coating_desert = tunnel_material_desert
	elseif fields.digging_mode == S("Bike path mode") then
		user_config[pname].digging_mode = 3
		user_config[pname].height = tunnel_height_bike
		user_config[pname].add_arches = false
		user_config[pname].add_embankment = false
		user_config[pname].add_refs = true
		user_config[pname].add_floors = true
		user_config[pname].add_wide_floors = user_config[pname].add_lined_tunnels
		user_config[pname].add_bike_ramps = true
		user_config[pname].coating_not_desert = bike_path_material
		user_config[pname].coating_desert = bike_path_material_desert
	end
	return true
end)

-- Decrement remove_refs countdown timers.
minetest.register_globalstep(function(dtime)
	local players  = minetest.get_connected_players()
	for _,player in ipairs(players) do
		local pname = player:get_player_name()
		local rr = user_config[pname].remove_refs
		if rr > 0 then
			rr = rr - dtime
			if rr <= 0 then
				user_config[pname].remove_refs = 0
			else
				user_config[pname].remove_refs = rr
			end
		end
		local ct = user_config[pname].clear_trees
		if ct > 0 then
			ct = ct - dtime
			if ct <= 0 then
				user_config[pname].clear_trees = 0
			else
				user_config[pname].clear_trees = ct
			end
		end
	end
end)

-- Remove reference marks
local remove_refs = function(player)
	local ppos = player:get_pos()
	local refpos = minetest.find_node_near(ppos, 1, reference_marks)
	if refpos then
		if not minetest.is_protected(refpos, player:get_player_name()) then
			local meta = minetest.get_meta(refpos)
			local rep_mat = meta:get("replace_with")
			if rep_mat and string.len(rep_mat) > 0 then
				-- only advtrain embankment should get 42 param2
				if rep_mat == embankment then
					minetest.set_node(refpos, {name = rep_mat, param2 = 42})
				else
					minetest.set_node(refpos, {name = rep_mat, param2 = 0})
				end
			end
		end
	end
end

-- Replaces reference marks with appropriate material.
minetest.register_globalstep(function(dtime)
	for _, player in ipairs(minetest.get_connected_players()) do
		if user_config[player:get_player_name()].remove_refs > 0 then
			remove_refs(player)
		end
	end
end)

-- Allow other mods to use the dig_tunnel function.
tunnelmaker.dig_tunnel = dig_tunnel
