-- tunnelmaker
-- Another tunnel digging mod for minetest.
-- by David G (kestral246@gmail.com)

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
        if gotatunnelmaker then
            local pos = player:getpos()
            local dir = player:get_look_yaw()
            local angle_north = 0
            local angle_dir = 90 - math.deg(dir)
            local angle_relative = (angle_north - angle_dir) % 360
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
-- add reference block to point to next target location and to aid laying track
-- currently using default:cobble
local add_ref = function(x, z, user, pointed_thing)
    local pos = vector.add(pointed_thing.under, {x=x, y=0, z=z})
    if not minetest.is_protected(pos, user) then
        minetest.set_node(pos, {name = "default:cobble"})
    end
end

-- delete single node, but not torches
local dig_single = function(x, y, z, user, pointed_thing)
    local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
    if minetest.get_node(pos).name ~= "default:torch_ceiling" and not minetest.is_protected(pos, user) then
        minetest.dig_node(pos)
    end
end

-- add stone floor, if air
local add_single = function(x, y, z, user, pointed_thing)
    local pos = vector.add(pointed_thing.under, {x=x, y=0, z=z})
    if minetest.get_node(pos).name == "air" and not minetest.is_protected(pos, user) then
        minetest.set_node(pos, {name = "default:stone"})
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

-- dig rectangular shape for non-45 degree angles
local dig_rect = function(xmin, xmax, zmin, zmax, user, pointed_thing)
    for x=xmin,xmax do
        for z=zmin,zmax do
            for y=1,4 do
                dig_single(x, y, z, user, pointed_thing)
            end
        end
    end
end

-- rectangular finishing, floor and ceiling
local dig_rect_fin = function(xmin, xmax, zmin, zmax, user, pointed_thing)
    for x=xmin,xmax do
        for z=zmin,zmax do
            dig_single(x, 5, z, user, pointed_thing)
            add_single(x, 0, z, user, pointed_thing)
        end
    end
    -- add lighting
    add_light(2, user, pointed_thing)
end

-- dig extra width for 45 degree angles
local dig_nw = function(user, pointed_thing)
    for y=1,4 do
        dig_single(-3, y, 0, user, pointed_thing)
        dig_single(-2, y, -1, user, pointed_thing)
        dig_single(-1, y, -2, user, pointed_thing)
        dig_single(0, y, 3, user, pointed_thing)
        dig_single(1, y, 2, user, pointed_thing)
        dig_single(2, y, 1, user, pointed_thing)
    end
end

local dig_sw = function(user, pointed_thing)
    for y=1,4 do
        dig_single(-3, y, 0, user, pointed_thing)
        dig_single(-2, y, 1, user, pointed_thing)
        dig_single(-1, y, 2, user, pointed_thing)
        dig_single(0, y, -3, user, pointed_thing)
        dig_single(1, y, -2, user, pointed_thing)
        dig_single(2, y, -1, user, pointed_thing)
    end
end

local dig_se = function(user, pointed_thing)
    for y=1,4 do
        dig_single(-2, y, -1, user, pointed_thing)
        dig_single(-1, y, -2, user, pointed_thing)
        dig_single(0, y, -3, user, pointed_thing)
        dig_single(1, y, 2, user, pointed_thing)
        dig_single(2, y, 1, user, pointed_thing)
        dig_single(3, y, 0, user, pointed_thing)
    end
end

local dig_ne = function(user, pointed_thing)
    for y=1,4 do
        dig_single(-2, y, 1, user, pointed_thing)
        dig_single(-1, y, 2, user, pointed_thing)
        dig_single(0, y, 3, user, pointed_thing)
        dig_single(1, y, -2, user, pointed_thing)
        dig_single(2, y, -1, user, pointed_thing)
        dig_single(3, y, 0, user, pointed_thing)
    end
end

-- 45 degree finishing, floor and ceiling
local dig_plus = function(xmin, xmax, zmin, zmax, user, pointed_thing)
    -- center section
    for x=xmin,xmax do
        for z=zmin+1,zmax-1 do
            -- delete nodes (not torches)
            for y=1,5 do
                dig_single(x, y, z, user, pointed_thing)
            end
            -- add flooring (if air)
            add_single(x, 0, z, user, pointed_thing)
        end
    end
    -- top and bottom sections
    for x=xmin+1,xmax-1 do
        for z=zmin,zmax,3 do
            -- delete nodes (not torches)
            for y=1,5 do
                dig_single(x, y, z, user, pointed_thing)
            end
            -- add flooring (if air)
            add_single(x, 0, z, user, pointed_thing)
        end
    end
    -- add lighting
    add_light(2, user, pointed_thing)
