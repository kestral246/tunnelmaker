-- tunnelmaker
-- Another tunnel digging mod for minetest.
-- Digs tunnels and builds simple bridges for advtrains track, supporting
-- all 16 track directions, along with slopes up and down.
-- 
-- by David G (kestral246@gmail.com)

-- Version 1.0 - 2018-12-16

-- based on compassgps 2.7 and compass 0.5

-- To the extent possible under law, the author(s) have dedicated all copyright and related
-- and neighboring rights to this software to the public domain worldwide. This software is
-- distributed without any warranty.

-- You should have received a copy of the CC0 Public Domain Dedication along with this
-- software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>. 


-- Configuration variables
--------------------------
-- Change the way certain features of this mod work.

-- Define height of tunnel. (default = 5)
local tunnel_height = 5

-- Define whether to add "arches" along the sides. (default = true)
local tunnel_arch = true

-- Allow tunneling through water. (default = true)
-- Builds a glass enclosure around tunnel as you go.
local water_tunnels = true

-- Add cobblestone reference points in ground. (default = true)
-- This is helpful if creating tunnels for advtrains track.
local add_references = true

-- Add torches in ceiling. (default = true)
-- Warning, tunnels will get really dark without this.
local add_torches = true

-- Radius to search for adjacent torches before placing torch. (default = 1)
-- Values from 0 to 4 are reasonable.
local torch_search_radius = 1

-- Allow digging up/down multiple times without resetting mode. (default = false)
-- Changing direction will still reset, but moving or digging will not. 
local continuous_updown_digging = false

-- End of configuration.


minetest.register_privilege("tunneling", {description = "Allow use of tunnelmaker tool"})

-- Define top level variable to maintain per player state
local tunnelmaker = {}

-- Initialize player's state when player joins
minetest.register_on_joinplayer(function(player)
	local pname = player:get_player_name()
	tunnelmaker[pname] = {updown = 0, lastdir = -1, lastpos = {x = 0, y = 0, z = 0}}
end)

-- Delete player's state when player leaves
minetest.register_on_leaveplayer(function(player)
	local pname = player:get_player_name()
	if tunnelmaker[pname] then
		tunnelmaker[pname] = nil
	end
end)

local activewidth=8  --until I can find some way to get it from minetest

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
		if string.sub(wielded_item, 0, 12) == "tunnelmaker:" then
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
					if i<=activewidth and string.sub(stack:get_name(), 0, 12) == "tunnelmaker:" then
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
				player:set_wielded_item("tunnelmaker:"..tunnelmaker_image)
			elseif activeinv then
				player:get_inventory():set_stack("main",stackidx,"tunnelmaker:"..tunnelmaker_image)
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

-- tests whether position is in desert-type biomes, such as desert, sandstone_desert, cold_desert, etc
-- always just returns false if can't determine biome (i.e., using 0.4.x version)
local is_desert = function(pos)
	if minetest.get_biome_data then
		local cur_biome = minetest.get_biome_name( minetest.get_biome_data(pos).biome )
		return string.match(cur_biome, "desert")
	else
		return false
	end
end

-- add cobble reference block to point to next target location and to aid laying track
-- in minetest 5.0+, desert biomes will use desert_cobble
local add_ref = function(x, y0, y1, z, user, pointed_thing)
	local pos = vector.add(pointed_thing.under, {x=x, y=y0, z=z})
	if add_references and not minetest.is_protected(pos, user) then
		if is_desert(pos) then
			minetest.set_node(pos, {name = "default:desert_cobble"})
		else
			minetest.set_node(pos, {name = "default:cobble"})
		end
	end
end

-- add cobble braces for bridges if they would be air
-- in minetest 5.0+, desert biomes will use desert_cobble
local add_brace = function(x, y0, y1, z, user, pointed_thing)
	local pos = vector.add(pointed_thing.under, {x=x, y=y0, z=z})
	local name = minetest.get_node(pos).name
	if not minetest.is_protected(pos, user) and name == "air" then
		if is_desert(pos) then
			minetest.set_node(pos, {name = "default:desert_cobble"})
		else
			minetest.set_node(pos, {name = "default:cobble"})
		end
	end
end

-- dig single node, but not torches, air (not diggable), or advtrain track
local dig_single = function(x, y, z, user, pointed_thing)
	local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
	local name = minetest.get_node(pos).name
	-- local isAdvtrack = minetest.registered_nodes[name].groups.advtrains_track == 1
	local isAdvtrack = string.match(name, "dtrack")
	if not minetest.is_protected(pos, user) then
		if water_tunnels and string.match(name, "water") then
			minetest.set_node(pos, {name = "air"})
		elseif name ~= "air" and name ~= "default:torch_ceiling" and not isAdvtrack then
			minetest.node_dig(pos, minetest.get_node(pos), user)
		end
	end
end

-- add stone floor if air or water or glass
-- in minetest 5.0+, desert biomes will use desert_stone
local replace_floor = function(x, y, z, user, pointed_thing)
	local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
	if not minetest.is_protected(pos, user) then
		local name = minetest.get_node(pos).name
		if name == "air" or string.match(name, "water") or name == "default:glass" then
			if is_desert(pos) then
				minetest.set_node(pos, {name = "default:desert_stone"})
			else
				minetest.set_node(pos, {name = "default:stone"})
			end
		end
	end
end

-- check for blocks that can fall in future ceiling and convert to cobble before digging
-- in minetest 5.0+, desert biomes will use desert_cobble
local replace_ceiling = function(x, y, z, user, pointed_thing)
	local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
	local ceiling = minetest.get_node(pos).name
	if (ceiling == "default:sand" or ceiling == "default:desert_sand" or
			ceiling == "default:silver_sand" or ceiling == "default:gravel") and
			not minetest.is_protected(pos, user) then
		if is_desert(pos) then
			minetest.set_node(pos, {name = "default:desert_cobble"})
		else
			minetest.set_node(pos, {name = "default:cobble"})
		end
	end
end

