-- tunnelmaker
-- Another tunnel digging mod for minetest.
-- Digs tunnels and builds simple bridges for advtrains track, supporting
-- all 16 track directions, along with slopes up and down.
-- 
-- by David G (kestral246@gmail.com)

-- Version 1.X.X - 2018-12-20

-- based on compassgps 2.7 and compass 0.5

-- To the extent possible under law, the author(s) have dedicated all copyright and related
-- and neighboring rights to this software to the public domain worldwide. This software is
-- distributed without any warranty.

-- You should have received a copy of the CC0 Public Domain Dedication along with this
-- software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>. 


-- Configuration variables
-- Functional

-- Allow the use of other materials in desert biomes
local add_desert_material = minetest.settings:get_bool("add_desert_material", false)

-- Allow to replace the coating of tunnels on a specific coating
local add_tough_tunnels = minetest.settings:get_bool("add_tough_tunnels", true)

-- Allow wide paths in the woods. Greenpeace does not approve
local add_wide_passage = minetest.settings:get_bool("add_wide_passage", true)

-- Allow to replace water in air and a transparent coating tunnels
local add_dry_tunnels = minetest.settings:get_bool("add_dry_tunnels", true)

-- Add ceiling lighting
local add_lighting = minetest.settings:get_bool("add_lighting", true)

-- Add gravel mound and additional base
local add_embankment = minetest.settings:get_bool("add_embankment", true)

-- Add markup for the railway advtrains
local add_marking = minetest.settings:get_bool("add_marking", true)

-- Allow digging up/down multiple times without resetting mode
local continuous_updown_digging = minetest.settings:get_bool("continuous_updown_digging", true)

-- Add "arches" along the sides.
local add_arches = minetest.settings:get_bool("add_arches", true)

-- Materials

-- Walls, floor and additional base (outside the desert)
local coating_not_desert = minetest.settings:get("coating_not_desert") or "default:stone"

-- Walls, floor and additional base (in the desert)
local coating_desert = minetest.settings:get("coating_desert") or "default:desert_stone"

-- Walls in the water
local glass_walls = minetest.settings:get("glass_walls") or "default:glass"

-- Ceiling lighting
local lighting = minetest.settings:get("lighting") or "default:mese_post_light"

-- Embankment for railway tracks
local embankment = minetest.settings:get("embankment") or "default:gravel"

-- Railway markings for advtrains (outside the desert)
local marking_not_desert = minetest.settings:get("marking_not_desert") or "default:stone_block"

-- Railway markings for advtrains (in the desert)
local marking_desert = minetest.settings:get("marking_desert") or "default:desert_stone_block"

-- Parameters

-- Distance between illumination (from 0 to 4)
local lighting_search_radius = tonumber(minetest.settings:get("lighting_search_radius") or 1)

-- Increase tunnel height 
local ith = (tonumber(minetest.settings:get("tunnel_height") or 5))-5

-- End of configuration
minetest.register_privilege("tunneling", {description = "Allow use of tunnelmaker tool"})

-- Define top level variable to maintain per player state
local tunnelmaker = {}

-- Initialize player's state when player joins
minetest.register_on_joinplayer(function(player)
	tunnelmaker[player:get_player_name()] = {updown = 0, lastdir = -1, lastpos = {x = 0, y = 0, z = 0}}
end)