end

-- dig tunnel based on direction given
local dig_tunnel = function(cdir, user, pointed_thing)
    if minetest.check_player_privs(user, "tunneling") then
        if cdir == 0 then                                   -- pointed north
            dig_rect(-2, 2, 0, 2, user, pointed_thing)
            dig_rect_fin(-1, 1, 0, 2, user, pointed_thing)
            add_ref(0, 2, user, pointed_thing)
        elseif cdir == 1 then                               -- pointed north-northwest
            dig_rect(-3, 2, 0, 2, user, pointed_thing)
            dig_rect_fin(-2, 1, 0, 2, user, pointed_thing)
            add_ref(-1, 2, user, pointed_thing)
        elseif cdir == 2 then                               -- pointed northwest
            dig_nw(user, pointed_thing)
            dig_plus(-2, 1, -1, 2, user, pointed_thing)
            add_ref(-1, 1, user, pointed_thing)
        elseif cdir == 3 then                               -- pointed west-northwest
            dig_rect(-2, 0, -2, 3, user, pointed_thing)
            dig_rect_fin(-2, 0, -1, 2, user, pointed_thing)
            add_ref(-2, 1, user, pointed_thing)
        elseif cdir == 4 then                               -- pointed west
            dig_rect(-2, 0, -2, 2, user, pointed_thing)
            dig_rect_fin(-2, 0, -1, 1, user, pointed_thing)
            add_ref(-2, 0, user, pointed_thing)
        elseif cdir == 5 then                               -- pointed west-southwest
            dig_rect(-2, 0, -3, 2, user, pointed_thing)
            dig_rect_fin(-2, 0, -2, 1, user, pointed_thing)
            add_ref(-2, -1, user, pointed_thing)
        elseif cdir == 6 then                               -- pointed southwest
            dig_sw(user, pointed_thing)
            dig_plus(-2, 1, -2, 1, user, pointed_thing)
            add_ref(-1, -1, user, pointed_thing)
        elseif cdir == 7 then                               -- pointed south-southwest
            dig_rect(-3, 2, -2, 0, user, pointed_thing)
            dig_rect_fin(-2, 1, -2, 0, user, pointed_thing)
            add_ref(-1, -2, user, pointed_thing)
        elseif cdir == 8 then                               -- pointed south
            dig_rect(-2, 2, -2, 0, user, pointed_thing)
            dig_rect_fin(-1, 1, -2, 0, user, pointed_thing)
            add_ref(0, -2, user, pointed_thing)
        elseif cdir == 9 then                               -- pointed south-southeast
            dig_rect(-2, 3, -2, 0, user, pointed_thing)
            dig_rect_fin(-1, 2, -2, 0, user, pointed_thing)
            add_ref(1, -2, user, pointed_thing)
        elseif cdir == 10 then                              -- pointed southeast
            dig_se(user, pointed_thing)
            dig_plus(-1, 2, -2, 1, user, pointed_thing)
            add_ref(1, -1, user, pointed_thing)
        elseif cdir == 11 then                              -- pointed east-southeast
            dig_rect(0, 2, -3, 2, user, pointed_thing)
            dig_rect_fin(0, 2, -2, 1, user, pointed_thing)
            add_ref(2, -1, user, pointed_thing)
        elseif cdir == 12 then                              -- pointed east
            dig_rect(0, 2, -2, 2, user, pointed_thing)
            dig_rect_fin(0, 2, -1, 1, user, pointed_thing)
            add_ref(2, 0, user, pointed_thing)
        elseif cdir == 13 then                              -- pointed east-northeast
            dig_rect(0, 2, -2, 3, user, pointed_thing)
            dig_rect_fin(0, 2, -1, 2, user, pointed_thing)
            add_ref(2, 1, user, pointed_thing)
        elseif cdir == 14 then                              -- pointed northeast
            dig_ne(user, pointed_thing)
            dig_plus(-1, 2, -1, 2, user, pointed_thing)
            add_ref(1, 1, user, pointed_thing)
        elseif cdir == 15 then                              -- pointed north-northeast
            dig_rect(-2, 3, 0, 2, user, pointed_thing)
            dig_rect_fin(-1, 2, 0, 2, user, pointed_thing)
            add_ref(1, 2, user, pointed_thing)
        end
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
        description = "Tunnel Maker (easily create curved tunnels)",
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
