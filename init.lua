-- tunnelmaker
-- Another tunnel digging mod for minetest.
-- by David G (kestral246@gmail.com)

-- Version 0.9.2
-- Continue work making tunnelmaker play nice with advtrains track.
-- Per Orwell's request, changed method for determining if node is advtrains track.
-- Instead of searching for dtrack in name of node,
-- I check whether the node belongs to the advtrains_track group using:
--     if minetest.registered_nodes[name].groups.advtrains_track == 1 then
--
-- Note that one can't right click ATC track with tunnelmaker, that track overrides right click.
-- Trying to right click on slope track probably won't do what is wanted.  Right now it treats
-- it like any other track, and digs the ground level.

-- Version 0.9.1
-- 1. Try to play nicer with already placed advtrains track (dtrack*).
--   A. Don't dig dtrack nodes.
--      This allows expanding or extending tunnels where track has already been laid.
--    However this causes issues when using tunnelmaker to raise or lower track.
--      Trying to dig tunnel one node above track won't fill where placed track exists.
--      Trying to dig tunnel one node below track will cause existing track to drop.
--   B. If pointing to dtrack node, assume user actually wants to point to ground below track.
--      Lower positions of pointed_thing by one node, while keeping name the same.
--      This assumes that existing track is sitting on valid node.
-- 2. Restruction direction code to make it much shorter.
-- 3. Fixed bug in implementation of SSW digging pattern.
--
-- Version 0.9.0
-- 1. Updated digging patterns to fix minor irregularities.
-- 2. Added protections for tunneling in water.
--      Adds glass walls around tunnel whenever there is water.
--      Adds glass endcap at end to protect from flooding while tunneling.
--      Note that this can place undesired glass when digging next to ground-level water. This
--        won't happen as long as you're one node higher than the water.
-- 3. Restructured code again.  Code is longer, but simpler to understand.

-- Version 0.8.1
-- Test if air before digging.  Cleans up air not diggable INFO messages.
-- Added test for desert-type biomes, which lets me start using biome-appropriate fill.
--   needs minetest 0.5.0+ to correctly flag desert biomes
--   however, if api doesn't exist (using 0.4.x), test just always returns false

-- Version 0.8.0
-- Changed from dig_node to node_dig (based on what matyilona200 did for the Tunneltest mod)
-- Places only a single instance of each type of block dug in inventory
-- Doesn't cause blocks to drop in 0.5.0-dev
-- Works with digall mod, but make sure it's deactivated before tunneling!

-- Version 0.7.0
-- Added test for fallable blocks in ceiling and replace them with cobblestone.
-- Fixed bug where I was digging from lower blocks to higher blocks.
-- Simplified and cleaned up tunneling code.

-- Version 0.6.0
-- Increased width and height of tunnel created.

-- based on compassgps 2.7 and compass 0.5

-- To the extent possible under law, the author(s) have dedicated all copyright and related
-- and neighboring rights to this software to the public domain worldwide. This software is
-- distributed without any warranty.

-- You should have received a copy of the CC0 Public Domain Dedication along with this
-- software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>. 

minetest.register_privilege("tunneling", {description = "Allow use of tunnelmaker tool"})

local activewidth=8 --until I can find some way to get it from minetest

