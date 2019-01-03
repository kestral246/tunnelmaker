-- tunnelmaker
-- Another tunnel digging mod for minetest.
-- Digs tunnels and builds simple bridges for advtrains track, supporting
-- all 16 track directions, along with slopes up and down.
-- 
-- by David G (kestral246@gmail.com)
-- and mikola

-- Version 2.0-pre-1 - 2019-01-02
-- Updating configs (wip), simplified digging patterns, added shift+left-click user config formspec.

-- based on compassgps 2.7 and compass 0.5

-- Licence TBD
-- To the extent possible under law, the author(s) have dedicated all copyright and related
-- and neighboring rights to this software to the public domain worldwide. This software is
-- distributed without any warranty.

-- You should have received a copy of the CC0 Public Domain Dedication along with this
-- software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>. 

-- This config section is a work in progress.
-- I prefixed all the minetest.conf names with tunnel_, but don't know if that's really necessary.

-- User settable config variables (in game formspec):
-----------------------------------------------------
-- Default for Remove References is always false.

-- Default for Non-train tunnels.
-- Disables the train-specific options.
local nontrain_tunnel_default = minetest.settings:get_bool("tunnel_nontrain_tunnel_default", false)

-- Default for Continuous updown digging.
-- Allow digging up/down multiple times without resetting mode.
local continuous_updown_default = minetest.settings:get_bool("tunnel_continuous_updown_default", false)


-- Server settable config variables (minetest.conf):
----------------------------------------------------
-- Ceiling lighting
-- Default to torches, but allow using mese post lights.
local use_mese_lights = minetest.settings:get_bool("tunnel_use_mese_lights", false)
local lighting = "default:torch"
if use_mese_lights then
	lighting = "default:mese_post_light"
end

-- Train specific options affected by nontrain_tunnel user setting
-- I need two variables for each of these, so they can be restored when using formspec.

-- Increase tunnel height
local ith_train = (tonumber(minetest.settings:get("tunnel_height") or 5))-5
local ith

-- Add "arches" along the sides.
local add_arches_train = minetest.settings:get_bool("tunnel_add_arches", true)
local add_arches

-- Add gravel mound and additional base
local add_embankment_train = minetest.settings:get_bool("tunnel_add_embankment", true)
local add_embankment

-- Add markup for the railway advtrains
local add_marking_train = minetest.settings:get_bool("tunnel_add_marking", true)
local add_marking

-- Allow to replace the coating of tunnels on a specific coating
local add_tough_tunnels_train = minetest.settings:get_bool("tunnel_add_tough_tunnels", true)
local add_tough_tunnels

-- Allow wide paths in the woods. Greenpeace does not approve
local add_wide_passage_train = minetest.settings:get_bool("tunnel_add_wide_passage", true)
local add_wide_passage

-- Set actual values based on nontrain_tunnel default.
if nontrain_tunnel_default then
	ith = 0
	add_arches = false
	add_embankment = false
	add_marking = false
	add_tough_tunnels = false
	add_wide_passage = false
else
	ith = ith_train
	add_arches = add_arches_train
	add_embankment = add_embankment_train
	add_marking = add_marking_train
	add_tough_tunnels = add_tough_tunnels_train
	add_wide_passage = add_wide_passage_train
end

-- Allow to replace water in air and a transparent coating tunnels
local add_dry_tunnels = minetest.settings:get_bool("tunnel_add_dry_tunnels", true)

-- Allow the use of other materials in desert biomes
local add_desert_material = minetest.settings:get_bool("tunnel_add_desert_material", false)

-- Materials

-- Walls, floor and additional base (outside the desert)
local coating_not_desert = minetest.settings:get("tunnel_coating_not_desert") or "default:stone"

-- Walls, floor and additional base (in the desert)
local coating_desert = minetest.settings:get("tunnel_coating_desert") or "default:desert_stone"

-- Walls in the water
local glass_walls = minetest.settings:get("tunnel_glass_walls") or "default:glass"

-- Embankment for railway tracks
local embankment = minetest.settings:get("tunnel_embankment") or "default:gravel"

-- Railway markings for advtrains (outside the desert)
local marking_not_desert = minetest.settings:get("tunnel_marking_not_desert") or "default:stone_block"

-- Railway markings for advtrains (in the desert)
local marking_desert = minetest.settings:get("tunnel_marking_desert") or "default:desert_stone_block"


-- Hard coded config options
----------------------------

-- Add ceiling lighting (I question whether not having lights is usable.)
local add_lighting = true

-- Distance between illumination (from 0 to 4)
local lighting_search_radius = 1  -- torch
if use_mese_lights then
lighting_search_radius = 2  --mese_post_lights are brighter
end
-- End of configuration

minetest.register_privilege("tunneling", {description = "Allow use of tunnelmaker tool"})

-- Define top level variable to maintain per player state
local tunnelmaker = {}
local user_config = {}