-- add torch
local add_light = function(spacing, user, pointed_thing)
	local pos = vector.add(pointed_thing.under, {x=0, y=tunnel_height, z=0})
	local ceiling = minetest.get_node(vector.add(pos, {x=0, y=1, z=0})).name
	if add_torches and (ceiling == "default:stone" or ceiling == "default:desert_stone") and
			minetest.get_node(pos).name == "air" and not minetest.is_protected(pos, user) and
			minetest.find_node_near(pos, spacing, {name = "default:torch_ceiling"}) == nil then
		minetest.set_node(pos, {name = "default:torch_ceiling"})
	end
	-- roof height can now be 5 or six so try again one higher
	pos = vector.add(pointed_thing.under, {x=0, y=tunnel_height+1, z=0})
	ceiling = minetest.get_node(vector.add(pos, {x=0, y=1, z=0})).name
	if add_torches and (ceiling == "default:stone" or ceiling == "default:desert_stone") and
			minetest.get_node(pos).name == "air" and not minetest.is_protected(pos, user) and
			minetest.find_node_near(pos, spacing, {name = "default:torch_ceiling"}) == nil then
		minetest.set_node(pos, {name = "default:torch_ceiling"})
	end
end

-- build glass barrier to water
-- if node is water, replace with glass
local check_for_water = function(x, y, z, user, pointed_thing)
	local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
	if water_tunnels and not minetest.is_protected(pos, user) then
		local name = minetest.get_node(pos).name
		if string.match(name, "water") then
			minetest.set_node(pos, {name = "default:glass"})
		end
		-- if string.match(name, "air") or string.match(name, "water") then -- debug
		--     minetest.set_node(pos, {name = "small:box"})
		-- end
	end
end

-- The wall and endcap functions replace water nodes with glass
-- They build a continuous column from y0 to y1 (e.g., 0:6).

-- add wall (pink)
local aw = function(x, y0, y1, z, user, pointed_thing)
	if water_tunnels then
		for y=y0, y1 do
			check_for_water(x, y, z, user, pointed_thing)
		end
	end
end

-- add endcap (light orange shorter, darker orange taller)
local ec = function(x, y0, y1, z, user, pointed_thing)
	if water_tunnels then
		for y=y0, y1 do
			check_for_water(x, y, z, user, pointed_thing)
		end
	end
end

-- dig side column, don't replace floor (light gray)
local ds = function(x, y0, y1, z, user, pointed_thing)
	local height = y1
	replace_ceiling(x, height+1, z, user, pointed_thing)
	check_for_water(x, height+1, z, user, pointed_thing)
	for y=height, y0+1, -1 do          -- dig from high to low
		dig_single(x, y, z, user, pointed_thing)
	end
	check_for_water(x, y0, z, user, pointed_thing)
end

-- dig tall column, fill in floor if air (light yellow, origin, or next ref)
local dt = function(x, y0, y1, z, user, pointed_thing)
	local height = y1
	replace_ceiling(x, height+1, z, user, pointed_thing)
	check_for_water(x, height+1, z, user, pointed_thing)
	for y=height, y0+1, -1 do          -- dig from high to low
		dig_single(x, y, z, user, pointed_thing)
	end
	replace_floor(x, y0, z, user, pointed_thing)
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
		-- Short abbreviations: "c" (ceiling) and "a" (arch)
		local c = tunnel_height
		local a = tunnel_height - 1
		if not tunnel_arch then a = tunnel_height end