minetest.register_globalstep(function(dtime)
    local players  = minetest.get_connected_players()
    for i,player in ipairs(players) do

        local gotatunnelmaker=false
        local wielded=false
        local activeinv=nil
        local stackidx=0
        --first check to see if the user has a tunnelmaker, because if they don't
        --there is no reason to waste time calculating bookmarks or spawnpoints.
        local wielded_item = player:get_wielded_item():get_name()
        if string.sub(wielded_item, 0, 12) == "tunnelmaker:" then
            --if the player is wielding a tunnelmaker, change the wielded image
            wielded=true
            stackidx=player:get_wield_index()
            gotatunnelmaker=true
        else
            --check to see if tunnelmaker is in active inventory
            if player:get_inventory() then
                --is there a way to only check the activewidth items instead of entire list?
                --problem being that arrays are not sorted in lua
                for i,stack in ipairs(player:get_inventory():get_list("main")) do
                    if i<=activewidth and string.sub(stack:get_name(), 0, 12) == "tunnelmaker:" then
                        activeinv=stack  --store the stack so we can update it later with new image
                        stackidx=i --store the index so we can add image at correct location
                        gotatunnelmaker=true
                        break
                    end --if i<=activewidth
                end --for loop
            end -- get_inventory
        end --if wielded else

        --don't mess with the rest of this if they don't have a tunnelmaker
        --update to remove legacy get_look_yaw function
        if gotatunnelmaker then
--            local pos = player:getpos()
--            local dir = player:get_look_yaw()
--            local angle_north = 0
--            local angle_dir = 90 - math.deg(dir)
--            local angle_relative = (angle_north - angle_dir) % 360
            local dir = player:get_look_horizontal()
            local angle_relative = math.deg(dir)
            local tunnelmaker_image = math.floor((angle_relative/22.5) + 0.5)%16

            --update tunnelmaker image to point at target
            if wielded then
                player:set_wielded_item("tunnelmaker:"..tunnelmaker_image)
            elseif activeinv then
                player:get_inventory():set_stack("main",stackidx,"tunnelmaker:"..tunnelmaker_image)
            end --if wielded elsif activin
        end --if gotatunnelmaker
    end --for i,player in ipairs(players)
end) -- register_globalstep

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
-- in minetest 0.5.0+, desert biomes will use desert_cobble
local add_ref = function(x, z, user, pointed_thing)
    local pos = vector.add(pointed_thing.under, {x=x, y=0, z=z})
    if not minetest.is_protected(pos, user) then
        if is_desert(pos) then
            minetest.set_node(pos, {name = "default:desert_cobble"})
        else
            minetest.set_node(pos, {name = "default:cobble"})
        end
    end
end

-- delete single node, including water, but not torches or air
-- test for air, since air is not diggable
-- update: don't dig advtrain track
local dig_single = function(x, y, z, user, pointed_thing)
    local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
    local name = minetest.get_node(pos).name
    local isAdvtrack = minetest.registered_nodes[name].groups.advtrains_track == 1
    if not minetest.is_protected(pos, user) then
        if string.match(name, "water") then
            minetest.set_node(pos, {name = "air"})
        elseif name ~= "air" and name ~= "default:torch_ceiling" and not isAdvtrack then
            minetest.node_dig(pos, minetest.get_node(pos), user)
        end
    end
end

-- add stone floor, if air or water or glass
-- in minetest 0.5.0+, desert biomes will use desert_stone
local replace_floor = function(x, y, z, user, pointed_thing)
    local pos = vector.add(pointed_thing.under, {x=x, y=0, z=z})
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
-- in minetest 0.5.0+, desert biomes will use desert_cobble
local replace_ceiling = function(x, y, z, user, pointed_thing)
    local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
    local ceiling = minetest.get_node(pos).name
    if (ceiling == "default:sand" or ceiling == "default:desert_sand" or ceiling == "default:silver_sand" or
            ceiling == "default:gravel") and not minetest.is_protected(pos, user) then
        if is_desert(pos) then
            minetest.set_node(pos, {name = "default:desert_cobble"})
        else
            minetest.set_node(pos, {name = "default:cobble"})
        end
    end
end

-- add torch
local add_light = function(spacing, user, pointed_thing)
    local pos = vector.add(pointed_thing.under, {x=0, y=5, z=0})
    local ceiling = minetest.get_node(vector.add(pos, {x=0, y=1, z=0})).name
    if (ceiling == "default:stone" or ceiling == "default:desert_stone") and
            minetest.get_node(pos).name == "air" and not minetest.is_protected(pos, user) and
            minetest.find_node_near(pos, spacing, {name = "default:torch_ceiling"}) == nil then
        minetest.set_node(pos, {name = "default:torch_ceiling"})
    end
