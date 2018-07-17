-- tunnelmaker
-- Another tunnel digging mod for minetest.
-- by David G (kestral246@gmail.com)

-- Version 0.9.4
-- Major update to build in support for digging up and down.
-- Digging up and down only supports orthogonal and 45deg directions to match advtrains track.
-- To select updown direction, hold sneak key (shift) while right-clicking tunnelmaker.
-- One click selects up (Yellow 'U' on icon), second click selects down (Yellow 'D' on icon),
-- third click returns back to horizontal (no letter on icon).
-- Updown state can also be reset by rotating to different icon, or moving by some amount (still tuning this).
-- Once updown state is selected, release sneak key and use right-click like normal.
-- After digging, updown state will also be reset to horizontal.

-- Version 0.9.3
-- Tweak cdir == 2 (nw) digging pattern.
-- Clean up some old debug statements.

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

-- Define a global variable to maintain per player state
tunnelmaker = {}

-- Initialize players global state on player join
minetest.register_on_joinplayer(function(player)
    local pname = player:get_player_name()
    tunnelmaker[pname] = {updown = 0, lastdir = -1, lastpos = {x = 0, y = 0, z = 0}}
end)

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
            local pname = player:get_player_name()
            local dir = player:get_look_horizontal()
            local angle_relative = math.deg(dir)
            local rawdir = math.floor((angle_relative/22.5) + 0.5)%16

            local distance2 = function(x, y, z)
                return x*x + y*y + z*z
            end

            local delta = distance2((player:getpos().x - tunnelmaker[pname].lastpos.x),
                                    (player:getpos().y - tunnelmaker[pname].lastpos.y),
                                    (player:getpos().z - tunnelmaker[pname].lastpos.z))
            
--            if rawdir ~= tunnelmaker[pname].lastdir or pos.x ~= tunnelmaker[pname].lastpos.x or pos.y ~= tunnelmaker[pname].lastpos.y or pos.z ~= tunnelmaker[pname].lastpos.z then

            -- If rotate to different direction, or move far enough from set position, reset to horizontal
            if rawdir ~= tunnelmaker[pname].lastdir or delta > 0.2 then -- tune to make distance moved feel right
                tunnelmaker[pname].lastdir = rawdir
                -- tunnelmaker[pname].lastpos = pos
                tunnelmaker[pname].updown = 0                           -- reset updown to horizontal
            end
            local tunnelmaker_image = rawdir                            -- horizontal digging maps to 0-15
            if tunnelmaker[pname].updown ~= 0 and rawdir % 2 == 0 then  -- only 0,45,90 are updown capable (U:16-23,D:24-31)
                tunnelmaker_image = 16 + (tunnelmaker[pname].updown - 1) * 8 + (rawdir / 2)
            end
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
-- in minetest 0.5.0+, desert biomes will use desert_cobble
local add_ref = function(x, y0, y1, z, user, pointed_thing)
    local pos = vector.add(pointed_thing.under, {x=x, y=y0, z=z})
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
    -- roof height can now be 5 or six so try again one higher
    pos = vector.add(pointed_thing.under, {x=0, y=6, z=0})
    ceiling = minetest.get_node(vector.add(pos, {x=0, y=1, z=0})).name
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
end

-- add wall if necessary to protect from water (pink)
local aw = function(x, y0, y1, z, user, pointed_thing)
    for y=y0, y1 do
        check_for_water(x, y, z, user, pointed_thing)
    end
end

-- add short endcap (light orange)
local es = function(x, y0, y1, z, user, pointed_thing)
    for y=y0, y1 do
        check_for_water(x, y, z, user, pointed_thing)
    end
end

-- add tall endcap (darker orange)
local et = function(x, y0, y1, z, user, pointed_thing)
    for y=y0, y1 do
        check_for_water(x, y, z, user, pointed_thing)
    end
end

-- dig short tunnel (light gray)
local ds = function(x, y0, y1, z, user, pointed_thing)
    local height = y1
    check_ceiling(x, height+1, z, user, pointed_thing)
    check_for_water(x, height+2, z, user, pointed_thing)
    -- add_ref(x, height+2, 0, z, user, pointed_thing)    -- debug debug
    for y=height, y0+1, -1 do          -- dig from high to low
        dig_single(x, y, z, user, pointed_thing)
    end
    check_for_water(x, y0, z, user, pointed_thing)
end