-- Delete player's state when player leaves
minetest.register_on_leaveplayer(function(player)
	local pname = player:get_player_name()
	if tunnelmaker[pname] then
		tunnelmaker[pname] = nil
	end
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
			if rawdir ~= tunnelmaker[pname].lastdir or (not continuous_updown_digging and delta > 0.2) then  -- tune to make distance moved feel right
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
		"tunnelmaker_0.png",
		"tunnelmaker_1.png",
		"tunnelmaker_2.png",
		"tunnelmaker_3.png",
		"tunnelmaker_4.png",
		"tunnelmaker_5.png",
		"tunnelmaker_6.png",
		"tunnelmaker_7.png",
		"tunnelmaker_8.png",
		"tunnelmaker_9.png",
		"tunnelmaker_10.png",
		"tunnelmaker_11.png",
		"tunnelmaker_12.png",
		"tunnelmaker_13.png",
		"tunnelmaker_14.png",
		"tunnelmaker_15.png",
		"tunnelmaker_16.png",   -- 0 up
		"tunnelmaker_17.png",   -- 2 up
		"tunnelmaker_18.png",   -- 4 up
		"tunnelmaker_19.png",   -- 6 up
		"tunnelmaker_20.png",   -- 8 up
		"tunnelmaker_21.png",   -- 10 up
		"tunnelmaker_22.png",   -- 12 up
		"tunnelmaker_23.png",   -- 14 up
		"tunnelmaker_24.png",   -- 0 down
		"tunnelmaker_25.png",   -- 2 down
		"tunnelmaker_26.png",   -- 4 down
		"tunnelmaker_27.png",   -- 6 down
		"tunnelmaker_28.png",   -- 8 down
		"tunnelmaker_29.png",   -- 10 down
		"tunnelmaker_30.png",   -- 12 down
		"tunnelmaker_31.png",   -- 14 down
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

-- Visible location of the regions¹ in the cut of the direct tunnel. Region ¹7 is used for ascents and descents between ¹6 and ¹4/¹5
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

-- To shorten the code, this function takes a list of lists with {function, x-coord, y-coord} and executes them in sequence.
local run_list = function(dir_list, user, pointed_thing)
	for i,v in ipairs(dir_list) do
		v[1](v[2], v[3], v[4], v[5], user, pointed_thing)
	end
end


-- dig tunnel based on direction given
local dig_tunnel = function(cdir, user, pointed_thing)
	if minetest.check_player_privs(user, "tunneling") then
		local ath = ith
		if not add_arches then
			ath = ith+1
		end
		-- Dig horizontal
		if cdir == 0 then  -- pointed north
			run_list(  {{ggggg,-3, 0, 5+ath, 3},{ggggg,-2, 0, 6+ith, 3},{ggggg,-1, 0, 6+ith, 3},{ggggg, 0, 0, 6+ith, 3},{ggggg, 1, 0, 6+ith, 3},{ggggg, 2, 0, 6+ith, 3},{ggggg, 3, 0, 5+ath, 3},
						{ggggg,-3, 0, 5+ath, 2},{gaagg,-2, 0, 4+ith, 2},{saaag,-1, 0, 5+ith, 2},{baaag, 0, 0, 5+ith, 2},{saaag, 1, 0, 5+ith, 2},{gaagg, 2, 0, 4+ith, 2},{ggggg, 3, 0, 5+ath, 2},
						{ggggg,-3, 0, 5+ath, 1},{gaagg,-2, 0, 4+ith, 1},{saaag,-1, 0, 5+ith, 1},{saaag, 0, 0, 5+ith, 1},{saaag, 1, 0, 5+ith, 1},{gaagg, 2, 0, 4+ith, 1},{ggggg, 3, 0, 5+ath, 1},
						{ggggg,-3, 0, 5+ath, 0},{gaagg,-2, 0, 4+ith, 0},{saaag,-1, 0, 5+ith, 0},{baaag, 0, 0, 5+ith, 0},{saaag, 1, 0, 5+ith, 0},{gaagg, 2, 0, 4+ith, 0},{ggggg, 3, 0, 5+ath, 0},
						{ggggg,-3, 0, 5+ath,-1},{ggggg,-2, 0, 6+ith,-1},{ggggg,-1, 0, 6+ith,-1},{ggggg, 0, 0, 6+ith,-1},{ggggg, 1, 0, 6+ith,-1},{ggggg, 2, 0, 6+ith,-1},{ggggg, 3, 0, 5+ath,-1},
						}, user, pointed_thing)

		elseif cdir == 1 then  -- pointed north-northwest
			run_list(  {{ggggg,-4, 0, 5+ath, 3},{ggggg,-3, 0, 6+ith, 3},{ggggg,-2, 0, 6+ith, 3},{ggggg,-1, 0, 6+ith, 3},{ggggg, 0, 0, 6+ith, 3},{ggggg, 1, 0, 6+ith, 3},{ggggg, 2, 0, 5+ath, 3},
						{ggggg,-4, 0, 5+ath, 2},{gaagg,-3, 0, 4+ith, 2},{saaag,-2, 0, 5+ith, 2},{baaag,-1, 0, 5+ith, 2},{saaag, 0, 0, 5+ith, 2},{gaagg, 1, 0, 4+ith, 2},{ggggg, 2, 0, 6+ith, 2},{ggggg, 3, 0, 5+ath, 2},
						{ggggg,-4, 0, 5+ath, 1},{gaagg,-3, 0, 4+ith, 1},{saaag,-2, 0, 5+ith, 1},{saaag,-1, 0, 5+ith, 1},{saaag, 0, 0, 5+ith, 1},{saaag, 1, 0, 5+ith, 1},{gaagg, 2, 0, 4+ith, 1},{ggggg, 3, 0, 5+ath, 1},
						{ggggg,-4, 0, 5+ath, 0},{ggggg,-3, 0, 6+ith, 0},{gaagg,-2, 0, 4+ith, 0},{saaag,-1, 0, 5+ith, 0},{baaag, 0, 0, 5+ith, 0},{saaag, 1, 0, 5+ith, 0},{gaagg, 2, 0, 4+ith, 0},{ggggg, 3, 0, 5+ath, 0},
												{ggggg,-3, 0, 5+ath,-1},{ggggg,-2, 0, 6+ith,-1},{ggggg,-1, 0, 6+ith,-1},{ggggg, 0, 0, 6+ith,-1},{ggggg, 1, 0, 6+ith,-1},{ggggg, 2, 0, 6+ith,-1},{ggggg, 3, 0, 5+ath,-1},
						}, user, pointed_thing)

		elseif cdir == 2 then  -- pointed northwest
			run_list(  {																		{ggggg,-1, 0, 5+ath, 4},{ggggg, 0, 0, 5+ath, 4},{ggggg, 1, 0, 5+ath, 4},
																								{ggggg,-1, 0, 6+ith, 3},{gaagg, 0, 0, 4+ith, 3},{ggggg, 1, 0, 6+ith, 3},{ggggg, 2, 0, 5+ath, 3},
																		{ggggg,-2, 0, 6+ith, 2},{ggggg,-1, 0, 6+ith, 2},{saaag, 0, 0, 5+ith, 2},{gaagg, 1, 0, 4+ith, 2},{ggggg, 2, 0, 6+ith, 2},{ggggg, 3, 0, 5+ath, 2},
						{ggggg,-4, 0, 5+ath, 1},{ggggg,-3, 0, 6+ith, 1},{ggggg,-2, 0, 6+ith, 1},{baaag,-1, 0, 5+ith, 1},{saaag, 0, 0, 5+ith, 1},{saaag, 1, 0, 5+ith, 1},{gaagg, 2, 0, 4+ith, 1},{ggggg, 3, 0, 5+ath, 1},
						{ggggg,-4, 0, 5+ath, 0},{gaagg,-3, 0, 4+ith, 0},{saaag,-2, 0, 5+ith, 0},{saaag,-1, 0, 5+ith, 0},{baaag, 0, 0, 5+ith, 0},{ggggg, 1, 0, 6+ith, 0},{ggggg, 2, 0, 6+ith, 0},{ggggg, 3, 0, 5+ath, 0},
						{ggggg,-4, 0, 5+ath,-1},{ggggg,-3, 0, 6+ith,-1},{gaagg,-2, 0, 4+ith,-1},{saaag,-1, 0, 5+ith,-1},{ggggg, 0, 0, 6+ith,-1},{ggggg, 1, 0, 6+ith,-1},
												{ggggg,-3, 0, 5+ath,-2},{ggggg,-2, 0, 6+ith,-2},{gaagg,-1, 0, 4+ith,-2},{ggggg, 0, 0, 6+ith,-2},
																		{ggggg,-2, 0, 5+ath,-3},{ggggg,-1, 0, 5+ath,-3},{ggggg, 0, 0, 5+ath,-3},
						}, user, pointed_thing)

		elseif cdir == 3 then  -- pointed west-northwest
			run_list(  {{ggggg,-3, 0, 5+ath, 4},{ggggg,-2, 0, 5+ath, 4},{ggggg,-1, 0, 5+ath, 4},{ggggg, 0, 0, 5+ath, 4},
						{ggggg,-3, 0, 6+ith, 3},{gaagg,-2, 0, 4+ith, 3},{gaagg,-1, 0, 4+ith, 3},{ggggg, 0, 0, 6+ith, 3},{ggggg, 1, 0, 5+ath, 3},
						{ggggg,-3, 0, 6+ith, 2},{saaag,-2, 0, 5+ith, 2},{saaag,-1, 0, 5+ith, 2},{gaagg, 0, 0, 4+ith, 2},{ggggg, 1, 0, 6+ith, 2},
						{ggggg,-3, 0, 6+ith, 1},{baaag,-2, 0, 5+ith, 1},{saaag,-1, 0, 5+ith, 1},{saaag, 0, 0, 5+ith, 1},{ggggg, 1, 0, 6+ith, 1},
						{ggggg,-3, 0, 6+ith, 0},{saaag,-2, 0, 5+ith, 0},{saaag,-1, 0, 5+ith, 0},{baaag, 0, 0, 5+ith, 0},{ggggg, 1, 0, 6+ith, 0},
						{ggggg,-3, 0, 6+ith,-1},{gaagg,-2, 0, 4+ith,-1},{saaag,-1, 0, 5+ith,-1},{saaag, 0, 0, 5+ith,-1},{ggggg, 1, 0, 6+ith,-1},
						{ggggg,-3, 0, 5+ath,-2},{ggggg,-2, 0, 6+ith,-2},{gaagg,-1, 0, 4+ith,-2},{gaagg, 0, 0, 4+ith,-2},{ggggg, 1, 0, 6+ith,-2},
												{ggggg,-2, 0, 5+ath,-3},{ggggg,-1, 0, 5+ath,-3},{ggggg, 0, 0, 5+ath,-3},{ggggg, 1, 0, 5+ath,-3},
						}, user, pointed_thing)

						 
		elseif cdir == 4 then  -- pointed west
			run_list(  {{ggggg,-3, 0, 5+ath, 3},{ggggg,-2, 0, 5+ath, 3},{ggggg,-1, 0, 5+ath, 3},{ggggg, 0, 0, 5+ath, 3},{ggggg, 1, 0, 5+ath, 3},
						{ggggg,-3, 0, 6+ith, 2},{gaagg,-2, 0, 4+ith, 2},{gaagg,-1, 0, 4+ith, 2},{gaagg, 0, 0, 4+ith, 2},{ggggg, 1, 0, 6+ith, 2},
						{ggggg,-3, 0, 6+ith, 1},{saaag,-2, 0, 5+ith, 1},{saaag,-1, 0, 5+ith, 1},{saaag, 0, 0, 5+ith, 1},{ggggg, 1, 0, 6+ith, 1},
						{ggggg,-3, 0, 6+ith, 0},{baaag,-2, 0, 5+ith, 0},{saaag,-1, 0, 5+ith, 0},{baaag, 0, 0, 5+ith, 0},{ggggg, 1, 0, 6+ith, 0},
						{ggggg,-3, 0, 6+ith,-1},{saaag,-2, 0, 5+ith,-1},{saaag,-1, 0, 5+ith,-1},{saaag, 0, 0, 5+ith,-1},{ggggg, 1, 0, 6+ith,-1},
						{ggggg,-3, 0, 6+ith,-2},{gaagg,-2, 0, 4+ith,-2},{gaagg,-1, 0, 4+ith,-2},{gaagg, 0, 0, 4+ith,-2},{ggggg, 1, 0, 6+ith,-2},
						{ggggg,-3, 0, 5+ath,-3},{ggggg,-2, 0, 5+ath,-3},{ggggg,-1, 0, 5+ath,-3},{ggggg, 0, 0, 5+ath,-3},{ggggg, 1, 0, 5+ath,-3},
						}, user, pointed_thing)

		elseif cdir == 5 then  -- pointed west-southwest
			run_list(  {						{ggggg,-2, 0, 5+ath, 3},{ggggg,-1, 0, 5+ath, 3},{ggggg, 0, 0, 5+ath, 3},{ggggg, 1, 0, 5+ath, 3},
						{ggggg,-3, 0, 5+ath, 2},{ggggg,-2, 0, 6+ith, 2},{gaagg,-1, 0, 4+ith, 2},{gaagg, 0, 0, 4+ith, 2},{ggggg, 1, 0, 6+ith, 2},
						{ggggg,-3, 0, 6+ith, 1},{gaagg,-2, 0, 4+ith, 1},{saaag,-1, 0, 5+ith, 1},{saaag, 0, 0, 5+ith, 1},{ggggg, 1, 0, 6+ith, 1},
						{ggggg,-3, 0, 6+ith, 0},{saaag,-2, 0, 5+ith, 0},{saaag,-1, 0, 5+ith, 0},{baaag, 0, 0, 5+ith, 0},{ggggg, 1, 0, 6+ith, 0},
						{ggggg,-3, 0, 6+ith,-1},{baaag,-2, 0, 5+ith,-1},{saaag,-1, 0, 5+ith,-1},{saaag, 0, 0, 5+ith,-1},{ggggg, 1, 0, 6+ith,-1},
						{ggggg,-3, 0, 6+ith,-2},{saaag,-2, 0, 5+ith,-2},{saaag,-1, 0, 5+ith,-2},{gaagg, 0, 0, 4+ith,-2},{ggggg, 1, 0, 6+ith,-2},
						{ggggg,-3, 0, 6+ith,-3},{gaagg,-2, 0, 4+ith,-3},{gaagg,-1, 0, 4+ith,-3},{ggggg, 0, 0, 6+ith,-3},{ggggg, 1, 0, 5+ath,-3},
						{ggggg,-3, 0, 5+ath,-4},{ggggg,-2, 0, 5+ath,-4},{ggggg,-1, 0, 5+ath,-4},{ggggg, 0, 0, 5+ath,-4},
						}, user, pointed_thing)

		elseif cdir == 6 then  -- pointed southwest
			run_list(  {												{ggggg,-2, 0, 5+ath, 3},{ggggg,-1, 0, 5+ath, 3},{ggggg, 0, 0, 5+ath, 3},
												{ggggg,-3, 0, 5+ath, 2},{ggggg,-2, 0, 6+ith, 2},{gaagg,-1, 0, 4+ith, 2},{ggggg, 0, 0, 6+ith, 2},
						{ggggg,-4, 0, 5+ath, 1},{ggggg,-3, 0, 6+ith, 1},{gaagg,-2, 0, 4+ith, 1},{saaag,-1, 0, 5+ith, 1},{ggggg, 0, 0, 6+ith, 1},{ggggg, 1, 0, 6+ith, 1},
						{ggggg,-4, 0, 5+ath, 0},{gaagg,-3, 0, 4+ith, 0},{saaag,-2, 0, 5+ith, 0},{saaag,-1, 0, 5+ith, 0},{baaag, 0, 0, 5+ith, 0},{ggggg, 1, 0, 6+ith, 0},{ggggg, 2, 0, 6+ith, 0},{ggggg, 3, 0, 5+ath, 0},
						{ggggg,-4, 0, 5+ath,-1},{ggggg,-3, 0, 6+ith,-1},{ggggg,-2, 0, 6+ith,-1},{baaag,-1, 0, 5+ith,-1},{saaag, 0, 0, 5+ith,-1},{saaag, 1, 0, 5+ith,-1},{gaagg, 2, 0, 4+ith,-1},{ggggg, 3, 0, 5+ath,-1},
																		{ggggg,-2, 0, 6+ith,-2},{ggggg,-1, 0, 6+ith,-2},{saaag, 0, 0, 5+ith,-2},{gaagg, 1, 0, 4+ith,-2},{ggggg, 2, 0, 6+ith,-2},{ggggg, 3, 0, 5+ath,-2},
																								{ggggg,-1, 0, 6+ith,-3},{gaagg, 0, 0, 4+ith,-3},{ggggg, 1, 0, 6+ith,-3},{ggggg, 2, 0, 5+ath,-3},
																								{ggggg,-1, 0, 5+ath,-4},{ggggg, 0, 0, 5+ath,-4},{ggggg, 1, 0, 5+ath,-4},
						}, user, pointed_thing)

		elseif cdir == 7 then  -- pointed south-southwest
			run_list(  {						{ggggg,-3, 0, 5+ath, 1},{ggggg,-2, 0, 6+ith, 1},{ggggg,-1, 0, 6+ith, 1},{ggggg, 0, 0, 6+ith, 1},{ggggg, 1, 0, 6+ith, 1},{ggggg, 2, 0, 6+ith, 1},{ggggg, 3, 0, 5+ath, 1},
						{ggggg,-4, 0, 5+ath, 0},{ggggg,-3, 0, 6+ith, 0},{gaagg,-2, 0, 4+ith, 0},{saaag,-1, 0, 5+ith, 0},{baaag, 0, 0, 5+ith, 0},{saaag, 1, 0, 5+ith, 0},{gaagg, 2, 0, 4+ith, 0},{ggggg, 3, 0, 5+ath, 0},
						{ggggg,-4, 0, 5+ath,-1},{gaagg,-3, 0, 4+ith,-1},{saaag,-2, 0, 5+ith,-1},{saaag,-1, 0, 5+ith,-1},{saaag, 0, 0, 5+ith,-1},{saaag, 1, 0, 5+ith,-1},{gaagg, 2, 0, 4+ith,-1},{ggggg, 3, 0, 5+ath,-1},
						{ggggg,-4, 0, 5+ath,-2},{gaagg,-3, 0, 4+ith,-2},{saaag,-2, 0, 5+ith,-2},{baaag,-1, 0, 5+ith,-2},{saaag, 0, 0, 5+ith,-2},{gaagg, 1, 0, 4+ith,-2},{ggggg, 2, 0, 6+ith,-2},{ggggg, 3, 0, 5+ath,-2},
						{ggggg,-4, 0, 5+ath,-3},{ggggg,-3, 0, 6+ith,-3},{ggggg,-2, 0, 6+ith,-3},{ggggg,-1, 0, 6+ith,-3},{ggggg, 0, 0, 6+ith,-3},{ggggg, 1, 0, 6+ith,-3},{ggggg, 2, 0, 5+ath,-3},
						}, user, pointed_thing)

		elseif cdir == 8 then  -- pointed south
			run_list(  {{ggggg,-3, 0, 5+ath, 1},{ggggg,-2, 0, 6+ith, 1},{ggggg,-1, 0, 6+ith, 1},{ggggg, 0, 0, 6+ith, 1},{ggggg, 1, 0, 6+ith, 1},{ggggg, 2, 0, 6+ith, 1},{ggggg, 3, 0, 5+ath, 1},
						{ggggg,-3, 0, 5+ath, 0},{gaagg,-2, 0, 4+ith, 0},{saaag,-1, 0, 5+ith, 0},{baaag, 0, 0, 5+ith, 0},{saaag, 1, 0, 5+ith, 0},{gaagg, 2, 0, 4+ith, 0},{ggggg, 3, 0, 5+ath, 0},
						{ggggg,-3, 0, 5+ath,-1},{gaagg,-2, 0, 4+ith,-1},{saaag,-1, 0, 5+ith,-1},{saaag, 0, 0, 5+ith,-1},{saaag, 1, 0, 5+ith,-1},{gaagg, 2, 0, 4+ith,-1},{ggggg, 3, 0, 5+ath,-1},
						{ggggg,-3, 0, 5+ath,-2},{gaagg,-2, 0, 4+ith,-2},{saaag,-1, 0, 5+ith,-2},{baaag, 0, 0, 5+ith,-2},{saaag, 1, 0, 5+ith,-2},{gaagg, 2, 0, 4+ith,-2},{ggggg, 3, 0, 5+ath,-2},
						{ggggg,-3, 0, 5+ath,-3},{ggggg,-2, 0, 6+ith,-3},{ggggg,-1, 0, 6+ith,-3},{ggggg, 0, 0, 6+ith,-3},{ggggg, 1, 0, 6+ith,-3},{ggggg, 2, 0, 6+ith,-3},{ggggg, 3, 0, 5+ath,-3},
						}, user, pointed_thing)

		elseif cdir == 9 then  -- pointed south-southeast
			run_list(  {{ggggg,-3, 0, 5+ath, 1},{ggggg,-2, 0, 6+ith, 1},{ggggg,-1, 0, 6+ith, 1},{ggggg, 0, 0, 6+ith, 1},{ggggg, 1, 0, 6+ith, 1},{ggggg, 2, 0, 6+ith, 1},{ggggg, 3, 0, 5+ath, 1},
						{ggggg,-3, 0, 5+ath, 0},{gaagg,-2, 0, 4+ith, 0},{saaag,-1, 0, 5+ith, 0},{baaag, 0, 0, 5+ith, 0},{saaag, 1, 0, 5+ith, 0},{gaagg, 2, 0, 4+ith, 0},{ggggg, 3, 0, 6+ith, 0},{ggggg, 4, 0, 5+ath, 0},
						{ggggg,-3, 0, 5+ath,-1},{gaagg,-2, 0, 4+ith,-1},{saaag,-1, 0, 5+ith,-1},{saaag, 0, 0, 5+ith,-1},{saaag, 1, 0, 5+ith,-1},{saaag, 2, 0, 5+ith,-1},{gaagg, 3, 0, 4+ith,-1},{ggggg, 4, 0, 5+ath,-1},
						{ggggg,-3, 0, 5+ath,-2},{ggggg,-2, 0, 6+ith,-2},{gaagg,-1, 0, 4+ith,-2},{saaag, 0, 0, 5+ith,-2},{baaag, 1, 0, 5+ith,-2},{saaag, 2, 0, 5+ith,-2},{gaagg, 3, 0, 4+ith,-2},{ggggg, 4, 0, 5+ath,-2},
												{ggggg,-2, 0, 5+ath,-3},{ggggg,-1, 0, 6+ith,-3},{ggggg, 0, 0, 6+ith,-3},{ggggg, 1, 0, 6+ith,-3},{ggggg, 2, 0, 6+ith,-3},{ggggg, 3, 0, 6+ith,-3},{ggggg, 4, 0, 5+ath,-3},
						}, user, pointed_thing)

		elseif cdir == 10 then  -- pointed southeast
			run_list(  {																		{ggggg, 0, 0, 5+ath, 3},{ggggg, 1, 0, 5+ath, 3},{ggggg, 2, 0, 5+ath, 3},
																								{ggggg, 0, 0, 6+ith, 2},{gaagg, 1, 0, 4+ith, 2},{ggggg, 2, 0, 6+ith, 2},{ggggg, 3, 0, 5+ath, 2},
																		{ggggg,-1, 0, 6+ith, 1},{ggggg, 0, 0, 6+ith, 1},{saaag, 1, 0, 5+ith, 1},{gaagg, 2, 0, 4+ith, 1},{ggggg, 3, 0, 6+ith, 1},{ggggg, 4, 0, 5+ath, 1},
						{ggggg,-3, 0, 5+ath, 0},{ggggg,-2, 0, 6+ith, 0},{ggggg,-1, 0, 6+ith, 0},{baaag, 0, 0, 5+ith, 0},{saaag, 1, 0, 5+ith, 0},{saaag, 2, 0, 5+ith, 0},{gaagg, 3, 0, 4+ith, 0},{ggggg, 4, 0, 5+ath, 0},
						{ggggg,-3, 0, 5+ath,-1},{gaagg,-2, 0, 4+ith,-1},{saaag,-1, 0, 5+ith,-1},{saaag, 0, 0, 5+ith,-1},{baaag, 1, 0, 5+ith,-1},{ggggg, 2, 0, 6+ith,-1},{ggggg, 3, 0, 6+ith,-1},{ggggg, 4, 0, 5+ath,-1},
						{ggggg,-3, 0, 5+ath,-2},{ggggg,-2, 0, 6+ith,-2},{gaagg,-1, 0, 4+ith,-2},{saaag, 0, 0, 5+ith,-2},{ggggg, 1, 0, 6+ith,-2},{ggggg, 2, 0, 6+ith,-2},
												{ggggg,-2, 0, 5+ath,-3},{ggggg,-1, 0, 6+ith,-3},{gaagg, 0, 0, 4+ith,-3},{ggggg, 1, 0, 6+ith,-3},
																		{ggggg,-1, 0, 5+ath,-4},{ggggg, 0, 0, 5+ath,-4},{ggggg, 1, 0, 5+ath,-4},
						}, user, pointed_thing)

		elseif cdir == 11 then  -- pointed east-southeast
			run_list(  {{ggggg,-1, 0, 5+ath, 3},{ggggg, 0, 0, 5+ath, 3},{ggggg, 1, 0, 5+ath, 3},{ggggg, 2, 0, 5+ath, 3},
						{ggggg,-1, 0, 6+ith, 2},{gaagg, 0, 0, 4+ith, 2},{gaagg, 1, 0, 4+ith, 2},{ggggg, 2, 0, 6+ith, 2},{ggggg, 3, 0, 5+ath, 2},
						{ggggg,-1, 0, 6+ith, 1},{saaag, 0, 0, 5+ith, 1},{saaag, 1, 0, 5+ith, 1},{gaagg, 2, 0, 4+ith, 1},{ggggg, 3, 0, 6+ith, 1},
						{ggggg,-1, 0, 6+ith, 0},{baaag, 0, 0, 5+ith, 0},{saaag, 1, 0, 5+ith, 0},{saaag, 2, 0, 5+ith, 0},{ggggg, 3, 0, 6+ith, 0},
						{ggggg,-1, 0, 6+ith,-1},{saaag, 0, 0, 5+ith,-1},{saaag, 1, 0, 5+ith,-1},{baaag, 2, 0, 5+ith,-1},{ggggg, 3, 0, 6+ith,-1},
						{ggggg,-1, 0, 6+ith,-2},{gaagg, 0, 0, 4+ith,-2},{saaag, 1, 0, 5+ith,-2},{saaag, 2, 0, 5+ith,-2},{ggggg, 3, 0, 6+ith,-2},
						{ggggg,-1, 0, 5+ath,-3},{ggggg, 0, 0, 6+ith,-3},{gaagg, 1, 0, 4+ith,-3},{gaagg, 2, 0, 4+ith,-3},{ggggg, 3, 0, 6+ith,-3},
												{ggggg, 0, 0, 5+ath,-4},{ggggg, 1, 0, 5+ath,-4},{ggggg, 2, 0, 5+ath,-4},{ggggg, 3, 0, 5+ath,-4},
						}, user, pointed_thing)

						 elseif cdir == 12 then  -- pointed east
			run_list(  {{ggggg,-1, 0, 5+ath, 3},{ggggg, 0, 0, 5+ath, 3},{ggggg, 1, 0, 5+ath, 3},{ggggg, 2, 0, 5+ath, 3},{ggggg, 3, 0, 5+ath, 3},
						{ggggg,-1, 0, 6+ith, 2},{gaagg, 0, 0, 4+ith, 2},{gaagg, 1, 0, 4+ith, 2},{gaagg, 2, 0, 4+ith, 2},{ggggg, 3, 0, 6+ith, 2},
						{ggggg,-1, 0, 6+ith, 1},{saaag, 0, 0, 5+ith, 1},{saaag, 1, 0, 5+ith, 1},{saaag, 2, 0, 5+ith, 1},{ggggg, 3, 0, 6+ith, 1},
						{ggggg,-1, 0, 6+ith, 0},{baaag, 0, 0, 5+ith, 0},{saaag, 1, 0, 5+ith, 0},{baaag, 2, 0, 5+ith, 0},{ggggg, 3, 0, 6+ith, 0},
						{ggggg,-1, 0, 6+ith,-1},{saaag, 0, 0, 5+ith,-1},{saaag, 1, 0, 5+ith,-1},{saaag, 2, 0, 5+ith,-1},{ggggg, 3, 0, 6+ith,-1},
						{ggggg,-1, 0, 6+ith,-2},{gaagg, 0, 0, 4+ith,-2},{gaagg, 1, 0, 4+ith,-2},{gaagg, 2, 0, 4+ith,-2},{ggggg, 3, 0, 6+ith,-2},
						{ggggg,-1, 0, 5+ath,-3},{ggggg, 0, 0, 5+ath,-3},{ggggg, 1, 0, 5+ath,-3},{ggggg, 2, 0, 5+ath,-3},{ggggg, 3, 0, 5+ath,-3},
						}, user, pointed_thing)

		elseif cdir == 13 then  -- pointed east-northeast
			run_list(  {						{ggggg, 0, 0, 5+ath, 4},{ggggg, 1, 0, 5+ath, 4},{ggggg, 2, 0, 5+ath, 4},{ggggg, 3, 0, 5+ath, 4},
						{ggggg,-1, 0, 5+ath, 3},{ggggg, 0, 0, 6+ith, 3},{gaagg, 1, 0, 4+ith, 3},{gaagg, 2, 0, 4+ith, 3},{ggggg, 3, 0, 6+ith, 3},
						{ggggg,-1, 0, 6+ith, 2},{gaagg, 0, 0, 4+ith, 2},{saaag, 1, 0, 5+ith, 2},{saaag, 2, 0, 5+ith, 2},{ggggg, 3, 0, 6+ith, 2},
						{ggggg,-1, 0, 6+ith, 1},{saaag, 0, 0, 5+ith, 1},{saaag, 1, 0, 5+ith, 1},{baaag, 2, 0, 5+ith, 1},{ggggg, 3, 0, 6+ith, 1},
						{ggggg,-1, 0, 6+ith, 0},{baaag, 0, 0, 5+ith, 0},{saaag, 1, 0, 5+ith, 0},{saaag, 2, 0, 5+ith, 0},{ggggg, 3, 0, 6+ith, 0},
						{ggggg,-1, 0, 6+ith,-1},{saaag, 0, 0, 5+ith,-1},{saaag, 1, 0, 5+ith,-1},{gaagg, 2, 0, 4+ith,-1},{ggggg, 3, 0, 6+ith,-1},
						{ggggg,-1, 0, 6+ith,-2},{gaagg, 0, 0, 4+ith,-2},{gaagg, 1, 0, 4+ith,-2},{ggggg, 2, 0, 6+ith,-2},{ggggg, 3, 0, 5+ath,-2},
						{ggggg,-1, 0, 5+ath,-3},{ggggg, 0, 0, 5+ath,-3},{ggggg, 1, 0, 5+ath,-3},{ggggg, 2, 0, 5+ath,-3},
						}, user, pointed_thing)

		elseif cdir == 14 then  -- pointed northeast
			run_list(  {												{ggggg,-1, 0, 5+ath, 4},{ggggg, 0, 0, 5+ath, 4},{ggggg, 1, 0, 5+ath, 4},
												{ggggg,-2, 0, 5+ath, 3},{ggggg,-1, 0, 6+ith, 3},{gaagg, 0, 0, 4+ith, 3},{ggggg, 1, 0, 6+ith, 3},
						{ggggg,-3, 0, 5+ath, 2},{ggggg,-2, 0, 6+ith, 2},{gaagg,-1, 0, 4+ith, 2},{saaag, 0, 0, 5+ith, 2},{ggggg, 1, 0, 6+ith, 2},{ggggg, 2, 0, 6+ith, 2},
						{ggggg,-3, 0, 5+ath, 1},{gaagg,-2, 0, 4+ith, 1},{saaag,-1, 0, 5+ith, 1},{saaag, 0, 0, 5+ith, 1},{baaag, 1, 0, 5+ith, 1},{ggggg, 2, 0, 6+ith, 1},{ggggg, 3, 0, 6+ith, 1},{ggggg, 4, 0, 5+ath, 1},
						{ggggg,-3, 0, 5+ath, 0},{ggggg,-2, 0, 6+ith, 0},{ggggg,-1, 0, 6+ith, 0},{baaag, 0, 0, 5+ith, 0},{saaag, 1, 0, 5+ith, 0},{saaag, 2, 0, 5+ith, 0},{gaagg, 3, 0, 4+ith, 0},{ggggg, 4, 0, 5+ath, 0},
																		{ggggg,-1, 0, 6+ith,-1},{ggggg, 0, 0, 6+ith,-1},{saaag, 1, 0, 5+ith,-1},{gaagg, 2, 0, 4+ith,-1},{ggggg, 3, 0, 6+ith,-1},{ggggg, 4, 0, 5+ath,-1},
																								{ggggg, 0, 0, 6+ith,-2},{gaagg, 1, 0, 4+ith,-2},{ggggg, 2, 0, 6+ith,-2},{ggggg, 3, 0, 5+ath,-2},
																								{ggggg, 0, 0, 5+ath,-3},{ggggg, 1, 0, 5+ath,-3},{ggggg, 2, 0, 5+ath,-3},
						}, user, pointed_thing)

		elseif cdir == 15 then  -- pointed north-northeast
			run_list(  {						{ggggg,-2, 0, 5+ath, 3},{ggggg,-1, 0, 6+ith, 3},{ggggg, 0, 0, 6+ith, 3},{ggggg, 1, 0, 6+ith, 3},{ggggg, 2, 0, 6+ith, 3},{ggggg, 3, 0, 6+ith, 3},{ggggg, 4, 0, 5+ath, 3},
						{ggggg,-3, 0, 5+ath, 2},{ggggg,-2, 0, 6+ith, 2},{gaagg,-1, 0, 4+ith, 2},{saaag, 0, 0, 5+ith, 2},{baaag, 1, 0, 5+ith, 2},{saaag, 2, 0, 5+ith, 2},{gaagg, 3, 0, 4+ith, 2},{ggggg, 4, 0, 5+ath, 2},
						{ggggg,-3, 0, 5+ath, 1},{gaagg,-2, 0, 4+ith, 1},{saaag,-1, 0, 5+ith, 1},{saaag, 0, 0, 5+ith, 1},{saaag, 1, 0, 5+ith, 1},{saaag, 2, 0, 5+ith, 1},{gaagg, 3, 0, 4+ith, 1},{ggggg, 4, 0, 5+ath, 1},
						{ggggg,-3, 0, 5+ath, 0},{gaagg,-2, 0, 4+ith, 0},{saaag,-1, 0, 5+ith, 0},{baaag, 0, 0, 5+ith, 0},{saaag, 1, 0, 5+ith, 0},{gaagg, 2, 0, 4+ith, 0},{ggggg, 3, 0, 6+ith, 0},{ggggg, 4, 0, 5+ath, 0},
						{ggggg,-3, 0, 5+ath,-1},{ggggg,-2, 0, 6+ith,-1},{ggggg,-1, 0, 6+ith,-1},{ggggg, 0, 0, 6+ith,-1},{ggggg, 1, 0, 6+ith,-1},{ggggg, 2, 0, 6+ith,-1},{ggggg, 3, 0, 5+ath,-1},
						}, user, pointed_thing)

-- ââåðõ
		elseif cdir == 16 then  -- pointed north (0, dig up)
			run_list(  {{ggggg,-3, 1, 6+ath, 3},{ggggg,-2, 1, 7+ith, 3},{ggggg,-1, 1, 7+ith, 3},{ggggg, 0, 1, 7+ith, 3},{ggggg, 1, 1, 7+ith, 3},{ggggg, 2, 1, 7+ith, 3},{ggggg, 3, 1, 6+ath, 3},
						{ggggg,-3, 0, 6+ath, 2},{ggagg,-2, 1, 5+ith, 2},{ssaag,-1, 1, 6+ith, 2},{sbaag, 0, 1, 6+ith, 2},{ssaag, 1, 1, 6+ith, 2},{ggagg, 2, 1, 5+ith, 2},{ggggg, 3, 0, 6+ath, 2},
						{ggggg,-3, 0, 6+ath, 1},{gaagg,-2, 0, 5+ith, 1},{saaag,-1, 0, 6+ith, 1},{saaag, 0, 0, 6+ith, 1},{saaag, 1, 0, 6+ith, 1},{gaagg, 2, 0, 5+ith, 1},{ggggg, 3, 0, 6+ath, 1},
						{ggggg,-3, 0, 6+ath, 0},{gaggg,-2, 0, 4+ith, 0},{saagg,-1, 0, 5+ith, 0},{baagg, 0, 0, 5+ith, 0},{saagg, 1, 0, 5+ith, 0},{gaggg, 2, 0, 4+ith, 0},{ggggg, 3, 0, 6+ath, 0},
						{ggggg,-3, 0, 5+ath,-1},{ggggg,-2, 0, 6+ith,-1},{ggggg,-1, 0, 6+ith,-1},{ggggg, 0, 0, 6+ith,-1},{ggggg, 1, 0, 6+ith,-1},{ggggg, 2, 0, 6+ith,-1},{ggggg, 3, 0, 5+ath,-1},
						}, user, pointed_thing)

		elseif cdir == 17 then  -- pointed northwest (2, dig up)
			run_list(  {																		{ggggg,-1, 1, 6+ath, 4},{ggggg, 0, 1, 6+ath, 4},{ggggg, 1, 1, 6+ath, 4},
																								{ggggg,-1, 1, 7+ith, 3},{ggagg, 0, 1, 5+ith, 3},{ggggg, 1, 0, 7+ith, 3},{ggggg, 2, 0, 6+ath, 3},
																		{ggggg,-2, 1, 7+ith, 2},{ggggg,-1, 1, 7+ith, 2},{ssaag, 0, 1, 6+ith, 2},{gaagg, 1, 0, 5+ith, 2},{ggggg, 2, 0, 6+ath, 2},{ggggg, 3, 0, 5+ath, 2},
						{ggggg,-4, 1, 6+ath, 1},{ggggg,-3, 1, 7+ith, 1},{ggggg,-2, 1, 7+ith, 1},{sbaag,-1, 1, 6+ith, 1},{saaag, 0, 0, 6+ith, 1},{saagg, 1, 0, 5+ith, 1},{gaxgx, 2, 0, 4+ith, 1},{ggggg, 3, 0, 5+ath, 1},
						{ggggg,-4, 1, 6+ath, 0},{ggagg,-3, 1, 5+ith, 0},{ssaag,-2, 1, 6+ith, 0},{saaag,-1, 0, 6+ith, 0},{baagg, 0, 0, 5+ith, 0},{ggggg, 1, 0, 7+ith, 0},{ggggg, 2, 0, 6+ith, 0},{ggggg, 3, 0, 5+ath, 0},
						{ggggg,-4, 1, 6+ath,-1},{ggggg,-3, 0, 7+ith,-1},{gaagg,-2, 0, 5+ith,-1},{saagg,-1, 0, 5+ith,-1},{ggggg, 0, 0, 7+ith,-1},{ggggg, 1, 0, 6+ith,-1},
												{ggggg,-3, 0, 6+ath,-2},{ggggg,-2, 0, 6+ath,-2},{gaxgx,-1, 0, 4+ith,-2},{ggggg, 0, 0, 6+ith,-2},
																		{ggggg,-2, 0, 5+ath,-3},{ggggg,-1, 0, 5+ath,-3},{ggggg, 0, 0, 5+ath,-3},
						}, user, pointed_thing)

		elseif cdir == 18 then  -- pointed west (4, dig up)
			run_list(  {{ggggg,-3, 1, 6+ath, 3},{ggggg,-2, 0, 6+ath, 3},{ggggg,-1, 0, 6+ath, 3},{ggggg, 0, 0, 6+ath, 3},{ggggg, 1, 0, 5+ath, 3},
						{ggggg,-3, 1, 7+ith, 2},{ggagg,-2, 1, 5+ith, 2},{gaagg,-1, 0, 5+ith, 2},{gaggg, 0, 0, 4+ith, 2},{ggggg, 1, 0, 6+ith, 2},
						{ggggg,-3, 1, 7+ith, 1},{ssaag,-2, 1, 6+ith, 1},{saaag,-1, 0, 6+ith, 1},{saagg, 0, 0, 5+ith, 1},{ggggg, 1, 0, 6+ith, 1},
						{ggggg,-3, 1, 7+ith, 0},{sbaag,-2, 1, 6+ith, 0},{saaag,-1, 0, 6+ith, 0},{baagg, 0, 0, 5+ith, 0},{ggggg, 1, 0, 6+ith, 0},
						{ggggg,-3, 1, 7+ith,-1},{ssaag,-2, 1, 6+ith,-1},{saaag,-1, 0, 6+ith,-1},{saagg, 0, 0, 5+ith,-1},{ggggg, 1, 0, 6+ith,-1},
						{ggggg,-3, 1, 7+ith,-2},{ggagg,-2, 1, 5+ith,-2},{gaagg,-1, 0, 5+ith,-2},{gaggg, 0, 0, 4+ith,-2},{ggggg, 1, 0, 6+ith,-2},
						{ggggg,-3, 1, 6+ath,-3},{ggggg,-2, 0, 6+ath,-3},{ggggg,-1, 0, 6+ath,-3},{ggggg, 0, 0, 6+ath,-3},{ggggg, 1, 0, 5+ath,-3},
						}, user, pointed_thing)

		elseif cdir == 19 then  -- pointed southwest (6, dig up)
			run_list(  {												{ggggg,-2, 0, 5+ath, 3},{ggggg,-1, 0, 5+ath, 3},{ggggg, 0, 0, 5+ath, 3},
												{ggggg,-3, 0, 6+ath, 2},{ggggg,-2, 0, 6+ath, 2},{gaxgx,-1, 0, 4+ith, 2},{ggggg, 0, 0, 6+ith, 2},
						{ggggg,-4, 1, 6+ath, 1},{ggggg,-3, 0, 7+ith, 1},{gaagg,-2, 0, 5+ith, 1},{saagg,-1, 0, 5+ith, 1},{ggggg, 0, 0, 7+ith, 1},{ggggg, 1, 0, 6+ith, 1},
						{ggggg,-4, 1, 6+ath, 0},{ggagg,-3, 1, 5+ith, 0},{ssaag,-2, 1, 6+ith, 0},{saaag,-1, 0, 6+ith, 0},{baagg, 0, 0, 5+ith, 0},{ggggg, 1, 0, 7+ith, 0},{ggggg, 2, 0, 6+ith, 0},{ggggg, 3, 0, 5+ath, 0},
						{ggggg,-4, 1, 6+ath,-1},{ggggg,-3, 1, 7+ith,-1},{ggggg,-2, 1, 7+ith,-1},{sbaag,-1, 1, 6+ith,-1},{saaag, 0, 0, 6+ith,-1},{saagg, 1, 0, 5+ith,-1},{gaxgx, 2, 0, 4+ith,-1},{ggggg, 3, 0, 5+ath,-1},
																		{ggggg,-2, 1, 7+ith,-2},{ggggg,-1, 1, 7+ith,-2},{ssaag, 0, 1, 6+ith,-2},{gaagg, 1, 0, 5+ith,-2},{ggggg, 2, 0, 6+ath,-2},{ggggg, 3, 0, 5+ath,-2},
																								{ggggg,-1, 1, 7+ith,-3},{ggagg, 0, 1, 5+ith,-3},{ggggg, 1, 0, 7+ith,-3},{ggggg, 2, 0, 6+ath,-3},
																								{ggggg,-1, 1, 6+ath,-4},{ggggg, 0, 1, 6+ath,-4},{ggggg, 1, 1, 6+ath,-4},
						}, user, pointed_thing)

		elseif cdir == 20 then  -- pointed south (8, dig up)
			run_list(  {{ggggg,-3, 0, 5+ath, 1},{ggggg,-2, 0, 6+ith, 1},{ggggg,-1, 0, 6+ith, 1},{ggggg, 0, 0, 6+ith, 1},{ggggg, 1, 0, 6+ith, 1},{ggggg, 2, 0, 6+ith, 1},{ggggg, 3, 0, 5+ath, 1},
						{ggggg,-3, 0, 6+ath, 0},{gaggg,-2, 0, 4+ith, 0},{saagg,-1, 0, 5+ith, 0},{baagg, 0, 0, 5+ith, 0},{saagg, 1, 0, 5+ith, 0},{gaggg, 2, 0, 4+ith, 0},{ggggg, 3, 0, 6+ath, 0},
						{ggggg,-3, 0, 6+ath,-1},{gaagg,-2, 0, 5+ith,-1},{saaag,-1, 0, 6+ith,-1},{saaag, 0, 0, 6+ith,-1},{saaag, 1, 0, 6+ith,-1},{gaagg, 2, 0, 5+ith,-1},{ggggg, 3, 0, 6+ath,-1},
						{ggggg,-3, 0, 6+ath,-2},{ggagg,-2, 1, 5+ith,-2},{ssaag,-1, 1, 6+ith,-2},{sbaag, 0, 1, 6+ith,-2},{ssaag, 1, 1, 6+ith,-2},{ggagg, 2, 1, 5+ith,-2},{ggggg, 3, 0, 6+ath,-2},
						{ggggg,-3, 1, 6+ath,-3},{ggggg,-2, 1, 7+ith,-3},{ggggg,-1, 1, 7+ith,-3},{ggggg, 0, 1, 7+ith,-3},{ggggg, 1, 1, 7+ith,-3},{ggggg, 2, 1, 7+ith,-3},{ggggg, 3, 1, 6+ath,-3},
						}, user, pointed_thing)

		elseif cdir == 21 then  -- pointed southeast (10, dig up)
			run_list(  {																		{ggggg, 0, 0, 5+ath, 3},{ggggg, 1, 0, 5+ath, 3},{ggggg, 2, 0, 5+ath, 3},
																								{ggggg, 0, 0, 6+ith, 2},{gaxgx, 1, 0, 4+ith, 2},{ggggg, 2, 0, 6+ath, 2},{ggggg, 3, 0, 6+ath, 2},
																		{ggggg,-1, 0, 6+ith, 1},{ggggg, 0, 0, 7+ith, 1},{saagg, 1, 0, 5+ith, 1},{gaagg, 2, 0, 5+ith, 1},{ggggg, 3, 0, 7+ith, 1},{ggggg, 4, 1, 6+ath, 1},
						{ggggg,-3, 0, 5+ath, 0},{ggggg,-2, 0, 6+ith, 0},{ggggg,-1, 0, 7+ith, 0},{baagg, 0, 0, 5+ith, 0},{saaag, 1, 0, 6+ith, 0},{ssaag, 2, 1, 6+ith, 0},{ggagg, 3, 1, 5+ith, 0},{ggggg, 4, 1, 6+ath, 0},
						{ggggg,-3, 0, 5+ath,-1},{gaxgx,-2, 0, 4+ith,-1},{saagg,-1, 0, 5+ith,-1},{saaag, 0, 0, 6+ith,-1},{sbaag, 1, 1, 6+ith,-1},{ggggg, 2, 1, 7+ith,-1},{ggggg, 3, 1, 7+ith,-1},{ggggg, 4, 1, 6+ath,-1},
						{ggggg,-3, 0, 5+ath,-2},{ggggg,-2, 0, 6+ath,-2},{gaagg,-1, 0, 5+ith,-2},{ssaag, 0, 1, 6+ith,-2},{ggggg, 1, 1, 7+ith,-2},{ggggg, 2, 1, 7+ith,-2},
												{ggggg,-2, 0, 6+ath,-3},{ggggg,-1, 0, 7+ith,-3},{ggagg, 0, 1, 5+ith,-3},{ggggg, 1, 1, 7+ith,-3},
																		{ggggg,-1, 1, 6+ath,-4},{ggggg, 0, 1, 6+ath,-4},{ggggg, 1, 1, 6+ath,-4},
						}, user, pointed_thing)

		elseif cdir == 22 then  -- pointed east (12, dig up)
			run_list(  {{ggggg,-1, 0, 5+ath, 3},{ggggg, 0, 0, 6+ath, 3},{ggggg, 1, 0, 6+ath, 3},{ggggg, 2, 0, 6+ath, 3},{ggggg, 3, 1, 6+ath, 3},
						{ggggg,-1, 0, 6+ith, 2},{gaggg, 0, 0, 4+ith, 2},{gaagg, 1, 0, 5+ith, 2},{ggagg, 2, 1, 5+ith, 2},{ggggg, 3, 1, 7+ith, 2},
						{ggggg,-1, 0, 6+ith, 1},{saagg, 0, 0, 5+ith, 1},{saaag, 1, 0, 6+ith, 1},{ssaag, 2, 1, 6+ith, 1},{ggggg, 3, 1, 7+ith, 1},
						{ggggg,-1, 0, 6+ith, 0},{baagg, 0, 0, 5+ith, 0},{saaag, 1, 0, 6+ith, 0},{sbaag, 2, 1, 6+ith, 0},{ggggg, 3, 1, 7+ith, 0},
						{ggggg,-1, 0, 6+ith,-1},{saagg, 0, 0, 5+ith,-1},{saaag, 1, 0, 6+ith,-1},{ssaag, 2, 1, 6+ith,-1},{ggggg, 3, 1, 7+ith,-1},
						{ggggg,-1, 0, 6+ith,-2},{gaggg, 0, 0, 4+ith,-2},{gaagg, 1, 0, 5+ith,-2},{ggagg, 2, 1, 5+ith,-2},{ggggg, 3, 1, 7+ith,-2},
						{ggggg,-1, 0, 5+ath,-3},{ggggg, 0, 0, 6+ath,-3},{ggggg, 1, 0, 6+ath,-3},{ggggg, 2, 0, 6+ath,-3},{ggggg, 3, 1, 6+ath,-3},
						}, user, pointed_thing)

		elseif cdir == 23 then  -- pointed northeast (14, dig up)
			run_list(  {												{ggggg,-1, 1, 6+ath, 4},{ggggg, 0, 1, 6+ath, 4},{ggggg, 1, 1, 6+ath, 4},
												{ggggg,-2, 0, 6+ath, 3},{ggggg,-1, 0, 7+ith, 3},{ggagg, 0, 1, 5+ith, 3},{ggggg, 1, 1, 7+ith, 3},
						{ggggg,-3, 0, 5+ath, 2},{ggggg,-2, 0, 6+ath, 2},{gaagg,-1, 0, 5+ith, 2},{ssaag, 0, 1, 6+ith, 2},{ggggg, 1, 1, 7+ith, 2},{ggggg, 2, 1, 7+ith, 2},
						{ggggg,-3, 0, 5+ath, 1},{gaxgx,-2, 0, 4+ith, 1},{saagg,-1, 0, 5+ith, 1},{saaag, 0, 0, 6+ith, 1},{sbaag, 1, 1, 6+ith, 1},{ggggg, 2, 1, 7+ith, 1},{ggggg, 3, 1, 7+ith, 1},{ggggg, 4, 1, 6+ath, 1},
						{ggggg,-3, 0, 5+ath, 0},{ggggg,-2, 0, 6+ith, 0},{ggggg,-1, 0, 7+ith, 0},{baagg, 0, 0, 5+ith, 0},{saaag, 1, 0, 6+ith, 0},{ssaag, 2, 1, 6+ith, 0},{ggagg, 3, 1, 5+ith, 0},{ggggg, 4, 1, 6+ath, 0},
																		{ggggg,-1, 0, 6+ith,-1},{ggggg, 0, 0, 7+ith,-1},{saagg, 1, 0, 5+ith,-1},{gaagg, 2, 0, 5+ith,-1},{ggggg, 3, 0, 7+ith,-1},{ggggg, 4, 1, 6+ath,-1},
																								{ggggg, 0, 0, 6+ith,-2},{gaxgx, 1, 0, 4+ith,-2},{ggggg, 2, 0, 6+ath,-2},{ggggg, 3, 0, 6+ath,-2},
																								{ggggg, 0, 0, 5+ath,-3},{ggggg, 1, 0, 5+ath,-3},{ggggg, 2, 0, 5+ath,-3},
						}, user, pointed_thing) 

-- âíèç
		elseif cdir == 24 then  -- pointed north (0, dig down)
			run_list(  {{ggggg,-3,-1, 4+ath, 3},{ggggg,-2,-1, 5+ith, 3},{ggggg,-1,-1, 5+ith, 3},{ggggg, 0,-1, 5+ith, 3},{ggggg, 1,-1, 5+ith, 3},{ggggg, 2,-1, 5+ith, 3},{ggggg, 3,-1, 4+ath, 3},
						{ggggg,-3,-1, 5+ath, 2},{gaggg,-2,-1, 3+ith, 2},{saagg,-1,-1, 4+ith, 2},{baagg, 0,-1, 4+ith, 2},{saagg, 1,-1, 4+ith, 2},{gaggg, 2,-1, 3+ith, 2},{ggggg, 3,-1, 5+ath, 2},
						{ggggg,-3,-1, 5+ath, 1},{gaagg,-2,-1, 4+ith, 1},{saaag,-1,-1, 5+ith, 1},{saaag, 0,-1, 5+ith, 1},{saaag, 1,-1, 5+ith, 1},{gaagg, 2,-1, 4+ith, 1},{ggggg, 3,-1, 5+ath, 1},
						{ggggg,-3,-1, 5+ath, 0},{ggagg,-2, 0, 4+ith, 0},{ssaag,-1, 0, 5+ith, 0},{sbaag, 0, 0, 5+ith, 0},{ssaag, 1, 0, 5+ith, 0},{ggagg, 2, 0, 4+ith, 0},{ggggg, 3,-1, 5+ath, 0},
						{ggggg,-3, 0, 5+ath,-1},{ggggg,-2, 0, 6+ith,-1},{ggggg,-1, 0, 6+ith,-1},{ggggg, 0, 0, 6+ith,-1},{ggggg, 1, 0, 6+ith,-1},{ggggg, 2, 0, 6+ith,-1},{ggggg, 3, 0, 5+ath,-1},
						}, user, pointed_thing)

		elseif cdir == 25 then  -- pointed northwest (2, dig down)
			run_list(  {																		{ggggg,-1,-1, 4+ath, 4},{ggggg, 0,-1, 4+ath, 4},{ggggg, 1,-1, 4+ath, 4},
																								{ggggg,-1,-1, 5+ith, 3},{gaxgx, 0,-1, 3+ith, 3},{ggggg, 1,-1, 5+ath, 3},{ggggg, 2,-1, 5+ath, 3},
																		{ggggg,-2,-1, 5+ith, 2},{ggggg,-1,-1, 6+ith, 2},{saagg, 0,-1, 4+ith, 2},{gaagg, 1,-1, 4+ith, 2},{ggggg, 2,-1, 6+ith, 2},{ggggg, 3, 0, 5+ath, 2},
						{ggggg,-4,-1, 4+ath, 1},{ggggg,-3,-1, 5+ith, 1},{ggggg,-2,-1, 6+ith, 1},{baagg,-1,-1, 4+ith, 1},{saaag, 0,-1, 5+ith, 1},{ssaag, 1, 0, 5+ith, 1},{ggagg, 2, 0, 4+ith, 1},{ggggg, 3, 0, 5+ath, 1},
						{ggggg,-4,-1, 4+ath, 0},{gaxgx,-3,-1, 3+ith, 0},{saagg,-2,-1, 4+ith, 0},{saaag,-1,-1, 5+ith, 0},{sbaag, 0, 0, 5+ith, 0},{ggggg, 1, 0, 6+ith, 0},{ggggg, 2, 0, 6+ith, 0},{ggggg, 3, 0, 5+ath, 0},
						{ggggg,-4,-1, 4+ath,-1},{ggggg,-3,-1, 5+ath,-1},{gaagg,-2,-1, 4+ith,-1},{ssaag,-1, 0, 5+ith,-1},{ggggg, 0, 0, 6+ith,-1},{ggggg, 1, 0, 6+ith,-1},
												{ggggg,-3,-1, 5+ath,-2},{ggggg,-2,-1, 6+ith,-2},{ggagg,-1, 0, 4+ith,-2},{ggggg, 0, 0, 6+ith,-2},
																		{ggggg,-2, 0, 5+ath,-3},{ggggg,-1, 0, 5+ath,-3},{ggggg, 0, 0, 5+ath,-3},
						}, user, pointed_thing)

		elseif cdir == 26 then  -- pointed west (4, dig down)
			run_list(  {{ggggg,-3,-1, 4+ath, 3},{ggggg,-2,-1, 5+ath, 3},{ggggg,-1,-1, 5+ath, 3},{ggggg, 0,-1, 5+ath, 3},{ggggg, 1, 0, 5+ath, 3},
						{ggggg,-3,-1, 5+ith, 2},{gaggg,-2,-1, 3+ith, 2},{gaagg,-1,-1, 4+ith, 2},{ggagg, 0, 0, 4+ith, 2},{ggggg, 1, 0, 6+ith, 2},
						{ggggg,-3,-1, 5+ith, 1},{saagg,-2,-1, 4+ith, 1},{saaag,-1,-1, 5+ith, 1},{ssaag, 0, 0, 5+ith, 1},{ggggg, 1, 0, 6+ith, 1},
						{ggggg,-3,-1, 5+ith, 0},{baagg,-2,-1, 4+ith, 0},{saaag,-1,-1, 5+ith, 0},{sbaag, 0, 0, 5+ith, 0},{ggggg, 1, 0, 6+ith, 0},
						{ggggg,-3,-1, 5+ith,-1},{saagg,-2,-1, 4+ith,-1},{saaag,-1,-1, 5+ith,-1},{ssaag, 0, 0, 5+ith,-1},{ggggg, 1, 0, 6+ith,-1},
						{ggggg,-3,-1, 5+ith,-2},{gaggg,-2,-1, 3+ith,-2},{gaagg,-1,-1, 4+ith,-2},{ggagg, 0, 0, 4+ith,-2},{ggggg, 1, 0, 6+ith,-2},
						{ggggg,-3,-1, 4+ath,-3},{ggggg,-2,-1, 5+ath,-3},{ggggg,-1,-1, 5+ath,-3},{ggggg, 0,-1, 5+ath,-3},{ggggg, 1, 0, 5+ath,-3},
						}, user, pointed_thing)

		elseif cdir == 27 then  -- pointed southwest (6, dig down)
			run_list(  {												{ggggg,-2, 0, 5+ath, 3},{ggggg,-1, 0, 5+ath, 3},{ggggg, 0, 0, 5+ath, 3},
												{ggggg,-3,-1, 5+ath, 2},{ggggg,-2,-1, 6+ith, 2},{ggagg,-1, 0, 4+ith, 2},{ggggg, 0, 0, 6+ith, 2},
						{ggggg,-4,-1, 4+ath, 1},{ggggg,-3,-1, 5+ath, 1},{gaagg,-2,-1, 4+ith, 1},{ssaag,-1, 0, 5+ith, 1},{ggggg, 0, 0, 6+ith, 1},{ggggg, 1, 0, 6+ith, 1},
						{ggggg,-4,-1, 4+ath, 0},{gaxgx,-3,-1, 3+ith, 0},{saagg,-2,-1, 4+ith, 0},{saaag,-1,-1, 5+ith, 0},{sbaag, 0, 0, 5+ith, 0},{ggggg, 1, 0, 6+ith, 0},{ggggg, 2, 0, 6+ith, 0},{ggggg, 3, 0, 5+ath, 0},
						{ggggg,-4,-1, 4+ath,-1},{ggggg,-3,-1, 5+ith,-1},{ggggg,-2,-1, 6+ith,-1},{baagg,-1,-1, 4+ith,-1},{saaag, 0,-1, 5+ith,-1},{ssaag, 1, 0, 5+ith,-1},{ggagg, 2, 0, 4+ith,-1},{ggggg, 3, 0, 5+ath,-1},
																		{ggggg,-2,-1, 5+ith,-2},{ggggg,-1,-1, 6+ith,-2},{saagg, 0,-1, 4+ith,-2},{gaagg, 1,-1, 4+ith,-2},{ggggg, 2,-1, 6+ith,-2},{ggggg, 3, 0, 5+ath,-2},
																								{ggggg,-1,-1, 5+ith,-3},{gaxgx, 0,-1, 3+ith,-3},{ggggg, 1,-1, 5+ath,-3},{ggggg, 2,-1, 5+ath,-3},
																								{ggggg,-1,-1, 4+ath,-4},{ggggg, 0,-1, 4+ath,-4},{ggggg, 1,-1, 4+ath,-4},
						}, user, pointed_thing)

		elseif cdir == 28 then  -- pointed south (8, dig down)
			run_list(  {{ggggg,-3, 0, 5+ath, 1},{ggggg,-2, 0, 6+ith, 1},{ggggg,-1, 0, 6+ith, 1},{ggggg, 0, 0, 6+ith, 1},{ggggg, 1, 0, 6+ith, 1},{ggggg, 2, 0, 6+ith, 1},{ggggg, 3, 0, 5+ath, 1},
						{ggggg,-3,-1, 5+ath, 0},{ggagg,-2, 0, 4+ith, 0},{ssaag,-1, 0, 5+ith, 0},{sbaag, 0, 0, 5+ith, 0},{ssaag, 1, 0, 5+ith, 0},{ggagg, 2, 0, 4+ith, 0},{ggggg, 3,-1, 5+ath, 0},
						{ggggg,-3,-1, 5+ath,-1},{gaagg,-2,-1, 4+ith,-1},{saaag,-1,-1, 5+ith,-1},{saaag, 0,-1, 5+ith,-1},{saaag, 1,-1, 5+ith,-1},{gaagg, 2,-1, 4+ith,-1},{ggggg, 3,-1, 5+ath,-1},
						{ggggg,-3,-1, 5+ath,-2},{gaggg,-2,-1, 3+ith,-2},{saagg,-1,-1, 4+ith,-2},{baagg, 0,-1, 4+ith,-2},{saagg, 1,-1, 4+ith,-2},{gaggg, 2,-1, 3+ith,-2},{ggggg, 3,-1, 5+ath,-2},
						{ggggg,-3,-1, 4+ath,-3},{ggggg,-2,-1, 5+ith,-3},{ggggg,-1,-1, 5+ith,-3},{ggggg, 0,-1, 5+ith,-3},{ggggg, 1,-1, 5+ith,-3},{ggggg, 2,-1, 5+ith,-3},{ggggg, 3,-1, 4+ath,-3},
						}, user, pointed_thing)

		elseif cdir == 29 then  -- pointed southeast (10, dig down)
			run_list(  {																		{ggggg, 0, 0, 5+ath, 3},{ggggg, 1, 0, 5+ath, 3},{ggggg, 2, 0, 5+ath, 3},
																								{ggggg, 0, 0, 6+ith, 2},{ggagg, 1, 0, 4+ith, 2},{ggggg, 2,-1, 6+ith, 2},{ggggg, 3,-1, 5+ath, 2},
																		{ggggg,-1, 0, 6+ith, 1},{ggggg, 0, 0, 6+ith, 1},{ssaag, 1, 0, 5+ith, 1},{gaagg, 2,-1, 4+ith, 1},{ggggg, 3,-1, 5+ath, 1},{ggggg, 4,-1, 4+ath, 1},
						{ggggg,-3, 0, 5+ath, 0},{ggggg,-2, 0, 6+ith, 0},{ggggg,-1, 0, 6+ith, 0},{sbaag, 0, 0, 5+ith, 0},{saaag, 1,-1, 5+ith, 0},{saagg, 2,-1, 4+ith, 0},{gaxgx, 3,-1, 3+ith, 0},{ggggg, 4,-1, 4+ath, 0},
						{ggggg,-3, 0, 5+ath,-1},{ggagg,-2, 0, 4+ith,-1},{ssaag,-1, 0, 5+ith,-1},{saaag, 0,-1, 5+ith,-1},{baagg, 1,-1, 4+ith,-1},{ggggg, 2,-1, 6+ith,-1},{ggggg, 3,-1, 5+ith,-1},{ggggg, 4,-1, 4+ath,-1},
						{ggggg,-3, 0, 5+ath,-2},{ggggg,-2,-1, 6+ith,-2},{gaagg,-1,-1, 4+ith,-2},{saagg, 0,-1, 4+ith,-2},{ggggg, 1,-1, 6+ith,-2},{ggggg, 2,-1, 5+ith,-2},
												{ggggg,-2,-1, 5+ath,-3},{ggggg,-1,-1, 5+ath,-3},{gaxgx, 0,-1, 3+ith,-3},{ggggg, 1,-1, 5+ith,-3},
																		{ggggg,-1,-1, 4+ath,-4},{ggggg, 0,-1, 4+ath,-4},{ggggg, 1,-1, 4+ath,-4},
						}, user, pointed_thing)

		elseif cdir == 30 then  -- pointed east (12, dig down)
			run_list(  {{ggggg,-1, 0, 5+ath, 3},{ggggg, 0,-1, 5+ath, 3},{ggggg, 1,-1, 5+ath, 3},{ggggg, 2,-1, 5+ath, 3},{ggggg, 3,-1, 4+ath, 3},
						{ggggg,-1, 0, 6+ith, 2},{ggagg, 0, 0, 4+ith, 2},{gaagg, 1,-1, 4+ith, 2},{gaggg, 2,-1, 3+ith, 2},{ggggg, 3,-1, 5+ith, 2},
						{ggggg,-1, 0, 6+ith, 1},{ssaag, 0, 0, 5+ith, 1},{saaag, 1,-1, 5+ith, 1},{saagg, 2,-1, 4+ith, 1},{ggggg, 3,-1, 5+ith, 1},
						{ggggg,-1, 0, 6+ith, 0},{sbaag, 0, 0, 5+ith, 0},{saaag, 1,-1, 5+ith, 0},{baagg, 2,-1, 4+ith, 0},{ggggg, 3,-1, 5+ith, 0},
						{ggggg,-1, 0, 6+ith,-1},{ssaag, 0, 0, 5+ith,-1},{saaag, 1,-1, 5+ith,-1},{saagg, 2,-1, 4+ith,-1},{ggggg, 3,-1, 5+ith,-1},
						{ggggg,-1, 0, 6+ith,-2},{ggagg, 0, 0, 4+ith,-2},{gaagg, 1,-1, 4+ith,-2},{gaggg, 2,-1, 3+ith,-2},{ggggg, 3,-1, 5+ith,-2},
						{ggggg,-1, 0, 5+ath,-3},{ggggg, 0,-1, 5+ath,-3},{ggggg, 1,-1, 5+ath,-3},{ggggg, 2,-1, 5+ath,-3},{ggggg, 3,-1, 4+ath,-3},
						}, user, pointed_thing)

		elseif cdir == 31 then  -- pointed northeast (14, dig down)
			run_list(  {												{ggggg,-1,-1, 4+ath, 4},{ggggg, 0,-1, 4+ath, 4},{ggggg, 1,-1, 4+ath, 4},
												{ggggg,-2,-1, 5+ath, 3},{ggggg,-1,-1, 5+ath, 3},{gaxgx, 0,-1, 3+ith, 3},{ggggg, 1,-1, 5+ith, 3},
						{ggggg,-3, 0, 5+ath, 2},{ggggg,-2,-1, 6+ith, 2},{gaagg,-1,-1, 4+ith, 2},{saagg, 0,-1, 4+ith, 2},{ggggg, 1,-1, 6+ith, 2},{ggggg, 2,-1, 5+ith, 2},
						{ggggg,-3, 0, 5+ath, 1},{ggagg,-2, 0, 4+ith, 1},{ssaag,-1, 0, 5+ith, 1},{saaag, 0,-1, 5+ith, 1},{baagg, 1,-1, 4+ith, 1},{ggggg, 2,-1, 6+ith, 1},{ggggg, 3,-1, 5+ith, 1},{ggggg, 4,-1, 4+ath, 1},
						{ggggg,-3, 0, 5+ath, 0},{ggggg,-2, 0, 6+ith, 0},{ggggg,-1, 0, 6+ith, 0},{sbaag, 0, 0, 5+ith, 0},{saaag, 1,-1, 5+ith, 0},{saagg, 2,-1, 4+ith, 0},{gaxgx, 3,-1, 3+ith, 0},{ggggg, 4,-1, 4+ath, 0},
																		{ggggg,-1, 0, 6+ith,-1},{ggggg, 0, 0, 6+ith,-1},{ssaag, 1, 0, 5+ith,-1},{gaagg, 2,-1, 4+ith,-1},{ggggg, 3,-1, 5+ath,-1},{ggggg, 4,-1, 4+ath,-1},
																								{ggggg, 0, 0, 6+ith,-2},{ggagg, 1, 0, 4+ith,-2},{ggggg, 2,-1, 6+ith,-2},{ggggg, 3,-1, 5+ath,-2},
																								{ggggg, 0, 0, 5+ath,-3},{ggggg, 1, 0, 5+ath,-3},{ggggg, 2, 0, 5+ath,-3},
						}, user, pointed_thing)
		end
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
		-- Dig single node with left mouse click, upgraded from wood to steel pickaxe equivalent.
		tool_capabilities = {
			full_punch_interval = 1.0,
			max_drop_level=1,
			groupcaps={
				cracky = {times={[1]=4.00, [2]=1.60, [3]=0.80}, maxlevel=2},
			},
			damage_groups = {fleshy=4},
		},

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
				dig_tunnel(i-1, placer, pointed_thing)
				if not continuous_updown_digging then
					tunnelmaker[pname].updown = 0   -- reset to horizontal after one use
				end
			end
		end,
	}
	)
end


-- Remove marking
-- Is used for replaces marking_not_desert and marking_desert nodes to "tunnelmaker:embankment" under the railroad tracks advtrains. 

-- Expose api
local remove_marking = {}

-- Mode is used to store the remove_marking mode for each player.
remove_marking.mode = {}

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

-- Register chatcommand
minetest.register_chatcommand("remove_marking", {
	params = "<on|off>",
	description = "Replaces marking in a tunnel with gravel",
	privs = {tunneling = true},
	func = function(name, param)
	if param == 'on' then
		remove_marking.mode[name] = 1
		minetest.chat_send_player(name, "remove_marking turned on.")
	elseif param == 'off' then
		remove_marking.mode[name] = 0
		minetest.chat_send_player(name, "remove_marking turned off.")
	else
		minetest.chat_send_player(name, "Please enter 'on' or 'off'.")
	end
end,
})

-- Replaces marking_not_desert and marking_desert nodes to "tunnelmaker:embankment".
minetest.register_globalstep(function(dtime)
	for _, player in ipairs(minetest.get_connected_players()) do
		if remove_marking.mode[player:get_player_name()] == 1 then
			remove_marking.replace(player:getpos())
		end
	end
end)