end

-- build glass barrier to water
-- if node is water, replace with glass
local check_for_water = function(x, y, z, user, pointed_thing)
    local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
    if not minetest.is_protected(pos, user) then
        local name = minetest.get_node(pos).name
        if string.match(name, "water") then
            minetest.set_node(pos, {name = "default:glass"})
        end
    end
end

-- convenience function to call all the ceiling checks
local check_ceiling = function(x, y, z, user, pointed_thing)
    -- first check that ceiling isn't node that can fall
    replace_ceiling(x, y, z, user, pointed_thing)
    -- then make sure ceiling isn't water
    check_for_water(x, y, z, user, pointed_thing)
    -- check_for_water_stone(x, y, z, user, pointed_thing) --debug
end

-- add wall if necessary to protect from water (pink)
local aw = function(x, z, user, pointed_thing)
    for y=0, 5 do
        check_for_water(x, y, z, user, pointed_thing)
        -- check_for_water_stone(x, y, z, user, pointed_thing)  --debug
    end
end

-- add short endcap (light orange)
local es = function(x, z, user, pointed_thing)
    for y=0, 5 do
        check_for_water(x, y, z, user, pointed_thing)
        -- check_for_water_glass(x, y, z, user, pointed_thing)     --debug
    end
end

-- add tall endcap (darker orange)
local et = function(x, z, user, pointed_thing)
    for y=0, 6 do
        check_for_water(x, y, z, user, pointed_thing)
        -- check_for_water_glass(x, y, z, user, pointed_thing)     --debug
    end
end

-- dig short tunnel (light gray)
local ds = function(x, z, user, pointed_thing)
    local height = 4
    check_ceiling(x, height+1, z, user, pointed_thing)
    check_for_water(x, height+2, z, user, pointed_thing)
    -- check_for_water_stone(x, height+2, z, user, pointed_thing)  --debug
    for y=height, 1, -1 do          -- dig from high to low
        dig_single(x, y, z, user, pointed_thing)
    end
    check_for_water(x, 0, z, user, pointed_thing)
    -- check_for_water_stone(x, 0, z, user, pointed_thing) --debug
end

-- dig tall tunnel (light yellow)
local dt = function(x, z, user, pointed_thing)
    local height = 5
    check_ceiling(x, height+1, z, user, pointed_thing)
    for y=height, 1, -1 do          -- dig from high to low
        dig_single(x, y, z, user, pointed_thing)
    end
    replace_floor(x, 0, z, user, pointed_thing)
end

-- To shorten the code, this function takes a list of lists with {function, x-coord, y-coord} and executes them in sequence.
local run_list = function(dir_list, user, pointed_thing)
    for i,v in ipairs(dir_list) do
        v[1](v[2], v[3], user, pointed_thing)
    end
end