-- dig tall tunnel (light yellow)
local dt = function(x, y0, y1, z, user, pointed_thing)
    local height = y1
    check_ceiling(x, height+1, z, user, pointed_thing)
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
-- Dig horizontal
        if cdir == 0 then  -- pointed north
            run_list(   {{aw,-3, 0, 5, 0},{aw, 3, 0, 5, 0},{aw,-3, 0, 5, 1},
                         {aw, 3, 0, 5, 1},{aw,-3, 0, 5, 2},{aw, 3, 0, 5, 2},
                         {es,-3, 0, 5, 3},{et,-2, 0, 6, 3},{et,-1, 0, 6, 3},{et, 0, 0, 6, 3},{et, 1, 0, 6, 3},{et, 2, 0, 6, 3},{es, 3, 0, 5, 3},
                         {ds,-2, 0, 4, 0},{dt,-1, 0, 5, 0},{dt, 0, 0, 5, 0},{dt, 1, 0, 5, 0},{ds, 2, 0, 4, 0},
                         {ds,-2, 0, 4, 1},{dt,-1, 0, 5, 1},{dt, 0, 0, 5, 1},{dt, 1, 0, 5, 1},{ds, 2, 0, 4, 1},
                         {ds,-2, 0, 4, 2},{dt,-1, 0, 5, 2},{dt, 0, 0, 5, 2},{dt, 1, 0, 5, 2},{ds, 2, 0, 4, 2},
                         {add_ref, 0, 0, 0, 2}}, user, pointed_thing)
        elseif cdir == 1 then  -- pointed north-northwest
            run_list(   {{aw,-3, 0, 5,-1},{aw,-3, 0, 5, 0},{aw,-4, 0, 5, 0},{aw,-4, 0, 5, 1},{aw,-4, 0, 5, 2},
                         {aw, 3, 0, 5, 1},{aw, 3, 0, 5, 2},{aw, 2, 0, 5, 2},{aw, 2, 0, 5, 3},
                         {es,-4, 0, 5, 3},{et,-3, 0, 6, 3},{et,-2, 0, 6, 3},{et,-1, 0, 6, 3},{et, 0, 0, 6, 3},{et, 1, 0, 6, 3},
                         {ds,-2, 0, 4, 0},{dt,-1, 0, 5, 0},{dt, 0, 0, 5, 0},{dt, 1, 0, 5, 0},
                         {ds,-3, 0, 4, 1},{dt,-2, 0, 5, 1},{dt,-1, 0, 5, 1},{dt, 0, 0, 5, 1},{dt, 1, 0, 5, 1},{ds, 2, 0, 4, 1},
                         {ds,-3, 0, 4, 2},{dt,-2, 0, 5, 2},{dt,-1, 0, 5, 2},{dt, 0, 0, 5, 2},{ds, 1, 0, 4, 2},
                         {add_ref,-1, 0, 0, 2}}, user, pointed_thing)
        elseif cdir == 2 then  -- pointed northwest
            run_list(   {{aw,-2, 0, 5,-3},{aw,-2, 0, 5,-2},{aw,-3, 0, 5,-2},{aw,-3, 0, 5,-1},{aw,-3, 0, 5,-2},
                         {aw, 3, 0, 5, 2},{aw, 2, 0, 5, 2},{aw, 2, 0, 5, 3},{aw, 1, 0, 5, 3},{aw, 1, 0, 5, 4},
                         {es,-4, 0, 5, 0},{es,-4, 0, 5, 1},{et,-3, 0, 6, 1},{et,-2, 0, 6, 1},{et,-2, 0, 6, 2},{et,-1, 0, 6, 2},{et,-1, 0, 6, 3},{es,-1, 0, 5, 4},{es, 0, 0, 5, 4},
                         {ds,-1, 0, 4,-2},
                         {ds,-2, 0, 4,-1},{dt,-1, 0, 5,-1},
                         {ds,-3, 0, 4, 0},{dt,-2, 0, 5, 0},{dt,-1, 0, 5, 0},{dt, 0, 0, 5, 0},
                         {dt,-1, 0, 5, 1},{dt, 0, 0, 5, 1},{dt, 1, 0, 5, 1},{ds, 2, 0, 4, 1},
                         {dt, 0, 0, 5, 2},{ds, 1, 0, 4, 2},
                         {ds, 0, 0, 4, 3},
                         {add_ref,-1, 0, 0, 1}}, user, pointed_thing)
        elseif cdir == 3 then  -- pointed west-northwest
            run_list(   {{aw,-1, 0, 5,-3},{aw,-2, 0, 5,-3},{aw,-2, 0, 5,-2},{aw,-3, 0, 5,-2},
                         {aw, 1, 0, 5, 3},{aw, 0, 0, 5, 3},{aw, 0, 0, 5, 4},{aw,-1, 0, 5, 4},{aw,-2, 0, 5, 4},
                         {et,-3, 0, 6,-1},{et,-3, 0, 6, 0},{et,-3, 0, 6, 1},{et,-3, 0, 6, 2},{et,-3, 0, 6, 3},{es,-3, 0, 5, 4},
                         {ds,-1, 0, 4,-2},
                         {ds,-2, 0, 4,-1},{dt,-1, 0, 5,-1},{dt, 0, 0, 5,-1},
                         {dt,-2, 0, 5, 0},{dt,-1, 0, 5, 0},{dt, 0, 0, 5, 0},
                         {dt,-2, 0, 5, 1},{dt,-1, 0, 5, 1},{dt, 0, 0, 5, 1},
                         {dt,-2, 0, 5, 2},{dt,-1, 0, 5, 2},{ds, 0, 0, 4, 2},
                         {ds,-2, 0, 4, 3},{ds,-1, 0, 4, 3},
                         {add_ref,-2, 0, 0, 1}}, user, pointed_thing)
        elseif cdir == 4 then  -- pointed west
            run_list(   {{aw, 0, 0, 5,-3},{aw,-1, 0, 5,-3},{aw,-2, 0, 5,-3},
                         {aw, 0, 0, 5, 3},{aw,-1, 0, 5, 3},{aw,-2, 0, 5, 3},
                         {es,-3, 0, 5,-3},{et,-3, 0, 6,-2},{et,-3, 0, 6,-1},{et,-3, 0, 6, 0},{et,-3, 0, 6, 1},{et,-3, 0, 6, 2},{es,-3, 0, 5, 3},
                         {ds,-2, 0, 4,-2},{ds,-1, 0, 4,-2},{ds, 0, 0, 4,-2},
                         {dt,-2, 0, 5,-1},{dt,-1, 0, 5,-1},{dt, 0, 0, 5,-1},
                         {dt,-2, 0, 5, 0},{dt,-1, 0, 5, 0},{dt, 0, 0, 5, 0},
                         {dt,-2, 0, 5, 1},{dt,-1, 0, 5, 1},{dt, 0, 0, 5, 1},
                         {ds,-2, 0, 4, 2},{ds,-1, 0, 4, 2},{ds, 0, 0, 4, 2},
                         {add_ref,-2, 0, 0, 0}}, user, pointed_thing)
        elseif cdir == 5 then  -- pointed west-southwest
            run_list(   {{aw, 1, 0, 5,-3},{aw, 0, 0, 5,-3},{aw, 0, 0, 5,-4},{aw,-1, 0, 5,-4},{aw,-2, 0, 5,-4},
                         {aw,-1, 0, 5, 3},{aw,-2, 0, 5, 3},{aw,-2, 0, 5, 2},{aw,-3, 0, 5, 2},
                         {es,-3, 0, 5,-4},{et,-3, 0, 6,-3},{et,-3, 0, 6,-2},{et,-3, 0, 6,-1},{et,-3, 0, 6, 0},{et,-3, 0, 6, 1},
                         {ds,-2, 0, 4,-3},{ds,-1, 0, 4,-3},
                         {dt,-2, 0, 5,-2},{dt,-1, 0, 5,-2},{ds, 0, 0, 4,-2},
                         {dt,-2, 0, 5,-1},{dt,-1, 0, 5,-1},{dt, 0, 0, 5,-1},
                         {dt,-2, 0, 5, 0},{dt,-1, 0, 5, 0},{dt, 0, 0, 5, 0},
                         {ds,-2, 0, 4, 1},{dt,-1, 0, 5, 1},{dt, 0, 0, 5, 1},
                         {ds,-1, 0, 4, 2},
                         {add_ref,-2, 0, 0,-1}}, user, pointed_thing)
        elseif cdir == 6 then  -- pointed southwest
            run_list(   {{aw, 3, 0, 5,-2},{aw, 2, 0, 5,-2},{aw, 2, 0, 5,-3},{aw, 1, 0, 5,-3},{aw, 1, 0, 5,-4},
                         {aw,-2, 0, 5, 3},{aw,-2, 0, 5, 2},{aw,-3, 0, 5, 2},{aw,-3, 0, 5, 1},{aw,-4, 0, 5, 1},
                         {es, 0, 0, 5,-4},{es,-1, 0, 5,-4},{et,-1, 0, 6,-3},{et,-1, 0, 6,-2},{et,-2, 0, 6,-2},{et,-2, 0, 6,-1},{et,-3, 0, 6,-1},{es,-4, 0, 5,-1},{es,-4, 0, 5, 0},
                         {ds, 0, 0, 4,-3},
                         {dt, 0, 0, 5,-2},{ds, 1, 0, 4,-2},
                         {dt,-1, 0, 5,-1},{dt, 0, 0, 5,-1},{dt, 1, 0, 5,-1},{ds, 2, 0, 4,-1},
                         {ds,-3, 0, 4, 0},{dt,-2, 0, 5, 0},{dt,-1, 0, 5, 0},{dt, 0, 0, 5, 0},
                         {ds,-2, 0, 4, 1},{dt,-1, 0, 5, 1},
                         {ds,-1, 0, 4, 2},
                         {add_ref,-1, 0, 0,-1}}, user, pointed_thing)
        elseif cdir == 7 then  -- pointed south-southwest
            run_list(   {{aw, 3, 0, 5,-1},{aw, 3, 0, 5,-2},{aw, 2, 0, 5,-2},{aw, 2, 0, 5,-3},
                         {aw,-3, 0, 5, 1},{aw,-3, 0, 5, 0},{aw,-4, 0, 5, 0},{aw,-4, 0, 5,-1},{aw,-4, 0, 5,-2},
                         {et, 1, 0, 6,-3},{et, 0, 0, 6,-3},{et,-1, 0, 6, -3},{et,-2, 0, 6,-3},{et,-3, 0, 6,-3},{es,-4, 0, 5,-3},
                         {ds,-3, 0, 4,-2},{dt,-2, 0, 5,-2},{dt,-1, 0, 5,-2},{dt, 0, 0, 5,-2},{ds, 1, 0, 4,-2},
                         {ds,-3, 0, 4,-1},{dt,-2, 0, 5,-1},{dt,-1, 0, 5,-1},{dt, 0, 0, 5,-1},{dt, 1, 0, 5,-1},{ds, 2, 0, 4,-1},
                         {ds,-2, 0, 4, 0},{dt,-1, 0, 5, 0},{dt, 0, 0, 5, 0},{dt, 1, 0, 5, 0},
                         {add_ref,-1, 0, 0,-2}}, user, pointed_thing)
        elseif cdir == 8 then  -- pointed south
            run_list(   {{aw, 3, 0, 5, 0},{aw, 3, 0, 5,-1},{aw, 3, 0, 5,-2},
                         {aw,-3, 0, 5, 0},{aw,-3, 0, 5,-1},{aw,-3, 0, 5,-2},
                         {es, 3, 0, 5,-3},{et, 2, 0, 6,-3},{et, 1, 0, 6,-3},{et, 0, 0, 6,-3},{et,-1, 0, 6,-3},{et,-2, 0, 6,-3},{es,-3, 0, 5,-3},
                         {ds,-2, 0, 4,-2},{dt,-1, 0, 5,-2},{dt, 0, 0, 5,-2},{dt, 1, 0, 5,-2},{ds, 2, 0, 4,-2},
                         {ds,-2, 0, 4,-1},{dt,-1, 0, 5,-1},{dt, 0, 0, 5,-1},{dt, 1, 0, 5,-1},{ds, 2, 0, 4,-1},
                         {ds,-2, 0, 4, 0},{dt,-1, 0, 5, 0},{dt, 0, 0, 5, 0},{dt, 1, 0, 5, 0},{ds, 2, 0, 4, 0},
                         {add_ref,0, 0, 0,-2}}, user, pointed_thing)
        elseif cdir == 9 then  -- pointed south-southeast
            run_list(   {{aw, 3, 0, 5, 1},{aw, 3, 0, 5, 0},{aw, 4, 0, 5, 0},{aw, 4, 0, 5,-1},{aw, 4, 0, 5,-2},
                         {aw,-3, 0, 5,-1},{aw,-3, 0, 5,-2},{aw,-2, 0, 5,-2},{aw,-2, 0, 5,-3},
                         {es, 4, 0, 5,-3},{et, 3, 0, 6,-3},{et, 2, 0, 6,-3},{et, 1, 0, 6,-3},{et, 0, 0, 6,-3},{et,-1, 0, 6,-3},
                         {ds,-1, 0, 4,-2},{dt, 0, 0, 5,-2},{dt, 1, 0, 5,-2},{dt, 2, 0, 5,-2},{ds, 3, 0, 4,-2},
                         {ds,-2, 0, 4,-1},{dt,-1, 0, 5,-1},{dt, 0, 0, 5,-1},{dt, 1, 0, 5,-1},{dt, 2, 0, 5,-1},{ds, 3, 0, 4,-1},
                         {dt,-1, 0, 5, 0},{dt, 0, 0, 5, 0},{dt, 1, 0, 5, 0},{ds, 2, 0, 4, 0},
                         {add_ref,1, 0, 0,-2}}, user, pointed_thing)
        elseif cdir == 10 then  -- pointed southeast
            run_list(   {{aw, 2, 0, 5, 3},{aw, 2, 0, 5, 2},{aw, 3, 0, 5, 2},{aw, 3, 0, 5, 1},{aw, 4, 0, 5, 1},
                         {aw,-3, 0, 5,-2},{aw,-2, 0, 5,-2},{aw,-2, 0, 5,-3},{aw,-1, 0, 5,-3},{aw,-1, 0, 5,-4},
                         {es, 4, 0, 5, 0},{es, 4, 0, 5,-1},{et, 3, 0, 6,-1},{et, 2, 0, 6,-1},{et, 2, 0, 6,-2},{et, 1, 0, 6,-2},{et, 1, 0, 6,-3},{es, 1, 0, 5,-4},{es, 0, 0, 5,-4},
                         {ds, 0, 0, 4,-3},
                         {ds,-1, 0, 4,-2},{dt, 0, 0, 5,-2},
                         {ds,-2, 0, 4,-1},{dt,-1, 0, 5,-1},{dt, 0, 0, 5,-1},{dt, 1, 0, 5,-1},
                         {dt, 0, 0, 5, 0},{dt, 1, 0, 5, 0},{dt, 2, 0, 5, 0},{ds, 3, 0, 4, 0},
                         {dt, 1, 0, 5, 1},{ds, 2, 0, 4, 1},
                         {ds, 1, 0, 4, 2},
                         {add_ref, 1, 0, 0,-1}}, user, pointed_thing)
        elseif cdir == 11 then  -- pointed east-southeast
            run_list(   {{aw, 1, 0, 5, 3},{aw, 2, 0, 5, 3},{aw, 2, 0, 5, 2},{aw, 3, 0, 5, 2},
                         {aw,-1, 0, 5,-3},{aw, 0, 0, 5,-3},{aw, 0, 0, 5,-4},{aw, 1, 0, 5,-4},{aw, 2, 0, 5,-4},
                         {et, 3, 0, 6, 1},{et, 3, 0, 6, 0},{et, 3, 0, 6,-1},{et, 3, 0, 6,-2},{et, 3, 0, 6,-3},{es, 3, 0, 5,-4},
                         {ds, 1, 0, 4,-3},{ds, 2, 0, 4,-3},
                         {ds, 0, 0, 4,-2},{dt, 1, 0, 5,-2},{dt, 2, 0, 5,-2},
                         {dt, 0, 0, 5,-1},{dt, 1, 0, 5,-1},{dt, 2, 0, 5,-1},
                         {dt, 0, 0, 5, 0},{dt, 1, 0, 5, 0},{dt, 2, 0, 5, 0},
                         {dt, 0, 0, 5, 1},{dt, 1, 0, 5, 1},{ds, 2, 0, 4, 1},
                         {ds, 1, 0, 4, 2},
                         {add_ref, 2, 0, 0,-1}}, user, pointed_thing)
        elseif cdir == 12 then  -- pointed east
            run_list(   {{aw, 0, 0, 5, 3},{aw, 1, 0, 5, 3},{aw, 2, 0, 5, 3},
                         {aw, 0, 0, 5,-3},{aw, 1, 0, 5,-3},{aw, 2, 0, 5,-3},
                         {es, 3, 0, 5, 3},{et, 3, 0, 6, 2},{et, 3, 0, 6, 1},{et, 3, 0, 6, 0},{et, 3, 0, 6,-1},{et, 3, 0, 6,-2},{es, 3, 0, 5,-3},
                         {ds, 0, 0, 4,-2},{ds, 1, 0, 4,-2},{ds, 2, 0, 4,-2},
                         {dt, 0, 0, 5,-1},{dt, 1, 0, 5,-1},{dt, 2, 0, 5,-1},
                         {dt, 0, 0, 5, 0},{dt, 1, 0, 5, 0},{dt, 2, 0, 5, 0},
                         {dt, 0, 0, 5, 1},{dt, 1, 0, 5, 1},{dt, 2, 0, 5, 1},
                         {ds, 0, 0, 4, 2},{ds, 1, 0, 4, 2},{ds, 2, 0, 4, 2},
                         {add_ref, 2, 0, 0, 0}}, user, pointed_thing)
        elseif cdir == 13 then  -- pointed east-northeast
            run_list(   {{aw,-1, 0, 5, 3},{aw, 0, 0, 5, 3},{aw, 0, 0, 5, 4},{aw, 1, 0, 5, 4},{aw, 2, 0, 5, 4},
                         {aw, 1, 0, 5,-3},{aw, 2, 0, 5,-3},{aw, 2, 0, 5,-2},{aw, 3, 0, 5,-2},
                         {es, 3, 0, 5, 4},{et, 3, 0, 6, 3},{et, 3, 0, 6, 2},{et, 3, 0, 6, 1},{et, 3, 0, 6, 0},{et, 3, 0, 6,-1},
                         {ds, 1, 0, 4,-2},
                         {dt, 0, 0, 5,-1},{dt, 1, 0, 5,-1},{ds, 2, 0, 4,-1},
                         {dt, 0, 0, 5, 0},{dt, 1, 0, 5, 0},{dt, 2, 0, 5, 0},
                         {dt, 0, 0, 5, 1},{dt, 1, 0, 5, 1},{dt, 2, 0, 5, 1},
                         {ds, 0, 0, 4, 2},{dt, 1, 0, 5, 2},{dt, 2, 0, 5, 2},
                         {ds, 1, 0, 4, 3},{ds, 2, 0, 4, 3},
                         {add_ref, 2, 0, 0, 1}}, user, pointed_thing)
        elseif cdir == 14 then  -- pointed northeast
            run_list(   {{aw,-3, 0, 5, 2},{aw,-2, 0, 5, 2},{aw,-2, 0, 5, 3},{aw,-1, 0, 5, 3},{aw,-1, 0, 5, 4},
                         {aw, 2, 0, 5,-3},{aw, 2, 0, 5,-2},{aw, 3, 0, 5,-2},{aw, 3, 0, 5,-1},{aw, 4, 0, 5,-1},
                         {es, 0, 0, 5, 4},{es, 1, 0, 5, 4},{et, 1, 0, 6, 3},{et, 1, 0, 6, 2},{et, 2, 0, 6, 2},{et, 2, 0, 6, 1},{et, 3, 0, 6, 1},{es, 4, 0, 5, 1},{es, 4, 0, 5, 0},
                         {ds, 1, 0, 4,-2},
                         {dt, 1, 0, 5,-1},{ds, 2, 0, 4,-1},
                         {dt, 0, 0, 5, 0},{dt, 1, 0, 5, 0},{dt, 2, 0, 5, 0},{ds, 3, 0, 4, 0},
                         {ds,-2, 0, 4, 1},{dt,-1, 0, 5, 1},{dt, 0, 0, 5, 1},{dt, 1, 0, 5, 1},
                         {ds,-1, 0, 4, 2},{dt, 0, 0, 5, 2},
                         {ds, 0, 0, 4, 3},
                         {add_ref, 1, 0, 0, 1}}, user, pointed_thing)
        elseif cdir == 15 then  -- pointed north-northeast
            run_list(   {{aw,-3, 0, 5, 1},{aw,-3, 0, 5, 2},{aw,-2, 0, 5, 2},{aw,-2, 0, 5, 3},
                         {aw, 3, 0, 5,-1},{aw, 3, 0, 5, 0},{aw, 4, 0, 5, 0},{aw, 4, 0, 5, 1},{aw, 4, 0, 5, 2},
                         {et,-1, 0, 6, 3},{et, 0, 0, 6, 3},{et, 1, 0, 6, 3},{et, 2, 0, 6, 3},{et, 3, 0, 6, 3},{es, 4, 0, 5, 3},
                         {dt,-1, 0, 5, 0},{dt, 0, 0, 5, 0},{dt, 1, 0, 5, 0},{ds, 2, 0, 4, 0},
                         {ds,-2, 0, 4, 1},{dt,-1, 0, 5, 1},{dt, 0, 0, 5, 1},{dt, 1, 0, 5, 1},{dt, 2, 0, 5, 1},{ds, 3, 0, 4, 1},
                         {ds,-1, 0, 4, 2},{dt, 0, 0, 5, 2},{dt, 1, 0, 5, 2},{dt, 2, 0, 5, 2},{ds, 3, 0, 4, 2},
                         {add_ref, 1, 0, 0, 2}}, user, pointed_thing)