-- Dig horizontal
		if cdir == 0 then  -- pointed north
			run_list({{aw,-3, 0, a, 0},{aw,-3, 0, a, 1},{aw,-3, 0, a, 2},
				{aw, 3, 0, a, 0},{aw, 3, 0, a, 1},{aw, 3, 0, a, 2},
				{ec,-3, 0, a, 3},{ec,-2, 0, a+1, 3},{ec,-1, 0, c+1, 3},{ec, 0, 0, c+1, 3},{ec, 1, 0, c+1, 3},{ec, 2, 0, a+1, 3},{ec, 3, 0, a, 3},
				{ds,-2, 0, a, 0},{dt,-1, 0, c, 0},{dt, 0, 0, c, 0},{dt, 1, 0, c, 0},{ds, 2, 0, a, 0},
				{ds,-2, 0, a, 1},{dt,-1, 0, c, 1},{dt, 0, 0, c, 1},{dt, 1, 0, c, 1},{ds, 2, 0, a, 1},
				{ds,-2, 0, a, 2},{dt,-1, 0, c, 2},{dt, 0, 0, c, 2},{dt, 1, 0, c, 2},{ds, 2, 0, a, 2},
				{add_ref, 0, 0, 0, 2}}, user, pointed_thing)

		elseif cdir == 1 then  -- pointed north-northwest
			run_list({{aw,-3, 0, a, 0},{aw,-4, 0, a, 1},{aw,-4, 0, a, 2},
				{aw, 3, 0, a, 1},{aw, 2, 0, a, 2},{aw, 2, 0, a, 3},
				{ec,-4, 0, a, 3},{ec,-3, 0, a+1, 3},{ec,-2, 0, c+1, 3},{ec,-1, 0, c+1, 3},{ec, 0, 0, c+1, 3},{ec, 1, 0, a+1, 3},
				{ds,-2, 0, a, 0},{dt,-1, 0, c, 0},{dt, 0, 0, c, 0},{dt, 1, 0, c, 0},
				{ds,-3, 0, a, 1},{dt,-2, 0, c, 1},{dt,-1, 0, c, 1},{dt, 0, 0, c, 1},{dt, 1, 0, c, 1},{ds, 2, 0, a, 1},
				{ds,-3, 0, a, 2},{dt,-2, 0, c, 2},{dt,-1, 0, c, 2},{dt, 0, 0, c, 2},{ds, 1, 0, a, 2},
				{add_ref,-1, 0, 0, 2}}, user, pointed_thing)

		elseif cdir == 2 then  -- pointed northwest
			run_list({{aw,-2, 0, a,-2},{aw,-3, 0, a,-1},
				{aw, 2, 0, a, 2},{aw, 1, 0, a, 3},
				{ec,-4, 0, a, 0},{ec,-3, 0, a, 1},{ec,-2, 0, c, 1},{ec,-1, 0, c, 2},{ec,-1, 0, a, 3},{ec, 0, 0, a, 4},
				{ds,-1, 0, a,-2},
				{ds,-2, 0, a,-1},{dt,-1, 0, c,-1},
				{ds,-3, 0, a, 0},{dt,-2, 0, c, 0},{dt,-1, 0, c, 0},{dt, 0, 0, c, 0},
				{dt,-1, 0, c, 1},{dt, 0, 0, c, 1},{dt, 1, 0, c, 1},{ds, 2, 0, a, 1},
				{dt, 0, 0, c, 2},{ds, 1, 0, a, 2},
				{ds, 0, 0, a, 3},
				{add_ref,-1, 0, 0, 1}}, user, pointed_thing)

		elseif cdir == 3 then  -- pointed west-northwest
			run_list({{aw,-1, 0, a,-3},{aw,-2, 0, a,-2},{aw,-3, 0, a,-2},
				{aw, 0, 0, a, 3},{aw,-1, 0, a, 4},{aw,-2, 0, a, 4},
				{ec,-3, 0, a+1,-1},{ec,-3, 0, c+1, 0},{ec,-3, 0, c+1, 1},{ec,-3, 0, c+1, 2},{ec,-3, 0, a+1, 3},{ec,-3, 0, a, 4},
				{ds,-1, 0, a,-2},
				{ds,-2, 0, a,-1},{dt,-1, 0, c,-1},{dt, 0, 0, c,-1},
				{dt,-2, 0, c, 0},{dt,-1, 0, c, 0},{dt, 0, 0, c, 0},
				{dt,-2, 0, c, 1},{dt,-1, 0, c, 1},{dt, 0, 0, c, 1},
				{dt,-2, 0, c, 2},{dt,-1, 0, c, 2},{ds, 0, 0, a, 2},
				{ds,-2, 0, a, 3},{ds,-1, 0, a, 3},
				{add_ref,-2, 0, 0, 1}}, user, pointed_thing)

		elseif cdir == 4 then  -- pointed west
			run_list({{aw, 0, 0, a,-3},{aw,-1, 0, a,-3},{aw,-2, 0, a,-3},
				{aw, 0, 0, a, 3},{aw,-1, 0, a, 3},{aw,-2, 0, a, 3},
				{ec,-3, 0, a,-3},{ec,-3, 0, a+1,-2},{ec,-3, 0, c+1,-1},{ec,-3, 0, c+1, 0},{ec,-3, 0, c+1, 1},{ec,-3, 0, a+1, 2},{ec,-3, 0, a, 3},
				{ds,-2, 0, a,-2},{ds,-1, 0, a,-2},{ds, 0, 0, a,-2},
				{dt,-2, 0, c,-1},{dt,-1, 0, c,-1},{dt, 0, 0, c,-1},
				{dt,-2, 0, c, 0},{dt,-1, 0, c, 0},{dt, 0, 0, c, 0},
				{dt,-2, 0, c, 1},{dt,-1, 0, c, 1},{dt, 0, 0, c, 1},
				{ds,-2, 0, a, 2},{ds,-1, 0, a, 2},{ds, 0, 0, a, 2},
				{add_ref,-2, 0, 0, 0}}, user, pointed_thing)

		elseif cdir == 5 then  -- pointed west-southwest
			run_list({{aw, 0, 0, a,-3},{aw,-1, 0, a,-4},{aw,-2, 0, a,-4},
				{aw,-1, 0, a, 3},{aw,-2, 0, a, 2},{aw,-3, 0, a, 2},
				{ec,-3, 0, a,-4},{ec,-3, 0, a+1,-3},{ec,-3, 0, c+1,-2},{ec,-3, 0, c+1,-1},{ec,-3, 0, c+1, 0},{ec,-3, 0, a+1, 1},
				{ds,-2, 0, a,-3},{ds,-1, 0, a,-3},
				{dt,-2, 0, c,-2},{dt,-1, 0, c,-2},{ds, 0, 0, a,-2},
				{dt,-2, 0, c,-1},{dt,-1, 0, c,-1},{dt, 0, 0, c,-1},
				{dt,-2, 0, c, 0},{dt,-1, 0, c, 0},{dt, 0, 0, c, 0},
				{ds,-2, 0, a, 1},{dt,-1, 0, c, 1},{dt, 0, 0, c, 1},
				{ds,-1, 0, a, 2},
				{add_ref,-2, 0, 0,-1}}, user, pointed_thing)

		elseif cdir == 6 then  -- pointed southwest
			run_list({{aw, 2, 0, a,-2},{aw, 1, 0, a,-3},
				{aw,-2, 0, a, 2},{aw,-3, 0, a, 1},
				{ec, 0, 0, a,-4},{ec,-1, 0, a,-3},{ec,-1, 0, c,-2},{ec,-2, 0, c,-1},{ec,-3, 0, a,-1},{ec,-4, 0, a, 0},
				{ds, 0, 0, a,-3},
				{dt, 0, 0, c,-2},{ds, 1, 0, a,-2},
				{dt,-1, 0, c,-1},{dt, 0, 0, c,-1},{dt, 1, 0, c,-1},{ds, 2, 0, a,-1},
				{ds,-3, 0, a, 0},{dt,-2, 0, c, 0},{dt,-1, 0, c, 0},{dt, 0, 0, c, 0},
				{ds,-2, 0, a, 1},{dt,-1, 0, c, 1},
				{ds,-1, 0, a, 2},
				{add_ref,-1, 0, 0,-1}}, user, pointed_thing)

		elseif cdir == 7 then  -- pointed south-southwest
			run_list({{aw, 3, 0, a,-1},{aw, 2, 0, a,-2},{aw, 2, 0, a,-3},
				{aw,-3, 0, a, 0},{aw,-4, 0, a,-1},{aw,-4, 0, a,-2},
				{ec, 1, 0, a+1,-3},{ec, 0, 0, c+1,-3},{ec,-1, 0, c+1, -3},{ec,-2, 0, c+1,-3},{ec,-3, 0, a+1,-3},{ec,-4, 0, a,-3},
				{ds,-3, 0, a,-2},{dt,-2, 0, c,-2},{dt,-1, 0, c,-2},{dt, 0, 0, c,-2},{ds, 1, 0, a,-2},
				{ds,-3, 0, a,-1},{dt,-2, 0, c,-1},{dt,-1, 0, c,-1},{dt, 0, 0, c,-1},{dt, 1, 0, c,-1},{ds, 2, 0, a,-1},
				{ds,-2, 0, a, 0},{dt,-1, 0, c, 0},{dt, 0, 0, c, 0},{dt, 1, 0, c, 0},
				{add_ref,-1, 0, 0,-2}}, user, pointed_thing)

		elseif cdir == 8 then  -- pointed south
			run_list({{aw, 3, 0, a, 0},{aw, 3, 0, a,-1},{aw, 3, 0, a,-2},
				{aw,-3, 0, a, 0},{aw,-3, 0, a,-1},{aw,-3, 0, a,-2},
				{ec, 3, 0, a,-3},{ec, 2, 0, a+1,-3},{ec, 1, 0, c+1,-3},{ec, 0, 0, c+1,-3},{ec,-1, 0, c+1,-3},{ec,-2, 0, a+1,-3},{ec,-3, 0, a,-3},
				{ds,-2, 0, a,-2},{dt,-1, 0, c,-2},{dt, 0, 0, c,-2},{dt, 1, 0, c,-2},{ds, 2, 0, a,-2},
				{ds,-2, 0, a,-1},{dt,-1, 0, c,-1},{dt, 0, 0, c,-1},{dt, 1, 0, c,-1},{ds, 2, 0, a,-1},
				{ds,-2, 0, a, 0},{dt,-1, 0, c, 0},{dt, 0, 0, c, 0},{dt, 1, 0, c, 0},{ds, 2, 0, a, 0},
				{add_ref,0, 0, 0,-2}}, user, pointed_thing)

		elseif cdir == 9 then  -- pointed south-southeast
			run_list({{aw, 3, 0, a, 0},{aw, 4, 0, a,-1},{aw, 4, 0, a,-2},
				{aw,-3, 0, a,-1},{aw,-2, 0, a,-2},{aw,-2, 0, a,-3},
				{ec, 4, 0, a,-3},{ec, 3, 0, a+1,-3},{ec, 2, 0, c+1,-3},{ec, 1, 0, c+1,-3},{ec, 0, 0, c+1,-3},{ec,-1, 0, a+1,-3},
				{ds,-1, 0, a,-2},{dt, 0, 0, c,-2},{dt, 1, 0, c,-2},{dt, 2, 0, c,-2},{ds, 3, 0, a,-2},
				{ds,-2, 0, a,-1},{dt,-1, 0, c,-1},{dt, 0, 0, c,-1},{dt, 1, 0, c,-1},{dt, 2, 0, c,-1},{ds, 3, 0, a,-1},
				{dt,-1, 0, c, 0},{dt, 0, 0, c, 0},{dt, 1, 0, c, 0},{ds, 2, 0, a, 0},
				{add_ref,1, 0, 0,-2}}, user, pointed_thing)

		elseif cdir == 10 then  -- pointed southeast
			run_list({{aw, 2, 0, a, 2},{aw, 3, 0, a, 1},
				{aw,-2, 0, a,-2},{aw,-1, 0, a,-3},
				{ec, 4, 0, a, 0},{ec, 3, 0, a,-1},{ec, 2, 0, c,-1},{ec, 1, 0, c,-2},{ec, 1, 0, a,-3},{ec, 0, 0, a,-4},
				{ds, 0, 0, a,-3},
				{ds,-1, 0, a,-2},{dt, 0, 0, c,-2},
				{ds,-2, 0, a,-1},{dt,-1, 0, c,-1},{dt, 0, 0, c,-1},{dt, 1, 0, c,-1},
				{dt, 0, 0, c, 0},{dt, 1, 0, c, 0},{dt, 2, 0, c, 0},{ds, 3, 0, a, 0},
				{dt, 1, 0, c, 1},{ds, 2, 0, a, 1},
				{ds, 1, 0, a, 2},
				{add_ref, 1, 0, 0,-1}}, user, pointed_thing)

		elseif cdir == 11 then  -- pointed east-southeast
			run_list({{aw, 1, 0, a, 3},{aw, 2, 0, a, 2},{aw, 3, 0, a, 2},
				{aw, 0, 0, a,-3},{aw, 1, 0, a,-4},{aw, 2, 0, a,-4},
				{ec, 3, 0, a+1, 1},{ec, 3, 0, c+1, 0},{ec, 3, 0, c+1,-1},{ec, 3, 0, c+1,-2},{ec, 3, 0, a+1,-3},{ec, 3, 0, a,-4},
				{ds, 1, 0, a,-3},{ds, 2, 0, a,-3},
				{ds, 0, 0, a,-2},{dt, 1, 0, c,-2},{dt, 2, 0, c,-2},
				{dt, 0, 0, c,-1},{dt, 1, 0, c,-1},{dt, 2, 0, c,-1},
				{dt, 0, 0, c, 0},{dt, 1, 0, c, 0},{dt, 2, 0, c, 0},
				{dt, 0, 0, c, 1},{dt, 1, 0, c, 1},{ds, 2, 0, a, 1},
				{ds, 1, 0, a, 2},
				{add_ref, 2, 0, 0,-1}}, user, pointed_thing)

		elseif cdir == 12 then  -- pointed east
			run_list({{aw, 0, 0, a, 3},{aw, 1, 0, a, 3},{aw, 2, 0, a, 3},
				{aw, 0, 0, a,-3},{aw, 1, 0, a,-3},{aw, 2, 0, a,-3},
				{ec, 3, 0, a, 3},{ec, 3, 0, a+1, 2},{ec, 3, 0, c+1, 1},{ec, 3, 0, c+1, 0},{ec, 3, 0, c+1,-1},{ec, 3, 0, a+1,-2},{ec, 3, 0, a,-3},
				{ds, 0, 0, a,-2},{ds, 1, 0, a,-2},{ds, 2, 0, a,-2},
				{dt, 0, 0, c,-1},{dt, 1, 0, c,-1},{dt, 2, 0, c,-1},
				{dt, 0, 0, c, 0},{dt, 1, 0, c, 0},{dt, 2, 0, c, 0},
				{dt, 0, 0, c, 1},{dt, 1, 0, c, 1},{dt, 2, 0, c, 1},
				{ds, 0, 0, a, 2},{ds, 1, 0, a, 2},{ds, 2, 0, a, 2},
				{add_ref, 2, 0, 0, 0}}, user, pointed_thing)

		elseif cdir == 13 then  -- pointed east-northeast
			run_list({{aw, 0, 0, a, 3},{aw, 1, 0, a, 4},{aw, 2, 0, a, 4},
				{aw, 1, 0, a,-3},{aw, 2, 0, a,-2},{aw, 3, 0, a,-2},
				{ec, 3, 0, a, 4},{ec, 3, 0, a+1, 3},{ec, 3, 0, c+1, 2},{ec, 3, 0, c+1, 1},{ec, 3, 0, c+1, 0},{ec, 3, 0, a+1,-1},
				{ds, 1, 0, a,-2},
				{dt, 0, 0, c,-1},{dt, 1, 0, c,-1},{ds, 2, 0, a,-1},
				{dt, 0, 0, c, 0},{dt, 1, 0, c, 0},{dt, 2, 0, c, 0},
				{dt, 0, 0, c, 1},{dt, 1, 0, c, 1},{dt, 2, 0, c, 1},
				{ds, 0, 0, a, 2},{dt, 1, 0, c, 2},{dt, 2, 0, c, 2},
				{ds, 1, 0, a, 3},{ds, 2, 0, a, 3},
				{add_ref, 2, 0, 0, 1}}, user, pointed_thing)

		elseif cdir == 14 then  -- pointed northeast
			run_list({{aw,-2, 0, a, 2},{aw,-1, 0, a, 3},
				{aw, 2, 0, a,-2},{aw, 3, 0, a,-1},
				{ec, 0, 0, a, 4},{ec, 1, 0, a, 3},{ec, 1, 0, c, 2},{ec, 2, 0, c, 1},{ec, 3, 0, a, 1},{ec, 4, 0, a, 0},
				{ds, 1, 0, a,-2},
				{dt, 1, 0, c,-1},{ds, 2, 0, a,-1},
				{dt, 0, 0, c, 0},{dt, 1, 0, c, 0},{dt, 2, 0, c, 0},{ds, 3, 0, a, 0},
				{ds,-2, 0, a, 1},{dt,-1, 0, c, 1},{dt, 0, 0, c, 1},{dt, 1, 0, c, 1},
				{ds,-1, 0, a, 2},{dt, 0, 0, c, 2},
				{ds, 0, 0, a, 3},
				{add_ref, 1, 0, 0, 1}}, user, pointed_thing)

		elseif cdir == 15 then  -- pointed north-northeast
			run_list({{aw,-3, 0, a, 1},{aw,-2, 0, a, 2},{aw,-2, 0, a, 3},
				{aw, 3, 0, a, 0},{aw, 4, 0, a, 1},{aw, 4, 0, a, 2},
				{ec,-1, 0, a+1, 3},{ec, 0, 0, c+1, 3},{ec, 1, 0, c+1, 3},{ec, 2, 0, c+1, 3},{ec, 3, 0, a+1, 3},{ec, 4, 0, a, 3},
				{dt,-1, 0, c, 0},{dt, 0, 0, c, 0},{dt, 1, 0, c, 0},{ds, 2, 0, a, 0},
				{ds,-2, 0, a, 1},{dt,-1, 0, c, 1},{dt, 0, 0, c, 1},{dt, 1, 0, c, 1},{dt, 2, 0, c, 1},{ds, 3, 0, a, 1},
				{ds,-1, 0, a, 2},{dt, 0, 0, c, 2},{dt, 1, 0, c, 2},{dt, 2, 0, c, 2},{ds, 3, 0, a, 2},
				{add_ref, 1, 0, 0, 2}}, user, pointed_thing)