-- dig tunnel based on direction given
local dig_tunnel = function(cdir, user, pointed_thing)
    if minetest.check_player_privs(user, "tunneling") then
        if cdir == 0 then                                               -- pointed north
            run_list(   {{aw,-3, 0},{aw, 3, 0},{aw,-3, 1},
                         {aw, 3, 1},{aw,-3, 2},{aw, 3, 2},
                         {es,-3, 3},{et,-2, 3},{et,-1, 3},{et, 0, 3},{et, 1, 3},{et, 2, 3},{es, 3, 3},
                         {ds,-2, 0},{dt,-1, 0},{dt, 0, 0},{dt, 1, 0},{ds, 2, 0},
                         {ds,-2, 1},{dt,-1, 1},{dt, 0, 1},{dt, 1, 1},{ds, 2, 1},
                         {ds,-2, 2},{dt,-1, 2},{dt, 0, 2},{dt, 1, 2},{ds, 2, 2},
                         {add_ref,0,2}}, user, pointed_thing)
        elseif cdir == 1 then                                           -- pointed north-northwest
            run_list(   {{aw,-3,-1},{aw,-3, 0},{aw,-4, 0},{aw,-4, 1},{aw,-4, 2},
                         {aw, 3, 1},{aw, 3, 2},{aw, 2, 2},{aw, 2, 3},
                         {es,-4, 3},{et,-3, 3},{et,-2, 3},{et,-1, 3},{et, 0, 3},{et, 1, 3},
                         {ds,-2, 0},{dt,-1, 0},{dt, 0, 0},{dt, 1, 0},
                         {ds,-3, 1},{dt,-2, 1},{dt,-1, 1},{dt, 0, 1},{dt, 1, 1},{ds, 2, 1},
                         {ds,-3, 2},{dt,-2, 2},{dt,-1, 2},{dt, 0, 2},{ds, 1, 2},
                         {add_ref,-1, 2}}, user, pointed_thing)
        elseif cdir == 2 then                                           -- pointed northwest
            run_list(   {{aw,-2,-3},{aw,-2,-2},{aw,-3,-2},{aw,-3,-1},{aw,-3,-2},
                         {aw, 3, 2},{aw, 2, 2},{aw, 2, 3},{aw, 1, 3},{aw, 1, 4},
                         {es,-4, 0},{es,-4, 1},{et,-3, 1},{et,-2, 1},{et,-2, 2},{et,-1, 2},{et,-1, 3},{es,-1, 4},{es, 0, 4},
                         {ds,-1,-2},
                         {ds,-2,-1},{dt,-1,-1},
                         {ds,-3, 0},{dt,-2, 0},{dt,-1, 0},{dt, 0, 0},
                         {ds,-1, 1},{dt, 0, 1},{dt, 1, 1},{ds, 2, 1},
                         {dt, 0, 2},{ds, 1, 2},
                         {ds, 0, 3},
                         {add_ref,-1, 1}}, user, pointed_thing)
        elseif cdir == 3 then                                           -- pointed west-northwest
            run_list(   {{aw,-1,-3},{aw,-2,-3},{aw,-2,-2},{aw,-3,-2},
                         {aw, 1, 3},{aw, 0, 3},{aw, 0, 4},{aw,-1, 4},{aw,-2, 4},
                         {et,-3,-1},{et,-3, 0},{et,-3, 1},{et,-3, 2},{et,-3, 3},{es,-3, 4},
                         {ds,-1,-2},
                         {ds,-2,-1},{dt,-1,-1},{dt, 0,-1},
                         {dt,-2, 0},{dt,-1, 0},{dt, 0, 0},
                         {dt,-2, 1},{dt,-1, 1},{dt, 0, 1},
                         {dt,-2, 2},{dt,-1, 2},{ds, 0, 2},
                         {ds,-2, 3},{ds,-1, 3},
                         {add_ref,-2, 1}}, user, pointed_thing)
        elseif cdir == 4 then                                           -- pointed west
            run_list(   {{aw, 0,-3},{aw,-1,-3},{aw,-2,-3},
                         {aw, 0, 3},{aw,-1, 3},{aw,-2, 3},
                         {es,-3,-3},{et,-3,-2},{et,-3,-1},{et,-3, 0},{et,-3, 1},{et,-3, 2},{es,-3, 3},
                         {ds,-2,-2},{ds,-1,-2},{ds, 0,-2},
                         {dt,-2,-1},{dt,-1,-1},{dt, 0,-1},
                         {dt,-2, 0},{dt,-1, 0},{dt, 0, 0},
                         {dt,-2, 1},{dt,-1, 1},{dt, 0, 1},
                         {ds,-2, 2},{ds,-1, 2},{ds, 0, 2},
                         {add_ref,-2, 0}}, user, pointed_thing)
        elseif cdir == 5 then                                           -- pointed west-southwest
            run_list(   {{aw, 1,-3},{aw, 0,-3},{aw, 0,-4},{aw,-1,-4},{aw,-2,-4},
                         {aw,-1, 3},{aw,-2, 3},{aw,-2, 2},{aw,-3, 2},
                         {es,-3,-4},{et,-3,-3},{et,-3,-2},{et,-3,-1},{et,-3, 0},{et,-3, 1},
                         {ds,-2,-3},{ds,-1,-3},
                         {dt,-2,-2},{dt,-1,-2},{ds, 0,-2},
                         {dt,-2,-1},{dt,-1,-1},{dt, 0,-1},
                         {dt,-2, 0},{dt,-1, 0},{dt, 0, 0},
                         {ds,-2, 1},{dt,-1, 1},{dt, 0, 1},
                         {ds,-1, 2},
                         {add_ref,-2, -1}}, user, pointed_thing)
        elseif cdir == 6 then                                           -- pointed southwest
            run_list(   {{aw, 3,-2},{aw, 2,-2},{aw, 2,-3},{aw, 1,-3},{aw, 1,-4},
                         {aw,-2, 3},{aw,-2, 2},{aw,-3, 2},{aw,-3, 1},{aw,-4, 1},
                         {es, 0,-4},{es,-1,-4},{et,-1,-3},{et,-1,-2},{et,-2,-2},{et,-2,-1},{et,-3,-1},{es,-4,-1},{es,-4, 0},
                         {ds, 0,-3},
                         {dt, 0,-2},{ds, 1,-2},
                         {dt,-1,-1},{dt, 0,-1},{dt, 1,-1},{ds, 2,-1},
                         {ds,-3, 0},{dt,-2, 0},{dt,-1, 0},{dt, 0, 0},
                         {ds,-2, 1},{dt,-1, 1},
                         {ds,-1, 2},
                         {add_ref,-1, -1}}, user, pointed_thing)
        elseif cdir == 7 then                                           -- pointed south-southwest
            run_list(   {{aw, 3,-1},{aw, 3,-2},{aw, 2,-2},{aw, 2,-3},
                         {aw,-3, 1},{aw,-3, 0},{aw,-4, 0},{aw,-4,-1},{aw,-4,-2},
                         {et, 1,-3},{et, 0,-3},{et,-1,-3},{et,-2,-3},{et,-3,-3},{es,-4,-3},
                         {ds,-3,-2},{dt,-2,-2},{dt,-1,-2},{dt, 0,-2},{ds, 1,-2},
                         {ds,-3,-1},{dt,-2,-1},{dt,-1,-1},{dt, 0,-1},{dt, 1,-1},{ds, 2,-1},
                         {ds,-2, 0},{dt,-1, 0},{dt, 0, 0},{dt, 1, 0},
                         {add_ref,-1, -2}}, user, pointed_thing)
        elseif cdir == 8 then                                           -- pointed south
            run_list(   {{aw, 3, 0},{aw, 3,-1},{aw, 3,-2},
                         {aw,-3, 0},{aw,-3,-1},{aw,-3,-2},
                         {es, 3,-3},{et, 2,-3},{et, 1,-3},{et, 0,-3},{et,-1,-3},{et,-2,-3},{es,-3,-3},
                         {ds,-2,-2},{dt,-1,-2},{dt, 0,-2},{dt, 1,-2},{ds, 2,-2},
                         {ds,-2,-1},{dt,-1,-1},{dt, 0,-1},{dt, 1,-1},{ds, 2,-1},
                         {ds,-2, 0},{dt,-1, 0},{dt, 0, 0},{dt, 1, 0},{ds, 2, 0},
                         {add_ref,0, -2}}, user, pointed_thing)
        elseif cdir == 9 then                                           -- pointed south-southeast
            run_list(   {{aw, 3, 1},{aw, 3, 0},{aw, 4, 0},{aw, 4,-1},{aw, 4,-2},
                         {aw,-3,-1},{aw,-3,-2},{aw,-2,-2},{aw,-2,-3},
                         {es, 4,-3},{et, 3,-3},{et, 2,-3},{et, 1,-3},{et, 0,-3},{et,-1,-3},
                         {ds,-1,-2},{dt, 0,-2},{dt, 1,-2},{dt, 2,-2},{ds, 3,-2},
                         {ds,-2,-1},{dt,-1,-1},{dt, 0,-1},{dt, 1,-1},{dt, 2,-1},{ds, 3,-1},
                         {dt,-1, 0},{dt, 0, 0},{dt, 1, 0},{ds, 2, 0},
                         {add_ref,1, -2}}, user, pointed_thing)
        elseif cdir == 10 then                                          -- pointed southeast
            run_list(   {{aw, 2, 3},{aw, 2, 2},{aw, 3, 2},{aw, 3, 1},{aw, 4, 1},
                         {aw,-3,-2},{aw,-2,-2},{aw,-2,-3},{aw,-1,-3},{aw,-1,-4},
                         {es, 4, 0},{es, 4,-1},{et, 3,-1},{et, 2,-1},{et, 2,-2},{et, 1,-2},{et, 1,-3},{es, 1,-4},{es, 0,-4},
                         {ds, 0,-3},
                         {ds,-1,-2},{dt, 0,-2},
                         {ds,-2,-1},{dt,-1,-1},{dt, 0,-1},{dt, 1,-1},
                         {dt, 0, 0},{dt, 1, 0},{dt, 2, 0},{ds, 3, 0},
                         {dt, 1, 1},{ds, 2, 1},
                         {ds, 1, 2},
                         {add_ref,1, -1}}, user, pointed_thing)
        elseif cdir == 11 then                                          -- pointed east-southeast
            run_list(   {{aw, 1, 3},{aw, 2, 3},{aw, 2, 2},{aw, 3, 2},
                         {aw,-1,-3},{aw, 0,-3},{aw, 0,-4},{aw, 1,-4},{aw, 2,-4},
                         {et, 3, 1},{et, 3, 0},{et, 3,-1},{et, 3,-2},{et, 3,-3},{es, 3,-4},
                         {ds, 1,-3},{ds, 2,-3},
                         {ds, 0,-2},{dt, 1,-2},{dt, 2,-2},
                         {dt, 0,-1},{dt, 1,-1},{dt, 2,-1},
                         {dt, 0, 0},{dt, 1, 0},{dt, 2, 0},
                         {dt, 0, 1},{dt, 1, 1},{ds, 2, 1},
                         {ds, 1, 2},
                         {add_ref,2, -1}}, user, pointed_thing)
        elseif cdir == 12 then                                          -- pointed east
            run_list(   {{aw, 0, 3},{aw, 1, 3},{aw, 2, 3},
                         {aw, 0,-3},{aw, 1,-3},{aw, 2,-3},
                         {es, 3, 3},{et, 3, 2},{et, 3, 1},{et, 3, 0},{et, 3,-1},{et, 3,-2},{es, 3,-3},
                         {ds, 0,-2},{ds, 1,-2},{ds, 2,-2},
                         {dt, 0,-1},{dt, 1,-1},{dt, 2,-1},
                         {dt, 0, 0},{dt, 1, 0},{dt, 2, 0},
                         {dt, 0, 1},{dt, 1, 1},{dt, 2, 1},
                         {ds, 0, 2},{ds, 1, 2},{ds, 2, 2},
                         {add_ref,2, 0}}, user, pointed_thing)
        elseif cdir == 13 then                                          -- pointed east-northeast
            run_list(   {{aw,-1, 3},{aw, 0, 3},{aw, 0, 4},{aw, 1, 4},{aw, 2, 4},
                         {aw, 1,-3},{aw, 2,-3},{aw, 2,-2},{aw, 3,-2},
                         {es, 3, 4},{et, 3, 3},{et, 3, 2},{et, 3, 1},{et, 3, 0},{et, 3,-1},
                         {ds, 1,-2},
                         {dt, 0,-1},{dt, 1,-1},{ds, 2,-1},
                         {dt, 0, 0},{dt, 1, 0},{dt, 2, 0},
                         {dt, 0, 1},{dt, 1, 1},{dt, 2, 1},
                         {ds, 0, 2},{dt, 1, 2},{dt, 2, 2},
                         {ds, 1, 3},{ds, 2, 3},
                         {add_ref,2, 1}}, user, pointed_thing)
        elseif cdir == 14 then                                          -- pointed northeast
            run_list(   {{aw,-3, 2},{aw,-2, 2},{aw,-2, 3},{aw,-1, 3},{aw,-1, 4},
                         {aw, 2,-3},{aw, 2,-2},{aw, 3,-2},{aw, 3,-1},{aw, 4,-1},
                         {es, 0, 4},{es, 1, 4},{et, 1, 3},{et, 1, 2},{et, 2, 2},{et, 2, 1},{et, 3, 1},{es, 4, 1},{es, 4, 0},
                         {ds, 1,-2},
                         {dt, 1,-1},{ds, 2,-1},
                         {dt, 0, 0},{dt, 1, 0},{dt, 2, 0},{ds, 3, 0},
                         {ds,-2, 1},{dt,-1, 1},{dt, 0, 1},{dt, 1, 1},
                         {ds,-1, 2},{dt, 0, 2},
                         {ds, 0, 3},
                         {add_ref,1, 1}}, user, pointed_thing)
        elseif cdir == 15 then                                          -- pointed north-northeast
            run_list(   {{aw,-3, 1},{aw,-3, 2},{aw,-2, 2},{aw,-2, 3},
                         {aw, 3,-1},{aw, 3, 0},{aw, 4, 0},{aw, 4, 1},{aw, 4, 2},
                         {et,-1, 3},{et, 0, 3},{et, 1, 3},{et, 2, 3},{et, 3, 3},{es, 4, 3},
                         {dt,-1, 0},{dt, 0, 0},{dt, 1, 0},{ds, 2, 0},
                         {ds,-2, 1},{dt,-1, 1},{dt, 0, 1},{dt, 1, 1},{dt, 2, 1},{ds, 3, 1},
                         {ds,-1, 2},{dt, 0, 2},{dt, 1, 2},{dt, 2, 2},{ds, 3, 2},
                         {add_ref,  1, 2}}, user, pointed_thing)
        end
        add_light(2, user, pointed_thing)                       -- change to 1 for more frequent lights
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
        -- dig single node like wood pickaxe with left mouse click
        -- works in both regular and creative modes
        tool_capabilities = {
            full_punch_interval = 1.2,
            max_drop_level=0,
            groupcaps={
                cracky = {times={[3]=1.6}, maxlevel=1},
            },
            damage_groups = {fleshy=2},
        },

        -- dig tunnel with right mouse click (double tap on android)
        -- tunneling only works if in creative mode
        on_place = function(itemstack, placer, pointed_thing)
            local player_name = placer and placer:get_player_name() or ""
            local creative_enabled = (creative and creative.is_enabled_for
                            and creative.is_enabled_for(player_name))
            if creative_enabled and pointed_thing.type=="node" then
                -- if advtrains_track, I lower positions of pointed_thing to right below track, but keep name the same.
                local name = minetest.get_node(pointed_thing.under).name
                if minetest.registered_nodes[name].groups.advtrains_track == 1 then
                    pointed_thing.under = vector.add(pointed_thing.under, {x=0, y=-1, z=0})
                    pointed_thing.above = vector.add(pointed_thing.above, {x=0, y=-1, z=0})  -- don't currently use this
                end
                dig_tunnel(i-1, placer, pointed_thing)
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