-- Dig up
        elseif cdir == 16 then  -- pointed north (0, dig up)
            run_list(   {{aw,-3, 0, 5, 0},{aw, 3, 0, 5, 0},{aw,-3, 0, 6, 1},
                         {aw, 3, 0, 6, 1},{aw,-3, 1, 6, 2},{aw, 3, 1, 6, 2},
                         {es,-3, 1, 6, 3},{et,-2, 1, 7, 3},{et,-1, 1, 7, 3},{et, 0, 1, 7, 3},{et, 1, 1, 7, 3},{et, 2, 1, 7, 3},{es, 3, 1, 6, 3},
                         {ds,-2, 0, 4, 0},{dt,-1, 0, 5, 0},{dt, 0, 0, 5, 0},{dt, 1, 0, 5, 0},{ds, 2, 0, 4, 0},
                         {ds,-2, 0, 5, 1},{dt,-1, 0, 6, 1},{dt, 0, 0, 6, 1},{dt, 1, 0, 6, 1},{ds, 2, 0, 5, 1},
                         {ds,-2, 1, 5, 2},{dt,-1, 1, 6, 2},{dt, 0, 1, 6, 2},{dt, 1, 1, 6, 2},{ds, 2, 1, 5, 2},
                         {add_ref, 0, 1, 0, 2},
                         {add_ref,-1, 0, 0, 2},  -- bridge support (left and right of nextref)
                         {add_ref, 1, 0, 0, 2}}, user, pointed_thing) 
        elseif cdir == 17 then  -- pointed northwest (2, dig up)
            run_list(   {{aw,-2, 0, 5,-3},{aw,-2, 0, 6,-2},{aw,-3, 0, 6,-2},{aw,-3, 0, 6,-1},{aw,-3, 1, 6,-2},
                         {aw, 3, 0, 5, 2},{aw, 2, 0, 6, 2},{aw, 2, 0, 6, 3},{aw, 1, 0, 6, 3},{aw, 1, 1, 6, 4},
                         {es,-4, 1, 6, 0},{es,-4, 1, 6, 1},{et,-3, 1, 7, 1},{et,-2, 1, 7, 1},{et,-2, 1, 7, 2},{et,-1, 1, 7, 2},{et,-1, 1, 7, 3},{es,-1, 1, 6, 4},{es, 0, 1, 6, 4},
                         {ds,-1, 0, 4,-2},
                         {ds,-2, 0, 5,-1},{dt,-1, 0, 5,-1},
                         {ds,-3, 1, 5, 0},{dt,-2, 1, 6, 0},{dt,-1, 0, 6, 0},{dt, 0, 0, 6, 0},
                         {dt,-1, 1, 6, 1},{dt, 0, 0, 6, 1},{dt, 1, 0, 5, 1},{ds, 2, 0, 4, 1},
                         {dt, 0, 1, 6, 2},{ds, 1, 0, 5, 2},
                         {ds, 0, 1, 5, 3},
                         {add_ref,-1, 1, 0, 1},
                         {add_ref,-2, 0, 0, 0},  -- bridge support (left and right of nextref)
                         {add_ref, 0, 0, 0, 2}}, user, pointed_thing)
        elseif cdir == 18 then  -- pointed west (4, dig up)
            run_list(   {{aw, 0, 0, 5,-3},{aw,-1, 0, 6,-3},{aw,-2, 0, 6,-3},
                         {aw, 0, 0, 5, 3},{aw,-1, 0, 6, 3},{aw,-2, 0, 6, 3},
                         {es,-3, 1, 6,-3},{et,-3, 1, 7,-2},{et,-3, 1, 7,-1},{et,-3, 1, 7, 0},{et,-3, 1, 7, 1},{et,-3, 1, 7, 2},{es,-3, 1, 6, 3},
                         {ds,-2, 1, 5,-2},{ds,-1, 0, 5,-2},{ds, 0, 0, 4,-2},
                         {dt,-2, 1, 6,-1},{dt,-1, 0, 6,-1},{dt, 0, 0, 5,-1},
                         {dt,-2, 1, 6, 0},{dt,-1, 0, 6, 0},{dt, 0, 0, 5, 0},
                         {dt,-2, 1, 6, 1},{dt,-1, 0, 6, 1},{dt, 0, 0, 5, 1},
                         {ds,-2, 1, 5, 2},{ds,-1, 0, 5, 2},{ds, 0, 0, 4, 2},
                         {add_ref,-2, 1, 0, 0},
                         {add_ref,-2, 0, 0,-1},  -- bridge support (left and right of nextref)
                         {add_ref,-2, 0, 0, 1}}, user, pointed_thing) 

        elseif cdir == 19 then  -- pointed southwest (6, dig up)
            run_list(   {{aw, 3, 0, 5,-2},{aw, 2, 0, 6,-2},{aw, 2, 0, 6,-3},{aw, 1, 0, 6,-3},{aw, 1, 1, 6,-4},
                         {aw,-2, 0, 5, 3},{aw,-2, 0, 6, 2},{aw,-3, 0, 6, 2},{aw,-3, 0, 6, 1},{aw,-4, 1, 6, 1},
                         {es, 0, 1, 6,-4},{es,-1, 1, 6,-4},{et,-1, 1, 7,-3},{et,-1, 1, 7,-2},{et,-2, 1, 7,-2},{et,-2, 1, 7,-1},{et,-3, 1, 7,-1},{es,-4, 1, 6,-1},{es,-4, 1, 6, 0},
                         {ds, 0, 1, 5,-3},
                         {dt, 0, 1, 6,-2},{ds, 1, 0, 5,-2},
                         {dt,-1, 1, 6,-1},{dt, 0, 0, 6,-1},{dt, 1, 0, 5,-1},{ds, 2, 0, 4,-1},
                         {ds,-3, 1, 5, 0},{dt,-2, 1, 6, 0},{dt,-1, 0, 6, 0},{dt, 0, 0, 6, 0},
                         {ds,-2, 0, 5, 1},{dt,-1, 0, 5, 1},
                         {ds,-1, 0, 4, 2},
                         {add_ref,-1, 1, 0,-1},
                         {add_ref,-2, 0, 0, 0},  -- bridge support (left and right of nextref)
                         {add_ref, 0, 0, 0,-2}}, user, pointed_thing) 

        elseif cdir == 20 then  -- pointed south (8, dig up)
            run_list(   {{aw, 3, 0, 5, 0},{aw, 3, 0, 6,-1},{aw, 3, 0, 6,-2},
                         {aw,-3, 0, 5, 0},{aw,-3, 0, 6,-1},{aw,-3, 0, 6,-2},
                         {es, 3, 1, 6,-3},{et, 2, 1, 7,-3},{et, 1, 1, 7,-3},{et, 0, 1, 7,-3},{et,-1, 1, 7,-3},{et,-2, 1, 7,-3},{es,-3, 1, 6,-3},
                         {ds,-2, 1, 5,-2},{dt,-1, 1, 6,-2},{dt, 0, 1, 6,-2},{dt, 1, 1, 6,-2},{ds, 2, 1, 5,-2},
                         {ds,-2, 0, 5,-1},{dt,-1, 0, 6,-1},{dt, 0, 0, 6,-1},{dt, 1, 0, 6,-1},{ds, 2, 0, 6,-1},
                         {ds,-2, 0, 4, 0},{dt,-1, 0, 5, 0},{dt, 0, 0, 5, 0},{dt, 1, 0, 5, 0},{ds, 2, 0, 4, 0},
                         {add_ref,0, 1, 0,-2},
                         {add_ref,-1, 0, 0,-2},  -- bridge support (left and right of nextref)
                         {add_ref, 1, 0, 0,-2}}, user, pointed_thing) 

        elseif cdir == 21 then  -- pointed southeast (10, dig up)
            run_list(   {{aw, 2, 0, 5, 3},{aw, 2, 0, 6, 2},{aw, 3, 0, 6, 2},{aw, 3, 0, 6, 1},{aw, 4, 1, 6, 1},
                         {aw,-3, 0, 5,-2},{aw,-2, 0, 6,-2},{aw,-2, 0, 6,-3},{aw,-1, 0, 6,-3},{aw,-1, 1, 6,-4},
                         {es, 4, 1, 6, 0},{es, 4, 1, 6,-1},{et, 3, 1, 7,-1},{et, 2, 1, 7,-1},{et, 2, 1, 7,-2},{et, 1, 1, 7,-2},{et, 1, 1, 7,-3},{es, 1, 1, 6,-4},{es, 0, 1, 6,-4},
                         {ds, 0, 1, 5,-3},
                         {ds,-1, 0, 5,-2},{dt, 0, 1, 6,-2},
                         {ds,-2, 0, 4,-1},{dt,-1, 0, 5,-1},{dt, 0, 0, 6,-1},{dt, 1, 1, 6,-1},
                         {dt, 0, 0, 6, 0},{dt, 1, 0, 6, 0},{dt, 2, 1, 6, 0},{ds, 3, 1, 5, 0},
                         {dt, 1, 0, 5, 1},{ds, 2, 0, 5, 1},
                         {ds, 1, 0, 4, 2},
                         {add_ref, 1, 1, 0,-1},
                         {add_ref, 2, 0, 0, 0},  -- bridge support (left and right of nextref)
                         {add_ref, 0, 0, 0,-2}}, user, pointed_thing) 

        elseif cdir == 22 then  -- pointed east (12, dig up)
            run_list(   {{aw, 0, 0, 5, 3},{aw, 1, 0, 6, 3},{aw, 2, 0, 6, 3},
                         {aw, 0, 0, 5,-3},{aw, 1, 0, 6,-3},{aw, 2, 0, 6,-3},
                         {es, 3, 1, 6, 3},{et, 3, 1, 7, 2},{et, 3, 1, 7, 1},{et, 3, 1, 7, 0},{et, 3, 1, 7,-1},{et, 3, 1, 7,-2},{es, 3, 1, 6,-3},
                         {ds, 0, 0, 4,-2},{ds, 1, 0, 5,-2},{ds, 2, 1, 5,-2},
                         {dt, 0, 0, 5,-1},{dt, 1, 0, 6,-1},{dt, 2, 1, 6,-1},
                         {dt, 0, 0, 5, 0},{dt, 1, 0, 6, 0},{dt, 2, 1, 6, 0},
                         {dt, 0, 0, 5, 1},{dt, 1, 0, 6, 1},{dt, 2, 1, 6, 1},
                         {ds, 0, 0, 4, 2},{ds, 1, 0, 5, 2},{ds, 2, 1, 5, 2},
                         {add_ref, 2, 1, 0, 0},
                         {add_ref, 2, 0, 0, 1},  -- bridge support (left and right of nextref)
                         {add_ref, 2, 0, 0,-1}}, user, pointed_thing) 

        elseif cdir == 23 then  -- pointed northeast (14, dig up)
            run_list(   {{aw,-3, 0, 5, 2},{aw,-2, 0, 6, 2},{aw,-2, 0, 6, 3},{aw,-1, 0, 6, 3},{aw,-1, 1, 6, 4},
                         {aw, 2, 0, 5,-3},{aw, 2, 0, 6,-2},{aw, 3, 0, 6,-2},{aw, 3, 0, 6,-1},{aw, 4, 1, 6,-1},
                         {es, 0, 1, 6, 4},{es, 1, 1, 6, 4},{et, 1, 1, 7, 3},{et, 1, 1, 7, 2},{et, 2, 1, 7, 2},{et, 2, 1, 7, 1},{et, 3, 1, 7, 1},{es, 4, 1, 6, 1},{es, 4, 1, 6, 0},
                         {ds, 1, 0, 4,-2},
                         {dt, 1, 0, 5,-1},{ds, 2, 0, 5,-1},
                         {dt, 0, 0, 6, 0},{dt, 1, 0, 6, 0},{dt, 2, 1, 6, 0},{ds, 3, 1, 5, 0},
                         {ds,-2, 0, 4, 1},{dt,-1, 0, 5, 1},{dt, 0, 0, 6, 1},{dt, 1, 1, 6, 1},
                         {ds,-1, 0, 5, 2},{dt, 0, 1, 6, 2},
                         {ds, 0, 1, 5, 3},
                         {add_ref, 1, 1, 0, 1},
                         {add_ref, 0, 0, 0, 2},  -- bridge support (left and right of nextref)
                         {add_ref, 2, 0, 0, 0}}, user, pointed_thing) 