-- Dig for slope up
		elseif cdir == 16 then  -- pointed north (0, dig up)
			run_list({{aw,-3, 0, a, 0},{aw,-3, 0, a+1, 1},{aw,-3, 1, a+1, 2},
				{aw, 3, 0, a, 0},{aw, 3, 0, a+1, 1},{aw, 3, 1, a+1, 2},
				{ec,-3, 1, a+1, 3},{ec,-2, 1, a+2, 3},{ec,-1, 1, c+2, 3},{ec, 0, 1, c+2, 3},{ec, 1, 1, c+2, 3},{ec, 2, 1, a+2, 3},{ec, 3, 1, a+1, 3},
				{ds,-2, 0, a, 0},{dt,-1, 0, c, 0},{dt, 0, 0, c, 0},{dt, 1, 0, c, 0},{ds, 2, 0, a, 0},
				{ds,-2, 0, a+1, 1},{dt,-1, 0, c+1, 1},{dt, 0, 0, c+1, 1},{dt, 1, 0, c+1, 1},{ds, 2, 0, a+1, 1},
				{ds,-2, 1, a+1, 2},{dt,-1, 1, c+1, 2},{dt, 0, 1, c+1, 2},{dt, 1, 1, c+1, 2},{ds, 2, 1, a+1, 2},
				{add_ref, 0, 1, 0, 2},
				{add_brace,-1, 0, 0, 2},
				{add_brace, 1, 0, 0, 2}}, user, pointed_thing)

		elseif cdir == 17 then  -- pointed northwest (2, dig up)
			run_list({{aw,-2, 0, a+1,-2},{aw,-3, 1, a+1,-1},
				{aw, 2, 0, a+1, 2},{aw, 1, 1, a+1, 3},
				{ec,-4, 1, a+1, 0},{ec,-3, 1, c+1, 1},{ec,-2, 1, c+2, 1},{ec,-1, 1, c+2, 2},{ec,-1, 1, c+1, 3},{ec, 0, 1, a+1, 4},
				{ds,-1, 0, a,-2},
				{ds,-2, 0, a+1,-1},{dt,-1, 0, c,-1},
				{ds,-3, 1, a+1, 0},{dt,-2, 1, c+1, 0},{dt,-1, 0, c+1, 0},{dt, 0, 0, c+1, 0},
				{dt,-1, 1, c+1, 1},{dt, 0, 0, c+1, 1},{dt, 1, 0, c, 1},{ds, 2, 0, a, 1},
				{dt, 0, 1, c+1, 2},{ds, 1, 0, a+1, 2},
				{ds, 0, 1, a+1, 3},
				{add_ref,-1, 1, 0, 1},
				{add_brace,-2, 0, 0, 0},
				{add_brace, 0, 0, 0, 2}}, user, pointed_thing)

		elseif cdir == 18 then  -- pointed west (4, dig up)
			run_list({{aw, 0, 0, a,-3},{aw,-1, 0, a+1,-3},{aw,-2, 1, a+1,-3},
				{aw, 0, 0, a, 3},{aw,-1, 0, a+1, 3},{aw,-2, 1, a+1, 3},
				{ec,-3, 1, a+1,-3},{ec,-3, 1, a+2,-2},{ec,-3, 1, c+2,-1},{ec,-3, 1, c+2, 0},{ec,-3, 1, c+2, 1},{ec,-3, 1, a+2, 2},{ec,-3, 1, a+1, 3},
				{ds,-2, 1, a+1,-2},{ds,-1, 0, a+1,-2},{ds, 0, 0, a,-2},
				{dt,-2, 1, c+1,-1},{dt,-1, 0, c+1,-1},{dt, 0, 0, c,-1},
				{dt,-2, 1, c+1, 0},{dt,-1, 0, c+1, 0},{dt, 0, 0, c, 0},
				{dt,-2, 1, c+1, 1},{dt,-1, 0, c+1, 1},{dt, 0, 0, c, 1},
				{ds,-2, 1, a+1, 2},{ds,-1, 0, a+1, 2},{ds, 0, 0, a, 2},
				{add_ref,-2, 1, 0, 0},
				{add_brace,-2, 0, 0,-1},
				{add_brace,-2, 0, 0, 1}}, user, pointed_thing) 

		elseif cdir == 19 then  -- pointed southwest (6, dig up)
			run_list({{aw, 2, 0, a+1,-2},{aw, 1, 1, a+1,-3},
				{aw,-2, 0, a+1, 2},{aw,-3, 1, a+1, 1},
				{ec, 0, 1, a+1,-4},{ec,-1, 1, c+1,-3},{ec,-1, 1, c+2,-2},{ec,-2, 1, c+2,-1},{ec,-3, 1, c+1,-1},{ec,-4, 1, a+1, 0},
				{ds, 0, 1, a+1,-3},
				{dt, 0, 1, c+1,-2},{ds, 1, 0, a+1,-2},
				{dt,-1, 1, c+1,-1},{dt, 0, 0, c+1,-1},{dt, 1, 0, c,-1},{ds, 2, 0, a,-1},
				{ds,-3, 1, a+1, 0},{dt,-2, 1, c+1, 0},{dt,-1, 0, c+1, 0},{dt, 0, 0, c+1, 0},
				{ds,-2, 0, a+1, 1},{dt,-1, 0, c, 1},
				{ds,-1, 0, a, 2},
				{add_ref,-1, 1, 0,-1},
				{add_brace,-2, 0, 0, 0},
				{add_brace, 0, 0, 0,-2}}, user, pointed_thing) 

		elseif cdir == 20 then  -- pointed south (8, dig up)
			run_list({{aw, 3, 0, a, 0},{aw, 3, 0, a+1,-1},{aw, 3, 1, a+1,-2},
				{aw,-3, 0, a, 0},{aw,-3, 0, a+1,-1},{aw,-3, 1, a+1,-2},
				{ec, 3, 1, a+1,-3},{ec, 2, 1, a+2,-3},{ec, 1, 1, c+2,-3},{ec, 0, 1, c+2,-3},{ec,-1, 1, c+2,-3},{ec,-2, 1, a+2,-3},{ec,-3, 1, a+1,-3},
				{ds,-2, 1, a+1,-2},{dt,-1, 1, c+1,-2},{dt, 0, 1, c+1,-2},{dt, 1, 1, c+1,-2},{ds, 2, 1, a+1,-2},
				{ds,-2, 0, a+1,-1},{dt,-1, 0, c+1,-1},{dt, 0, 0, c+1,-1},{dt, 1, 0, c+1,-1},{ds, 2, 0, a+1,-1},
				{ds,-2, 0, a, 0},{dt,-1, 0, c, 0},{dt, 0, 0, c, 0},{dt, 1, 0, c, 0},{ds, 2, 0, a, 0},
				{add_ref,0, 1, 0,-2},
				{add_brace,-1, 0, 0,-2},
				{add_brace, 1, 0, 0,-2}}, user, pointed_thing) 

		elseif cdir == 21 then  -- pointed southeast (10, dig up)
			run_list({{aw, 2, 0, a+1, 2},{aw, 3, 1, a+1, 1},
				{aw,-2, 0, a+1,-2},{aw,-1, 1, a+1,-3},
				{ec, 4, 1, a+1, 0},{ec, 3, 1, c+1,-1},{ec, 2, 1, c+2,-1},{ec, 1, 1, c+2,-2},{ec, 1, 1, c+1,-3},{ec, 0, 1, a+1,-4},
				{ds, 0, 1, a+1,-3},
				{ds,-1, 0, a+1,-2},{dt, 0, 1, c+1,-2},
				{ds,-2, 0, a,-1},{dt,-1, 0, c,-1},{dt, 0, 0, c+1,-1},{dt, 1, 1, c+1,-1},
				{dt, 0, 0, c+1, 0},{dt, 1, 0, c+1, 0},{dt, 2, 1, c+1, 0},{ds, 3, 1, a+1, 0},
				{dt, 1, 0, c, 1},{ds, 2, 0, a+1, 1},
				{ds, 1, 0, a, 2},
				{add_ref, 1, 1, 0,-1},
				{add_brace, 2, 0, 0, 0},
				{add_brace, 0, 0, 0,-2}}, user, pointed_thing) 

		elseif cdir == 22 then  -- pointed east (12, dig up)
			run_list({{aw, 0, 0, a, 3},{aw, 1, 0, a+1, 3},{aw, 2, 1, a+1, 3},
				{aw, 0, 0, a,-3},{aw, 1, 0, a+1,-3},{aw, 2, 1, a+1,-3},
				{ec, 3, 1, a+1, 3},{ec, 3, 1, a+2, 2},{ec, 3, 1, c+2, 1},{ec, 3, 1, c+2, 0},{ec, 3, 1, c+2,-1},{ec, 3, 1, a+2,-2},{ec, 3, 1, a+1,-3},
				{ds, 0, 0, a,-2},{ds, 1, 0, a+1,-2},{ds, 2, 1, a+1,-2},
				{dt, 0, 0, c,-1},{dt, 1, 0, c+1,-1},{dt, 2, 1, c+1,-1},
				{dt, 0, 0, c, 0},{dt, 1, 0, c+1, 0},{dt, 2, 1, c+1, 0},
				{dt, 0, 0, c, 1},{dt, 1, 0, c+1, 1},{dt, 2, 1, c+1, 1},
				{ds, 0, 0, a, 2},{ds, 1, 0, a+1, 2},{ds, 2, 1, a+1, 2},
				{add_ref, 2, 1, 0, 0},
				{add_brace, 2, 0, 0, 1},
				{add_brace, 2, 0, 0,-1}}, user, pointed_thing) 

		elseif cdir == 23 then  -- pointed northeast (14, dig up)
			run_list({{aw,-2, 0, a+1, 2},{aw,-1, 1, a+1, 3},
				{aw, 2, 0, a+1,-2},{aw, 3, 1, a+1,-1},
				{ec, 0, 1, a+1, 4},{ec, 1, 1, c+1, 3},{ec, 1, 1, c+2, 2},{ec, 2, 1, c+2, 1},{ec, 3, 1, c+1, 1},{ec, 4, 1, a+1, 0},
				{ds, 1, 0, a,-2},
				{dt, 1, 0, c,-1},{ds, 2, 0, a+1,-1},
				{dt, 0, 0, c+1, 0},{dt, 1, 0, c+1, 0},{dt, 2, 1, c+1, 0},{ds, 3, 1, a+1, 0},
				{ds,-2, 0, a, 1},{dt,-1, 0, c, 1},{dt, 0, 0, c+1, 1},{dt, 1, 1, c+1, 1},
				{ds,-1, 0, a+1, 2},{dt, 0, 1, c+1, 2},
				{ds, 0, 1, a+1, 3},
				{add_ref, 1, 1, 0, 1},
				{add_brace, 0, 0, 0, 2},
				{add_brace, 2, 0, 0, 0}}, user, pointed_thing) 