-- Initialize player's state when player joins
minetest.register_on_joinplayer(function(player)
	local pname = player:get_player_name()
	tunnelmaker[pname] = {updown = 0, lastdir = -1, lastpos = {x = 0, y = 0, z = 0}}
	user_config[pname] = {remove_refs = false, nontrain_tunnels = nontrain_tunnel_default, continuous_updown = continuous_updown_default}
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
			local delta = distance2((player:getpos().x - tunnelmaker[pname].lastpos.x),
									(player:getpos().y - tunnelmaker[pname].lastpos.y),
									(player:getpos().z - tunnelmaker[pname].lastpos.z))
			
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

-- Creating a tunnelmaker:embankment from the embankment
local deepcopy
local register

function deepcopy(orig)
		local orig_type = type(orig)
		local copy
		if orig_type == 'table' then
				copy = {}
				for orig_key, orig_value in pairs(orig) do
						copy[deepcopy(orig_key)] = deepcopy(orig_value)
				end
				-- We don't copy metatable!
		else
				copy = orig
		end
		return copy
end

function register(original)
		minetest.log("Copying "..original)
		local orig_node = minetest.registered_nodes[original]
		if orig_node == nil then
				minetest.log("error", "Unknown original node")
				return
		end
		local name_parts = string.split(original, ":")
		local name = name_parts[2]
		local target_name = "tunnelmaker:embankment"
		local copy = deepcopy(orig_node)

		if orig_node.drop ~= nil then
			copy.drop = deepcopy(orig_node.drop)
		else
			copy.drop = original
		end
		minetest.log("Registering "..target_name)
		minetest.register_node(target_name, copy)
end

register(embankment)


-- Tests whether position is in desert-type biomes, such as desert, sandstone_desert, cold_desert, etc
-- Always just returns false if can't determine biome (i.e., using 0.4.x version)
local is_desert = function(pos)
	if add_desert_material and minetest.get_biome_data then
		local cur_biome = minetest.get_biome_name( minetest.get_biome_data(pos).biome )
		return string.match(cur_biome, "desert")
	else
		return false
	end
end

-- Visible location of the regions ? in the cut of the direct tunnel. Region ? is used for ascents and descents between ? and ?
-- | |3|3|3|3|3| |
-- |3|3|2|1|2|3|3|
-- |3|2|0|0|0|2|3|
-- |3|2|0|0|0|2|3|
-- |3|2|0|0|0|2|3|
-- |3|2|0|0|0|2|3|
-- |3|3|5|4|5|3|3|
-- | |8|6|6|6|8| |


local region0 = function(x, y, z, user, pointed_thing)
	local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
	local name = minetest.get_node(pos).name
	if not(name == lighting or string.match(name, "dtrack")) and (add_dry_tunnels or not(add_dry_tunnels or string.match(name, "water"))) then
		minetest.set_node(pos, {name = "air"})
	end
end

local region1 = function(spacing, user, pointed_thing)
	local pos = vector.add(pointed_thing.under, {x=0, y=5+ith, z=0})
	local ceiling = minetest.get_node(vector.add(pos, {x=0, y=1, z=0})).name
	if add_lighting and (ceiling == coating_not_desert or ceiling == coating_desert or ceiling == glass_walls) and
			minetest.get_node(pos).name == "air" and not minetest.is_protected(pos, user) and
			minetest.find_node_near(pos, spacing, {name = lighting}) == nil then
		minetest.set_node(pos, {name = lighting})
	end
	-- roof height can now be 5 or six so try again one higher
	pos = vector.add(pointed_thing.under, {x=0, y=6+ith, z=0})
	ceiling = minetest.get_node(vector.add(pos, {x=0, y=1, z=0})).name
	if add_lighting and (ceiling == coating_not_desert or ceiling == coating_desert or ceiling == glass_walls) and
			minetest.get_node(pos).name == "air" and not minetest.is_protected(pos, user) and
			minetest.find_node_near(pos, spacing, {name = lighting}) == nil then
		minetest.set_node(pos, {name = lighting})
	end
end

local region2 = function(x, y, z, user, pointed_thing)
	local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
	local name = minetest.get_node(pos).name
	local group_flammable = false
	if minetest.registered_nodes[name] then
		group_flammable = minetest.registered_nodes[name].groups.flammable and minetest.registered_nodes[name].groups.flammable > 0
	end
	if not(name == lighting or  string.match(name, "dtrack")) and (add_dry_tunnels or not(add_dry_tunnels or string.match(name, "water"))) and (add_wide_passage or not(add_wide_passage or group_flammable)) then
		minetest.set_node(pos, {name = "air"})
	end
end

local region3 = function(x, y, z, user, pointed_thing)
	local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
	local name = minetest.get_node(pos).name
	if add_dry_tunnels and string.match(name, "water") then
			minetest.set_node(pos, {name = glass_walls})
	else
		local group_flammable = false
		if minetest.registered_nodes[name] then
			group_flammable = minetest.registered_nodes[name].groups.flammable and minetest.registered_nodes[name].groups.flammable > 0
		end
		if not(string.match(name, "water") or name == "air" or name == glass_walls or name == coating_not_desert or (add_embankment and name == "tunnelmaker:embankment") or name == marking_not_desert or name == marking_desert or name == lighting or string.match(name, "dtrack")) and add_tough_tunnels then
			if not group_flammable then
				if is_desert(pos) then
					minetest.set_node(pos, {name = coating_desert})
				else
					minetest.set_node(pos, {name = coating_not_desert})
				end
			else
				if add_wide_passage then
					minetest.set_node(pos, {name = "air"})
				end
			end
		end
	end
end

local region4 = function(x, y, z, user, pointed_thing)
	local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
	local name = minetest.get_node(pos).name
	if not string.match(name, "dtrack") then
		if add_marking then
			if is_desert(pos) then
				minetest.set_node(pos, {name = marking_desert})
			else
				minetest.set_node(pos, {name = marking_not_desert})
			end
		else
			if add_embankment then
				minetest.set_node(pos, {name = "tunnelmaker:embankment"})
			else
				if is_desert(pos) then
					minetest.set_node(pos, {name = coating_desert})
				else
					minetest.set_node(pos, {name = coating_not_desert})
				end
			end
		end
	end
end

local region5 = function(x, y, z, user, pointed_thing)
	local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
	local name = minetest.get_node(pos).name
	if not(name == marking_not_desert or name == marking_desert or string.match(name, "dtrack")) then
		if add_embankment then
			minetest.set_node(pos, {name = "tunnelmaker:embankment"})
		else
			if is_desert(pos) then
				minetest.set_node(pos, {name = coating_desert})
			else
				minetest.set_node(pos, {name = coating_not_desert})
			end
		end
	end
end

local region6 = function(x, y, z, user, pointed_thing)
	local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
	local name = minetest.get_node(pos).name
	if not(name == coating_not_desert or name == marking_not_desert or name == marking_desert or string.match(name, "dtrack")) and add_embankment then
		if is_desert(pos) then
			minetest.set_node(pos, {name = coating_desert})
		else
			minetest.set_node(pos, {name = coating_not_desert})
		end
	end
end

local region7 = function(x, y, z, user, pointed_thing)
	local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
	local name = minetest.get_node(pos).name
	if not(name == coating_not_desert or name == marking_not_desert or name == marking_desert or string.match(name, "dtrack")) then
		if is_desert(pos) then
			minetest.set_node(pos, {name = coating_desert})
		else
			minetest.set_node(pos, {name = coating_not_desert})
		end
	end
end

local region8 = function(x, y, z, user, pointed_thing)
	local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
	local name = minetest.get_node(pos).name
	local group_flammable = false
	if minetest.registered_nodes[name] then
		group_flammable = minetest.registered_nodes[name].groups.flammable and minetest.registered_nodes[name].groups.flammable > 0
	end
	if not(name == coating_not_desert or name == marking_not_desert or name == marking_desert or string.match(name, "dtrack")) and add_embankment and (add_wide_passage or not(add_wide_passage or group_flammable)) then
		if is_desert(pos) then
			minetest.set_node(pos, {name = coating_desert})
		else
			minetest.set_node(pos, {name = coating_not_desert})
		end
	end
end


local ggggg = function(x, y0, y1, z, user, pointed_thing)
	for y=y1, y0, -1 do
		region3(x, y, z, user, pointed_thing)
	end
end

local ggagg = function(x, y0, y1, z, user, pointed_thing)
	region3(x, y1+2, z, user, pointed_thing)
	if add_arches then
		region3(x, y1+1, z, user, pointed_thing)
	else
		region2(x, y1+1, z, user, pointed_thing)
	end
	for y=y1, y0+1, -1 do
		region2(x, y, z, user, pointed_thing)
	end
	region3(x, y0, z, user, pointed_thing)
	region3(x, y0-1, z, user, pointed_thing)
	region8(x, y0-2, z, user, pointed_thing)
end

local gaagg = function(x, y0, y1, z, user, pointed_thing)
	region3(x, y1+2, z, user, pointed_thing)
	if add_arches then
		region3(x, y1+1, z, user, pointed_thing)
	else
		region2(x, y1+1, z, user, pointed_thing)
	end
	for y=y1, y0+1, -1 do
		region2(x, y, z, user, pointed_thing)
	end
	region3(x, y0, z, user, pointed_thing)
	region8(x, y0-1, z, user, pointed_thing)
end

local gaggg = function(x, y0, y1, z, user, pointed_thing)
	region3(x, y1+3, z, user, pointed_thing)
	region3(x, y1+2, z, user, pointed_thing)
	if add_arches then
		region3(x, y1+1, z, user, pointed_thing)
	else
		region2(x, y1+1, z, user, pointed_thing)
	end
	for y=y1, y0+1, -1 do
		region2(x, y, z, user, pointed_thing)
	end
	region3(x, y0, z, user, pointed_thing)
	region8(x, y0-1, z, user, pointed_thing)
end

local gaxgx = function(x, y0, y1, z, user, pointed_thing)
	region3(x, y1+2, z, user, pointed_thing)
	if add_arches then
		region3(x, y1+1, z, user, pointed_thing)
	else
		region3(x, y1+3, z, user, pointed_thing)
		region2(x, y1+1, z, user, pointed_thing)
	end
	for y=y1, y0+1, -1 do
		region2(x, y, z, user, pointed_thing)
	end
	region3(x, y0, z, user, pointed_thing)
	region8(x, y0-1, z, user, pointed_thing)
end

local saagg = function(x, y0, y1, z, user, pointed_thing)
	region3(x, y1+2, z, user, pointed_thing)
	region3(x, y1+1, z, user, pointed_thing)
	region2(x, y1, z, user, pointed_thing)
	for y=y1-1, y0+1, -1 do
		region0(x, y, z, user, pointed_thing)
	end
	region5(x, y0, z, user, pointed_thing)
	region6(x, y0-1, z, user, pointed_thing)
end

local ssaag = function(x, y0, y1, z, user, pointed_thing)
	region3(x, y1+1, z, user, pointed_thing)
	region2(x, y1, z, user, pointed_thing)
	for y=y1-1, y0+1, -1 do
		region0(x, y, z, user, pointed_thing)
	end
	region5(x, y0, z, user, pointed_thing)
	region7(x, y0-1, z, user, pointed_thing)
	region6(x, y0-2, z, user, pointed_thing)
end

local saaag = function(x, y0, y1, z, user, pointed_thing)
	region3(x, y1+1, z, user, pointed_thing)
	region2(x, y1, z, user, pointed_thing)
	for y=y1-1, y0+1, -1 do
		region0(x, y, z, user, pointed_thing)
	end
	region5(x, y0, z, user, pointed_thing)
	region6(x, y0-1, z, user, pointed_thing)
end

local baaag = function(x, y0, y1, z, user, pointed_thing)
	region3(x, y1+1, z, user, pointed_thing)
	region2(x, y1, z, user, pointed_thing)
	for y=y1-1, y0+1, -1 do
		region0(x, y, z, user, pointed_thing)
	end
	region4(x, y0, z, user, pointed_thing)
	region6(x, y0-1, z, user, pointed_thing)
end

local baagg = function(x, y0, y1, z, user, pointed_thing)
	region3(x, y1+2, z, user, pointed_thing)
	region3(x, y1+1, z, user, pointed_thing)
	region2(x, y1, z, user, pointed_thing)
	for y=y1-1, y0+1, -1 do
		region0(x, y, z, user, pointed_thing)
	end
	region4(x, y0, z, user, pointed_thing)
	region6(x, y0-1, z, user, pointed_thing)
end

local sbaag = function(x, y0, y1, z, user, pointed_thing)
	region3(x, y1+1, z, user, pointed_thing)
	region2(x, y1, z, user, pointed_thing)
	for y=y1-1, y0+1, -1 do
		region0(x, y, z, user, pointed_thing)
	end
	region4(x, y0, z, user, pointed_thing)
	region7(x, y0-1, z, user, pointed_thing)
	region6(x, y0-2, z, user, pointed_thing)
end

-- Add flips and rotates so I only need to define the seven basic digging patterns.
-- For flip: 1 = vertical, -1 = horizontal, 2 = both.
-- For rotate: 1 = clockwise, -1 = counterclockwise.

local fliprot = function(pos, f, r)
	local res = {}
	if f == 2 then  -- double flip
		res.x = -pos.x
		res.z = -pos.z
	elseif f ~= 0 and r == 0 then  -- single flip
		res.x = f * pos.x
		res.z = -f * pos.z
	elseif f == 0 and r ~= 0 then  -- rotate
		res.x = r * pos.z
		res.z = -r * pos.x
	elseif f ~= 0 and r ~= 0 then  -- flip + rotate
		res.x = f * r * pos.z
		res.z = f * r * pos.x
	else  -- identity
		res.x = pos.x
		res.z = pos.z
	end
	return res
end

-- To shorten the code, this function takes a list of lists with {function, x-coord, y-coord} and executes them in sequence.
local run_list = function(dir_list, f, r, user, pointed_thing)
	for _,v in ipairs(dir_list) do
		local pos = {}
		pos.x = v[2]
		pos.z = v[5]
		local newpos = fliprot(pos, f, r)
		v[1](newpos.x, v[3], v[4], newpos.z, user, pointed_thing)
	end
end

-- Dig tunnel based on direction given.
local dig_tunnel = function(cdir, user, pointed_thing)
	if minetest.check_player_privs(user, "tunneling") then
		local ath = ith
		if not add_arches then
			ath = ith+1
		end

		local dig_patterns = {
			-- Orthogonal (north reference).
			[1] = { {ggggg,-3, 0, 5+ath, 3},{ggggg,-2, 0, 6+ith, 3},{ggggg,-1, 0, 6+ith, 3},{ggggg, 0, 0, 6+ith, 3},{ggggg, 1, 0, 6+ith, 3},{ggggg, 2, 0, 6+ith, 3},{ggggg, 3, 0, 5+ath, 3},
					{ggggg,-3, 0, 5+ath, 2},{gaagg,-2, 0, 4+ith, 2},{saaag,-1, 0, 5+ith, 2},{baaag, 0, 0, 5+ith, 2},{saaag, 1, 0, 5+ith, 2},{gaagg, 2, 0, 4+ith, 2},{ggggg, 3, 0, 5+ath, 2},
					{ggggg,-3, 0, 5+ath, 1},{gaagg,-2, 0, 4+ith, 1},{saaag,-1, 0, 5+ith, 1},{saaag, 0, 0, 5+ith, 1},{saaag, 1, 0, 5+ith, 1},{gaagg, 2, 0, 4+ith, 1},{ggggg, 3, 0, 5+ath, 1},
					{ggggg,-3, 0, 5+ath, 0},{gaagg,-2, 0, 4+ith, 0},{saaag,-1, 0, 5+ith, 0},{baaag, 0, 0, 5+ith, 0},{saaag, 1, 0, 5+ith, 0},{gaagg, 2, 0, 4+ith, 0},{ggggg, 3, 0, 5+ath, 0},
					{ggggg,-3, 0, 5+ath,-1},{ggggg,-2, 0, 6+ith,-1},{ggggg,-1, 0, 6+ith,-1},{ggggg, 0, 0, 6+ith,-1},{ggggg, 1, 0, 6+ith,-1},{ggggg, 2, 0, 6+ith,-1},{ggggg, 3, 0, 5+ath,-1},
					},
			-- Knight move (north-northwest reference).
			[2] = { {ggggg,-4, 0, 5+ath, 3},{ggggg,-3, 0, 6+ith, 3},{ggggg,-2, 0, 6+ith, 3},{ggggg,-1, 0, 6+ith, 3},{ggggg, 0, 0, 6+ith, 3},{ggggg, 1, 0, 6+ith, 3},{ggggg, 2, 0, 5+ath, 3},
					{ggggg,-4, 0, 5+ath, 2},{gaagg,-3, 0, 4+ith, 2},{saaag,-2, 0, 5+ith, 2},{baaag,-1, 0, 5+ith, 2},{saaag, 0, 0, 5+ith, 2},{gaagg, 1, 0, 4+ith, 2},{ggggg, 2, 0, 6+ith, 2},{ggggg, 3, 0, 5+ath, 2},
					{ggggg,-4, 0, 5+ath, 1},{gaagg,-3, 0, 4+ith, 1},{saaag,-2, 0, 5+ith, 1},{saaag,-1, 0, 5+ith, 1},{saaag, 0, 0, 5+ith, 1},{saaag, 1, 0, 5+ith, 1},{gaagg, 2, 0, 4+ith, 1},{ggggg, 3, 0, 5+ath, 1},
					{ggggg,-4, 0, 5+ath, 0},{ggggg,-3, 0, 6+ith, 0},{gaagg,-2, 0, 4+ith, 0},{saaag,-1, 0, 5+ith, 0},{baaag, 0, 0, 5+ith, 0},{saaag, 1, 0, 5+ith, 0},{gaagg, 2, 0, 4+ith, 0},{ggggg, 3, 0, 5+ath, 0},
											{ggggg,-3, 0, 5+ath,-1},{ggggg,-2, 0, 6+ith,-1},{ggggg,-1, 0, 6+ith,-1},{ggggg, 0, 0, 6+ith,-1},{ggggg, 1, 0, 6+ith,-1},{ggggg, 2, 0, 6+ith,-1},{ggggg, 3, 0, 5+ath,-1},
					},
			-- Diagonal (northwest reference).
			[3] = {																			{ggggg,-1, 0, 5+ath, 4},{ggggg, 0, 0, 5+ath, 4},{ggggg, 1, 0, 5+ath, 4},
																							{ggggg,-1, 0, 6+ith, 3},{gaagg, 0, 0, 4+ith, 3},{ggggg, 1, 0, 6+ith, 3},{ggggg, 2, 0, 5+ath, 3},
																	{ggggg,-2, 0, 6+ith, 2},{ggggg,-1, 0, 6+ith, 2},{saaag, 0, 0, 5+ith, 2},{gaagg, 1, 0, 4+ith, 2},{ggggg, 2, 0, 6+ith, 2},{ggggg, 3, 0, 5+ath, 2},
					{ggggg,-4, 0, 5+ath, 1},{ggggg,-3, 0, 6+ith, 1},{ggggg,-2, 0, 6+ith, 1},{baaag,-1, 0, 5+ith, 1},{saaag, 0, 0, 5+ith, 1},{saaag, 1, 0, 5+ith, 1},{gaagg, 2, 0, 4+ith, 1},{ggggg, 3, 0, 5+ath, 1},
					{ggggg,-4, 0, 5+ath, 0},{gaagg,-3, 0, 4+ith, 0},{saaag,-2, 0, 5+ith, 0},{saaag,-1, 0, 5+ith, 0},{baaag, 0, 0, 5+ith, 0},{ggggg, 1, 0, 6+ith, 0},{ggggg, 2, 0, 6+ith, 0},{ggggg, 3, 0, 5+ath, 0},
					{ggggg,-4, 0, 5+ath,-1},{ggggg,-3, 0, 6+ith,-1},{gaagg,-2, 0, 4+ith,-1},{saaag,-1, 0, 5+ith,-1},{ggggg, 0, 0, 6+ith,-1},{ggggg, 1, 0, 6+ith,-1},
											{ggggg,-3, 0, 5+ath,-2},{ggggg,-2, 0, 6+ith,-2},{gaagg,-1, 0, 4+ith,-2},{ggggg, 0, 0, 6+ith,-2},
																	{ggggg,-2, 0, 5+ath,-3},{ggggg,-1, 0, 5+ath,-3},{ggggg, 0, 0, 5+ath,-3},
					},
			-- Orthogonal slope down (north reference).
			[10] = {{ggggg,-3,-1, 4+ath, 3},{ggggg,-2,-1, 5+ith, 3},{ggggg,-1,-1, 5+ith, 3},{ggggg, 0,-1, 5+ith, 3},{ggggg, 1,-1, 5+ith, 3},{ggggg, 2,-1, 5+ith, 3},{ggggg, 3,-1, 4+ath, 3},
					{ggggg,-3,-1, 5+ath, 2},{gaggg,-2,-1, 3+ith, 2},{saagg,-1,-1, 4+ith, 2},{baagg, 0,-1, 4+ith, 2},{saagg, 1,-1, 4+ith, 2},{gaggg, 2,-1, 3+ith, 2},{ggggg, 3,-1, 5+ath, 2},
					{ggggg,-3,-1, 5+ath, 1},{gaagg,-2,-1, 4+ith, 1},{saaag,-1,-1, 5+ith, 1},{saaag, 0,-1, 5+ith, 1},{saaag, 1,-1, 5+ith, 1},{gaagg, 2,-1, 4+ith, 1},{ggggg, 3,-1, 5+ath, 1},
					{ggggg,-3,-1, 5+ath, 0},{ggagg,-2, 0, 4+ith, 0},{ssaag,-1, 0, 5+ith, 0},{sbaag, 0, 0, 5+ith, 0},{ssaag, 1, 0, 5+ith, 0},{ggagg, 2, 0, 4+ith, 0},{ggggg, 3,-1, 5+ath, 0},
					{ggggg,-3, 0, 5+ath,-1},{ggggg,-2, 0, 6+ith,-1},{ggggg,-1, 0, 6+ith,-1},{ggggg, 0, 0, 6+ith,-1},{ggggg, 1, 0, 6+ith,-1},{ggggg, 2, 0, 6+ith,-1},{ggggg, 3, 0, 5+ath,-1},
					},
			-- Orthogonal slope up (north reference).
			[11] = {{ggggg,-3, 1, 6+ath, 3},{ggggg,-2, 1, 7+ith, 3},{ggggg,-1, 1, 7+ith, 3},{ggggg, 0, 1, 7+ith, 3},{ggggg, 1, 1, 7+ith, 3},{ggggg, 2, 1, 7+ith, 3},{ggggg, 3, 1, 6+ath, 3},
					{ggggg,-3, 0, 6+ath, 2},{ggagg,-2, 1, 5+ith, 2},{ssaag,-1, 1, 6+ith, 2},{sbaag, 0, 1, 6+ith, 2},{ssaag, 1, 1, 6+ith, 2},{ggagg, 2, 1, 5+ith, 2},{ggggg, 3, 0, 6+ath, 2},
					{ggggg,-3, 0, 6+ath, 1},{gaagg,-2, 0, 5+ith, 1},{saaag,-1, 0, 6+ith, 1},{saaag, 0, 0, 6+ith, 1},{saaag, 1, 0, 6+ith, 1},{gaagg, 2, 0, 5+ith, 1},{ggggg, 3, 0, 6+ath, 1},
					{ggggg,-3, 0, 6+ath, 0},{gaggg,-2, 0, 4+ith, 0},{saagg,-1, 0, 5+ith, 0},{baagg, 0, 0, 5+ith, 0},{saagg, 1, 0, 5+ith, 0},{gaggg, 2, 0, 4+ith, 0},{ggggg, 3, 0, 6+ath, 0},
					{ggggg,-3, 0, 5+ath,-1},{ggggg,-2, 0, 6+ith,-1},{ggggg,-1, 0, 6+ith,-1},{ggggg, 0, 0, 6+ith,-1},{ggggg, 1, 0, 6+ith,-1},{ggggg, 2, 0, 6+ith,-1},{ggggg, 3, 0, 5+ath,-1},
					},
			-- Diagonal slope down (northwest reference).
			[30] = {																		{ggggg,-1,-1, 4+ath, 4},{ggggg, 0,-1, 4+ath, 4},{ggggg, 1,-1, 4+ath, 4},
																							{ggggg,-1,-1, 5+ith, 3},{gaxgx, 0,-1, 3+ith, 3},{ggggg, 1,-1, 5+ath, 3},{ggggg, 2,-1, 5+ath, 3},
																	{ggggg,-2,-1, 5+ith, 2},{ggggg,-1,-1, 6+ith, 2},{saagg, 0,-1, 4+ith, 2},{gaagg, 1,-1, 4+ith, 2},{ggggg, 2,-1, 6+ith, 2},{ggggg, 3, 0, 5+ath, 2},
					{ggggg,-4,-1, 4+ath, 1},{ggggg,-3,-1, 5+ith, 1},{ggggg,-2,-1, 6+ith, 1},{baagg,-1,-1, 4+ith, 1},{saaag, 0,-1, 5+ith, 1},{ssaag, 1, 0, 5+ith, 1},{ggagg, 2, 0, 4+ith, 1},{ggggg, 3, 0, 5+ath, 1},
					{ggggg,-4,-1, 4+ath, 0},{gaxgx,-3,-1, 3+ith, 0},{saagg,-2,-1, 4+ith, 0},{saaag,-1,-1, 5+ith, 0},{sbaag, 0, 0, 5+ith, 0},{ggggg, 1, 0, 6+ith, 0},{ggggg, 2, 0, 6+ith, 0},{ggggg, 3, 0, 5+ath, 0},
					{ggggg,-4,-1, 4+ath,-1},{ggggg,-3,-1, 5+ath,-1},{gaagg,-2,-1, 4+ith,-1},{ssaag,-1, 0, 5+ith,-1},{ggggg, 0, 0, 6+ith,-1},{ggggg, 1, 0, 6+ith,-1},
											{ggggg,-3,-1, 5+ath,-2},{ggggg,-2,-1, 6+ith,-2},{ggagg,-1, 0, 4+ith,-2},{ggggg, 0, 0, 6+ith,-2},
																	{ggggg,-2, 0, 5+ath,-3},{ggggg,-1, 0, 5+ath,-3},{ggggg, 0, 0, 5+ath,-3},
					},
			-- Diagonal slope up (northwest reference).
			[31] = {																		{ggggg,-1, 1, 6+ath, 4},{ggggg, 0, 1, 6+ath, 4},{ggggg, 1, 1, 6+ath, 4},
																							{ggggg,-1, 1, 7+ith, 3},{ggagg, 0, 1, 5+ith, 3},{ggggg, 1, 0, 7+ith, 3},{ggggg, 2, 0, 6+ath, 3},
																	{ggggg,-2, 1, 7+ith, 2},{ggggg,-1, 1, 7+ith, 2},{ssaag, 0, 1, 6+ith, 2},{gaagg, 1, 0, 5+ith, 2},{ggggg, 2, 0, 6+ath, 2},{ggggg, 3, 0, 5+ath, 2},
					{ggggg,-4, 1, 6+ath, 1},{ggggg,-3, 1, 7+ith, 1},{ggggg,-2, 1, 7+ith, 1},{sbaag,-1, 1, 6+ith, 1},{saaag, 0, 0, 6+ith, 1},{saagg, 1, 0, 5+ith, 1},{gaxgx, 2, 0, 4+ith, 1},{ggggg, 3, 0, 5+ath, 1},
					{ggggg,-4, 1, 6+ath, 0},{ggagg,-3, 1, 5+ith, 0},{ssaag,-2, 1, 6+ith, 0},{saaag,-1, 0, 6+ith, 0},{baagg, 0, 0, 5+ith, 0},{ggggg, 1, 0, 7+ith, 0},{ggggg, 2, 0, 6+ith, 0},{ggggg, 3, 0, 5+ath, 0},
					{ggggg,-4, 1, 6+ath,-1},{ggggg,-3, 0, 7+ith,-1},{gaagg,-2, 0, 5+ith,-1},{saagg,-1, 0, 5+ith,-1},{ggggg, 0, 0, 7+ith,-1},{ggggg, 1, 0, 6+ith,-1},
											{ggggg,-3, 0, 6+ath,-2},{ggggg,-2, 0, 6+ath,-2},{gaxgx,-1, 0, 4+ith,-2},{ggggg, 0, 0, 6+ith,-2},
																	{ggggg,-2, 0, 5+ath,-3},{ggggg,-1, 0, 5+ath,-3},{ggggg, 0, 0, 5+ath,-3},
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

		local dig_list = dig_patterns[dig_lookup[cdir][1]]
		local flip = dig_lookup[cdir][2]
		local rotation = dig_lookup[cdir][3]
		run_list(dig_list, flip, rotation, user, pointed_thing)
		region1(lighting_search_radius, user, pointed_thing)
	end
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
			local pname = player:get_player_name()
			local pos = pointed_thing.under
			local key_stats = player:get_player_control()
			-- If sneak button held down when left-clicking tunnelmaker, brings up User Config formspec.
			if key_stats.sneak then  -- Configuration formspec
				local formspec = "size[4,3]"..
					"label[0.25,0.25;Tunnelmaker User Options]"..
					"checkbox[0.25,0.75;remove_refs;Remove reference nodes;"..tostring(user_config[pname].remove_refs).."]"..
					"checkbox[0.25,1.25;nontrain_tunnels;Dig non-train tunnels;"..tostring(user_config[pname].nontrain_tunnels).."]"..
					"checkbox[0.25,1.75;continuous_updown;Continuous updown digging;"..tostring(user_config[pname].continuous_updown).."]"
				minetest.show_formspec(pname, "tunnelmaker:form", formspec)
			else
				if pos ~= nil then
					minetest.node_dig(pos, minetest.get_node(pos), player)
					minetest.sound_play("default_dig_dig_immediate", {pos=pos, max_hear_distance = 8, gain = 0.5})
				end
			end
		end,

		-- Dig tunnel with right mouse click (double tap on android)
		on_place = function(itemstack, placer, pointed_thing)
			local pname = placer and placer:get_player_name() or ""
			-- If sneak button held down when right-clicking tunnelmaker, toggle updown dig direction:  up, down, horizontal, ...
			-- Rotating or moving will reset to horizontal.
			if placer:get_player_control().sneak then
				tunnelmaker[pname].updown = (tunnelmaker[pname].updown + 1) % 3
				tunnelmaker[pname].lastpos = { x = placer:getpos().x, y = placer:getpos().y, z = placer:getpos().z }
			-- Otherwise dig tunnel based on direction pointed and current updown direction
			elseif pointed_thing.type=="node" then
				-- if advtrains_track, I lower positions of pointed_thing to right below track, but keep name the same.
				local name = minetest.get_node(pointed_thing.under).name
				-- if minetest.registered_nodes[name].groups.advtrains_track == 1 then
				if string.match(name, "dtrack") then
					pointed_thing.under = vector.add(pointed_thing.under, {x=0, y=-1, z=0})
					--pointed_thing.above = vector.add(pointed_thing.above, {x=0, y=-1, z=0})  -- don't currently use this
				end
				minetest.sound_play("default_dig_dig_immediate", {pos=pos, max_hear_distance = 8, gain = 1.0})
				dig_tunnel(i-1, placer, pointed_thing)
				if not user_config[pname].continuous_updown then
					tunnelmaker[pname].updown = 0   -- reset to horizontal after one use
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
	minetest.debug(minetest.serialize(fields))
	local pname = player:get_player_name()
	if fields.remove_refs == "true" then user_config[pname].remove_refs = true
	elseif fields.remove_refs == "false" then user_config[pname].remove_refs = false
	elseif fields.nontrain_tunnels == "true" then
		user_config[pname].nontrain_tunnels = true
		ith = 0
		add_arches = false
		add_embankment = false
		add_marking = false
		add_tough_tunnels = false
		add_wide_passage = false
	elseif fields.nontrain_tunnels == "false" then
		user_config[pname].nontrain_tunnels = false
		ith = ith_train
		add_arches = add_arches_train
		add_embankment = add_embankment_train
		add_marking = add_marking_train
		add_tough_tunnels = add_tough_tunnels_train
		add_wide_passage = add_wide_passage_train
	elseif fields.continuous_updown == "true" then user_config[pname].continuous_updown = true
	elseif fields.continuous_updown == "false" then user_config[pname].continuous_updown = false
	end
	return true
end)

-- Remove marking
-- Is used for replaces marking_not_desert and marking_desert nodes to "tunnelmaker:embankment" under the railroad tracks advtrains.
-- Expose api
local remove_marking = {}

remove_marking.replace = function(player_pos)
	local count = 0

	-- Gen pos1 and pos2
	player_pos = vector.round(player_pos)
	local pos1 = vector.subtract(player_pos, 1)
	local pos2 = vector.add(player_pos, 1)

	-- Read data into LVM
	local vm = minetest.get_voxel_manip()
	local emin, emax = vm:read_from_map(pos1, pos2)
	local a = VoxelArea:new{
		MinEdge = emin,
		MaxEdge = emax
	}
	local data = vm:get_data()

	-- Modify data
	for z = pos1.z, pos2.z do
		for y = pos1.y, pos2.y do
			for x = pos1.x, pos2.x do
				local vi = a:index(x, y, z)
				if data[vi] == minetest.get_content_id(marking_not_desert) or data[vi] == minetest.get_content_id(marking_desert) then
					if add_embankment then
						data[vi] = minetest.get_content_id("tunnelmaker:embankment")
					else
						if is_desert({x=x, y=y, z=z}) then
							data[vi] = minetest.get_content_id(coating_desert)
						else
							data[vi] = minetest.get_content_id(coating_not_desert)
						end
					end
				end
			end
		end
	end
	-- Write data
	vm:set_data(data)
	vm:write_to_map(true)
end

-- Replaces marking_not_desert and marking_desert nodes to "tunnelmaker:embankment".
minetest.register_globalstep(function(dtime)
	for _, player in ipairs(minetest.get_connected_players()) do
		if user_config[player:get_player_name()].remove_refs then
			remove_marking.replace(player:getpos())
		end
	end
end)