-- Dig down
        elseif cdir == 24 then  -- pointed north (0, dig down)
            run_list(   {{aw,-3, 0, 5, 0},{aw, 3, 0, 5, 0},{aw,-3,-1, 5, 1},
                         {aw, 3,-1, 5, 1},{aw,-3,-1, 4, 2},{aw, 3,-1, 4, 2},
                         {es,-3,-1, 4, 3},{et,-2,-1, 5, 3},{et,-1,-1, 5, 3},{et, 0,-1, 5, 3},{et, 1,-1, 5, 3},{et, 2,-1, 5, 3},{es, 3,-1, 4, 3},
                         {ds,-2, 0, 4, 0},{dt,-1, 0, 5, 0},{dt, 0, 0, 5, 0},{dt, 1, 0, 5, 0},{ds, 2, 0, 4, 0},
                         {ds,-2,-1, 4, 1},{dt,-1,-1, 5, 1},{dt, 0,-1, 5, 1},{dt, 1,-1, 5, 1},{ds, 2,-1, 4, 1},
                         {ds,-2,-1, 3, 2},{dt,-1,-1, 4, 2},{dt, 0,-1, 4, 2},{dt, 1,-1, 4, 2},{ds, 2,-1, 3, 2},
                         {add_ref, 0,-1, 0, 2},
                         {add_ref,-1,-1, 0, 0},  -- bridge support (left and right of origin)
                         {add_ref, 1,-1, 0, 0}}, user, pointed_thing)
        elseif cdir == 25 then  -- pointed northwest (2, dig down)
            run_list(   {{aw,-2, 0, 5,-3},{aw,-2,-1, 5,-2},{aw,-3,-1, 5,-2},{aw,-3,-1, 5,-1},{aw,-4,-1, 4,-1},
                         {aw, 3, 0, 5, 2},{aw, 2,-1, 5, 2},{aw, 2,-1, 5, 3},{aw, 1,-1, 5, 3},{aw, 1,-1, 4, 4},
                         {es,-4,-1, 4, 0},{es,-4,-1, 4, 1},{et,-3,-1, 5, 1},{et,-2,-1, 6, 1},{et,-2,-1, 6, 2},{et,-1,-1, 6, 2},{et,-1,-1, 5, 3},{es,-1,-1, 4, 4},{es, 0,-1, 4, 4},
                         {ds,-1, 0, 4,-2},
                         {ds,-2,-1, 4,-1},{dt,-1, 0, 5,-1},
                         {ds,-3,-1, 3, 0},{dt,-2,-1, 4, 0},{dt,-1,-1, 5, 0},{dt, 0, 0, 5, 0},
                         {dt,-1,-1, 5, 1},{dt, 0,-1, 5, 1},{dt, 1, 0, 5, 1},{ds, 2, 0, 4, 1},
                         {dt, 0,-1, 4, 2},{ds, 1,-1, 4, 2},
                         {ds, 0,-1, 3, 3},
                         {add_ref,-1,-1, 0, 1},
                         {add_ref,-1,-1, 0,-1}, -- bridge support (left and right of origin)
                         {add_ref, 1,-1, 0, 1}}, user, pointed_thing)

        elseif cdir == 26 then  -- pointed west (4, dig down)
            run_list(   {{aw, 0, 0, 5,-3},{aw,-1,-1, 5,-3},{aw,-2,-1, 4,-3},
                         {aw, 0, 0, 5, 3},{aw,-1,-1, 5, 3},{aw,-2,-1, 4, 3},
                         {es,-3,-1, 4,-3},{et,-3,-1, 5,-2},{et,-3,-1, 5,-1},{et,-3,-1, 5, 0},{et,-3,-1, 5, 1},{et,-3,-1, 5, 2},{es,-3,-1, 4, 3},
                         {ds,-2,-1, 3,-2},{ds,-1,-1, 4,-2},{ds, 0, 0, 4,-2},
                         {dt,-2,-1, 4,-1},{dt,-1,-1, 5,-1},{dt, 0, 0, 5,-1},
                         {dt,-2,-1, 4, 0},{dt,-1,-1, 5, 0},{dt, 0, 0, 5, 0},
                         {dt,-2,-1, 4, 1},{dt,-1,-1, 5, 1},{dt, 0, 0, 5, 1},
                         {ds,-2,-1, 3, 2},{ds,-1,-1, 4, 2},{ds, 0, 0, 4, 2},
                         {add_ref,-2,-1, 0, 0},
                         {add_ref, 0,-1, 0, 1},  -- bridge support (left and right of origin)
                         {add_ref, 0,-1, 0,-1}}, user, pointed_thing)

        elseif cdir == 27 then  -- pointed southwest (6, dig down)
            run_list(   {{aw, 3, 0, 5,-2},{aw, 2,-1, 5,-2},{aw, 2,-1, 5,-3},{aw, 1,-1, 5,-3},{aw, 1,-1, 4,-4},
                         {aw,-2, 0, 5, 3},{aw,-2,-1, 5, 2},{aw,-3,-1, 5, 2},{aw,-3,-1, 5, 1},{aw,-4,-1, 4, 1},
                         {es, 0,-1, 4,-4},{es,-1,-1, 4,-4},{et,-1,-1, 5,-3},{et,-1, -1, 6,-2},{et,-2,-1, 6,-2},{et,-2,-1, 6,-1},{et,-3,-1, 5,-1},{es,-4,-1, 4,-1},{es,-4,-1, 4, 0},
                         {ds, 0,-1, 3,-3},
                         {dt, 0,-1, 4,-2},{ds, 1,-1, 4,-2},
                         {dt,-1,-1, 5,-1},{dt, 0,-1, 5,-1},{dt, 1, 0, 5,-1},{ds, 2, 0, 4,-1},
                         {ds,-3,-1, 3, 0},{dt,-2,-1, 4, 0},{dt,-1,-1, 5, 0},{dt, 0, 0, 5, 0},
                         {ds,-2,-1, 4, 1},{dt,-1, 0, 5, 1},
                         {ds,-1, 0, 4, 2},
                         {add_ref,-1,-1, 0,-1},
                         {add_ref,-1,-1, 0, 1},  -- bridge support (left and right of origin)
                         {add_ref, 1,-1, 0,-1}}, user, pointed_thing)

        elseif cdir == 28 then  -- pointed south (8, dig down)
            run_list(   {{aw, 3, 0, 5, 0},{aw, 3,-1, 5,-1},{aw, 3,-1, 4,-2},
                         {aw,-3, 0, 5, 0},{aw,-3,-1, 5,-1},{aw,-3,-1, 4,-2},
                         {es, 3,-1, 4,-3},{et, 2,-1, 5,-3},{et, 1,-1, 5,-3},{et, 0,-1, 5,-3},{et,-1,-1, 5,-3},{et,-2,-1, 5,-3},{es,-3,-1, 4,-3},
                         {ds,-2,-1, 3,-2},{dt,-1,-1, 4,-2},{dt, 0,-1, 4,-2},{dt, 1,-1, 4,-2},{ds, 2,-1, 3,-2},
                         {ds,-2,-1, 4,-1},{dt,-1,-1, 5,-1},{dt, 0,-1, 5,-1},{dt, 1,-1, 5,-1},{ds, 2,-1, 4,-1},
                         {ds,-2, 0, 4, 0},{dt,-1, 0, 5, 0},{dt, 0, 0, 5, 0},{dt, 1, 0, 5, 0},{ds, 2, 0, 4, 0},
                         {add_ref, 0,-1, 0,-2},
                         {add_ref,-1,-1, 0, 0},  -- bridge support (left and right of origin)
                         {add_ref, 1,-1, 0, 0}}, user, pointed_thing)

        elseif cdir == 29 then  -- pointed southeast (10, dig down)
            run_list(   {{aw, 2, 0, 5, 3},{aw, 2,-1, 5, 2},{aw, 3,-1, 5, 2},{aw, 3,-1, 5, 1},{aw, 4, 0, 5, 1},
                         {aw,-3, 0, 5,-2},{aw,-2,-1, 5,-2},{aw,-2,-1, 5,-3},{aw,-1,-1, 5,-3},{aw,-1, 0, 5,-4},
                         {es, 4,-1, 4, 0},{es, 4,-1, 4,-1},{et, 3,-1, 5,-1},{et, 2,-1, 6,-1},{et, 2,-1, 6,-2},{et, 1,-1, 6,-2},{et, 1,-1, 5,-3},{es, 1,-1, 4,-4},{es, 0,-1, 4,-4},
                         {ds, 0,-1, 3,-3},
                         {ds,-1,-1, 4,-2},{dt, 0,-1, 4,-2},
                         {ds,-2, 0, 4,-1},{dt,-1, 0, 5,-1},{dt, 0,-1, 5,-1},{dt, 1,-1, 5,-1},
                         {dt, 0, 0, 5, 0},{dt, 1,-1, 5, 0},{dt, 2,-1, 4, 0},{ds, 3,-1, 3, 0},
                         {dt, 1, 0, 5, 1},{ds, 2,-1, 4, 1},
                         {ds, 1, 0, 4, 2},
                         {add_ref, 1,-1, 0,-1},
                         {add_ref,-1,-1, 0,-1},  -- bridge support (left and right of origin)
                         {add_ref, 1,-1, 0, 1}}, user, pointed_thing)

        elseif cdir == 30 then  -- pointed east (12, dig down)
            run_list(   {{aw, 0, 0, 5, 3},{aw, 1,-1, 5, 3},{aw, 2,-1, 4, 3},
                         {aw, 0, 0, 5,-3},{aw, 1,-1, 5,-3},{aw, 2,-1, 4,-3},
                         {es, 3,-1, 4, 3},{et, 3,-1, 5, 2},{et, 3,-1, 5, 1},{et, 3,-1, 5, 0},{et, 3,-1, 5,-1},{et, 3,-1, 5,-2},{es, 3,-1, 4,-3},
                         {ds, 0, 0, 4,-2},{ds, 1,-1, 4,-2},{ds, 2,-1, 3,-2},
                         {dt, 0, 0, 5,-1},{dt, 1,-1, 5,-1},{dt, 2,-1, 4,-1},
                         {dt, 0, 0, 5, 0},{dt, 1,-1, 5, 0},{dt, 2,-1, 4, 0},
                         {dt, 0, 0, 5, 1},{dt, 1,-1, 5, 1},{dt, 2,-1, 4, 1},
                         {ds, 0, 0, 4, 2},{ds, 1,-1, 4, 2},{ds, 2,-1, 3, 2},
                         {add_ref, 2,-1, 0, 0},
                         {add_ref, 0,-1, 0, 1},  -- bridge support (left and right of origin)
                         {add_ref, 0,-1, 0,-1}}, user, pointed_thing)

        elseif cdir == 31 then  -- pointed northeast (14, dig down)
            run_list(   {{aw,-3, 0, 5, 2},{aw,-2,-1, 5, 2},{aw,-2,-1, 5, 3},{aw,-1,-1, 5, 3},{aw,-1,-1, 4, 4},
                         {aw, 2, 0, 5,-3},{aw, 2,-1, 5,-2},{aw, 3,-1, 5,-2},{aw, 3,-1, 5,-1},{aw, 4,-1, 4,-1},
                         {es, 0,-1, 4, 4},{es, 1,-1, 4, 4},{et, 1,-1, 5, 3},{et, 1,-1, 6, 2},{et, 2,-1, 6, 2},{et, 2,-1, 6, 1},{et, 3,-1, 5, 1},{es, 4,-1, 4, 1},{es, 4,-1, 4, 0},
                         {ds, 1, 0, 4,-2},
                         {dt, 1, 0, 5,-1},{ds, 2,-1, 4,-1},
                         {dt, 0, 0, 5, 0},{dt, 1,-1, 5, 0},{dt, 2,-1, 4, 0},{ds, 3,-1, 3, 0},
                         {ds,-2, 0, 4, 1},{dt,-1, 0, 5, 1},{dt, 0,-1, 5, 1},{dt, 1,-1, 5, 1},
                         {ds,-1,-1, 4, 2},{dt, 0,-1, 4, 2},
                         {ds, 0,-1, 3, 3},
                         {add_ref,-1,-1, 0, 1},
                         {add_ref,-1,-1, 0, 0},  -- bridge support (left and right of origin)
                         {add_ref, 1,-1, 0,-1}}, user, pointed_thing)
        end
        add_light(1, user, pointed_thing)  -- change to 1 for more frequent lights (using 1 while debugging updown)
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
                    if minetest.registered_nodes[name].groups.advtrains_track == 1 then
                        pointed_thing.under = vector.add(pointed_thing.under, {x=0, y=-1, z=0})
                        pointed_thing.above = vector.add(pointed_thing.above, {x=0, y=-1, z=0})  -- don't currently use this
                    end
                    dig_tunnel(i-1, placer, pointed_thing)
                    tunnelmaker[pname].updown = 0   -- reset after one use
                end
            end
        end,        -- on_place
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