-- Dig for slope down
		elseif cdir == 24 then  -- pointed north (0, dig down)
			run_list({{aw,-3, 0, a, 0},{aw,-3,-1, a, 1},{aw,-3,-1, a-1, 2},
				{aw, 3, 0, a, 0},{aw, 3,-1, a, 1},{aw, 3,-1, a-1, 2},
				{ec,-3,-1, a-1, 3},{ec,-2,-1, a, 3},{ec,-1,-1, c, 3},{ec, 0,-1, c, 3},{ec, 1,-1, c, 3},{ec, 2,-1, a, 3},{ec, 3,-1, a-1, 3},
				{ds,-2, 0, a, 0},{dt,-1, 0, c, 0},{dt, 0, 0, c, 0},{dt, 1, 0, c, 0},{ds, 2, 0, a, 0},
				{ds,-2,-1, a, 1},{dt,-1,-1, c, 1},{dt, 0,-1, c, 1},{dt, 1,-1, c, 1},{ds, 2,-1, a, 1},
				{ds,-2,-1, a-1, 2},{dt,-1,-1, c-1, 2},{dt, 0,-1, c-1, 2},{dt, 1,-1, c-1, 2},{ds, 2,-1, a-1, 2},
				{add_ref, 0,-1, 0, 2},
				{add_brace,-1,-1, 0, 0},
				{add_brace, 1,-1, 0, 0}}, user, pointed_thing)

		elseif cdir == 25 then  -- pointed northwest (2, dig down)
			run_list({{aw,-2,-1, a,-2},{aw,-3,-1, a,-1},
				{aw, 2,-1, a, 2},{aw, 1,-1, a, 3},
				{ec,-4,-1, a-1, 0},{ec,-3,-1, a, 1},{ec,-2,-1, c, 1},{ec,-1,-1, c, 2},{ec,-1,-1, a, 3},{ec, 0,-1, a-1, 4},
				{ds,-1, 0, a,-2},
				{ds,-2,-1, a,-1},{dt,-1, 0, c,-1},
				{ds,-3,-1, a-1, 0},{dt,-2,-1, c-1, 0},{dt,-1,-1, c, 0},{dt, 0, 0, c, 0},
				{dt,-1,-1, c, 1},{dt, 0,-1, c, 1},{dt, 1, 0, c, 1},{ds, 2, 0, a, 1},
				{dt, 0,-1, c-1, 2},{ds, 1,-1, a, 2},
				{ds, 0,-1, a-1, 3},
				{add_ref,-1,-1, 0, 1},
				{add_brace,-1,-1, 0,-1},
				{add_brace, 1,-1, 0, 1}}, user, pointed_thing)

		elseif cdir == 26 then  -- pointed west (4, dig down)
			run_list({{aw, 0, 0, a,-3},{aw,-1,-1, a,-3},{aw,-2,-1, a-1,-3},
				{aw, 0, 0, a, 3},{aw,-1,-1, a, 3},{aw,-2,-1, a-1, 3},
				{ec,-3,-1, a-1,-3},{ec,-3,-1, a,-2},{ec,-3,-1, c,-1},{ec,-3,-1, c, 0},{ec,-3,-1, c, 1},{ec,-3,-1, a, 2},{ec,-3,-1, a-1, 3},
				{ds,-2,-1, a-1,-2},{ds,-1,-1, a,-2},{ds, 0, 0, a,-2},
				{dt,-2,-1, c-1,-1},{dt,-1,-1, c,-1},{dt, 0, 0, c,-1},
				{dt,-2,-1, c-1, 0},{dt,-1,-1, c, 0},{dt, 0, 0, c, 0},
				{dt,-2,-1, c-1, 1},{dt,-1,-1, c, 1},{dt, 0, 0, c, 1},
				{ds,-2,-1, a-1, 2},{ds,-1,-1, a, 2},{ds, 0, 0, a, 2},
				{add_ref,-2,-1, 0, 0},
				{add_brace, 0,-1, 0, 1},
				{add_brace, 0,-1, 0,-1}}, user, pointed_thing)

		elseif cdir == 27 then  -- pointed southwest (6, dig down)
			run_list({{aw, 2,-1, a,-2},{aw, 1,-1, a,-3},
				{aw,-2,-1, a, 2},{aw,-3,-1, a, 1},
				{ec, 0,-1, a-1,-4},{ec,-1,-1, a,-3},{ec,-1, -1, c,-2},{ec,-2,-1, c,-1},{ec,-3,-1, a,-1},{ec,-4,-1, a-1, 0},
				{ds, 0,-1, a-1,-3},
				{dt, 0,-1, c-1,-2},{ds, 1,-1, a,-2},
				{dt,-1,-1, c,-1},{dt, 0,-1, c,-1},{dt, 1, 0, c,-1},{ds, 2, 0, a,-1},
				{ds,-3,-1, a-1, 0},{dt,-2,-1, c-1, 0},{dt,-1,-1, c, 0},{dt, 0, 0, c, 0},
				{ds,-2,-1, a, 1},{dt,-1, 0, c, 1},
				{ds,-1, 0, a, 2},
				{add_ref,-1,-1, 0,-1},
				{add_brace,-1,-1, 0, 1},
				{add_brace, 1,-1, 0,-1}}, user, pointed_thing)

		elseif cdir == 28 then  -- pointed south (8, dig down)
			run_list({{aw, 3, 0, a, 0},{aw, 3,-1, a,-1},{aw, 3,-1, a-1,-2},
				{aw,-3, 0, a, 0},{aw,-3,-1, a,-1},{aw,-3,-1, a-1,-2},
				{ec, 3,-1, a-1,-3},{ec, 2,-1, a,-3},{ec, 1,-1, c,-3},{ec, 0,-1, c,-3},{ec,-1,-1, c,-3},{ec,-2,-1, a,-3},{ec,-3,-1, a-1,-3},
				{ds,-2,-1, a-1,-2},{dt,-1,-1, c-1,-2},{dt, 0,-1, c-1,-2},{dt, 1,-1, c-1,-2},{ds, 2,-1, a-1,-2},
				{ds,-2,-1, a,-1},{dt,-1,-1, c,-1},{dt, 0,-1, c,-1},{dt, 1,-1, c,-1},{ds, 2,-1, a,-1},
				{ds,-2, 0, a, 0},{dt,-1, 0, c, 0},{dt, 0, 0, c, 0},{dt, 1, 0, c, 0},{ds, 2, 0, a, 0},
				{add_ref, 0,-1, 0,-2},
				{add_brace,-1,-1, 0, 0},
				{add_brace, 1,-1, 0, 0}}, user, pointed_thing)

		elseif cdir == 29 then  -- pointed southeast (10, dig down)
			run_list({{aw, 2,-1, a, 2},{aw, 3,-1, a, 1},
				{aw,-2,-1, a,-2},{aw,-1,-1, a,-3},
				{ec, 4,-1, a-1, 0},{ec, 3,-1, a,-1},{ec, 2,-1, c,-1},{ec, 1,-1, c,-2},{ec, 1,-1, a,-3},{ec, 0,-1, a-1,-4},
				{ds, 0,-1, a-1,-3},
				{ds,-1,-1, a,-2},{dt, 0,-1, c-1,-2},
				{ds,-2, 0, a,-1},{dt,-1, 0, c,-1},{dt, 0,-1, c,-1},{dt, 1,-1, c,-1},
				{dt, 0, 0, c, 0},{dt, 1,-1, c, 0},{dt, 2,-1, c-1, 0},{ds, 3,-1, a-1, 0},
				{dt, 1, 0, c, 1},{ds, 2,-1, a, 1},
				{ds, 1, 0, a, 2},
				{add_ref, 1,-1, 0,-1},
				{add_brace,-1,-1, 0,-1},
				{add_brace, 1,-1, 0, 1}}, user, pointed_thing)

		elseif cdir == 30 then  -- pointed east (12, dig down)
			run_list({{aw, 0, 0, a, 3},{aw, 1,-1, a, 3},{aw, 2,-1, a-1, 3},
				{aw, 0, 0, a,-3},{aw, 1,-1, a,-3},{aw, 2,-1, a-1,-3},
				{ec, 3,-1, a-1, 3},{ec, 3,-1, a, 2},{ec, 3,-1, c, 1},{ec, 3,-1, c, 0},{ec, 3,-1, c,-1},{ec, 3,-1, a,-2},{ec, 3,-1, a-1,-3},
				{ds, 0, 0, a,-2},{ds, 1,-1, a,-2},{ds, 2,-1, a-1,-2},
				{dt, 0, 0, c,-1},{dt, 1,-1, c,-1},{dt, 2,-1, c-1,-1},
				{dt, 0, 0, c, 0},{dt, 1,-1, c, 0},{dt, 2,-1, c-1, 0},
				{dt, 0, 0, c, 1},{dt, 1,-1, c, 1},{dt, 2,-1, c-1, 1},
				{ds, 0, 0, a, 2},{ds, 1,-1, a, 2},{ds, 2,-1, a-1, 2},
				{add_ref, 2,-1, 0, 0},
				{add_brace, 0,-1, 0, 1},
				{add_brace, 0,-1, 0,-1}}, user, pointed_thing)

		elseif cdir == 31 then  -- pointed northeast (14, dig down)
			run_list({{aw,-2,-1, a, 2},{aw,-1,-1, a, 3},
				{aw, 2,-1, a,-2},{aw, 3,-1, a,-1},
				{ec, 0,-1, a-1, 4},{ec, 1,-1, a, 3},{ec, 1,-1, c, 2},{ec, 2,-1, c, 1},{ec, 3,-1, a, 1},{ec, 4,-1, a-1, 0},
				{ds, 1, 0, a,-2},
				{dt, 1, 0, c,-1},{ds, 2,-1, a,-1},
				{dt, 0, 0, c, 0},{dt, 1,-1, c, 0},{dt, 2,-1, c-1, 0},{ds, 3,-1, a-1, 0},
				{ds,-2, 0, a, 1},{dt,-1, 0, c, 1},{dt, 0,-1, c, 1},{dt, 1,-1, c, 1},
				{ds,-1,-1, a, 2},{dt, 0,-1, c-1, 2},
				{ds, 0,-1, a-1, 3},
				{add_ref, 1,-1, 0, 1},  -- fixed bug
				{add_brace,-1,-1, 0, 0},
				{add_brace, 1,-1, 0,-1}}, user, pointed_thing)
		end
		add_light(torch_search_radius, user, pointed_thing)
	end
end

local i
for i,img in ipairs(images) do
	local inv = 1
	if i == 2 then
		inv = 0
	end

	minetest.register_tool("tunnelmaker:"..(i-1),
	{
		description = "Tunnel Maker",
		groups = {not_in_creative_inventory=inv},
		inventory_image = img,
		wield_image = img,
		stack_max = 1,
		range = 7.0,
		-- Dig single node with left mouse click, upgraded from wood to steel pickaxe equivalent.
		-- Works in both regular and creative modes.
		tool_capabilities = {
			full_punch_interval = 1.0,
			max_drop_level=1,
			groupcaps={
				cracky = {times={[1]=4.00, [2]=1.60, [3]=0.80}, maxlevel=2},
			},
			damage_groups = {fleshy=4},
		},

		-- Dig tunnel with right mouse click (double tap on android)
		-- tunneling only works if in creative mode
		on_place = function(itemstack, placer, pointed_thing)
			local pname = placer and placer:get_player_name() or ""
			local creative_enabled = (creative and creative.is_enabled_for
							and creative.is_enabled_for(pname))
			if creative_enabled then
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
			end
		end,
	}
	)
end

minetest.register_craft({
		output = 'tunnelmaker:1',
		recipe = {
				{'default:diamondblock', 'default:mese_block', 'default:diamondblock'},
				{'default:mese_block', 'default:diamondblock', 'default:mese_block'},
				{'default:diamondblock', 'default:mese_block', 'default:diamondblock'}
		}
})
