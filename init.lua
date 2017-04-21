-- tunnelmaker
-- Another tunnel digging mod for minetest.
-- by David G (kestral246@gmail.com)

-- Version 0.5.0

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

-- dig rectangular shape for non-45 degree angles
local dig_rect = function(xmin, xmax, zmin, zmax, user, pointed_thing)
    for x=xmin,xmax do
        for z=zmin,zmax do
            -- delete nodes (not torches)
            for y=1,4 do
                local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
                if minetest.get_node(pos).name ~= "default:torch_ceiling" and not minetest.is_protected(pos, user) then
                    minetest.dig_node(pos)
                end
            end
            -- add flooring (if air)
            local pos = vector.add(pointed_thing.under, {x=x, y=0, z=z})
            if minetest.get_node(pos).name == "air" and not minetest.is_protected(pos, user) then
                minetest.set_node(pos, {name = "default:cobble"})
            end
        end
    end
    -- add lighting
    local pos = vector.add(pointed_thing.under, {x=0, y=4, z=0})
    local ceiling = minetest.get_node(vector.add(pos, {x=0, y=1, z=0})).name
    if (ceiling == "default:stone" or ceiling == "default:desert_stone") and
            minetest.get_node(pos).name == "air" and not minetest.is_protected(pos, user) and
            minetest.find_node_near(pos, 3, {name = "default:torch_ceiling"}) == nil then
        minetest.set_node(pos, {name = "default:torch_ceiling"})
    end
end

-- dig plus shape for 45 degree angles
local dig_plus = function(xmin, xmax, zmin, zmax, user, pointed_thing)
    -- center section
    for x=xmin,xmax do
        for z=zmin+1,zmax-1 do
            -- delete nodes (not torches)
            for y=1,4 do
                local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
                if minetest.get_node(pos).name ~= "default:torch_ceiling" and not minetest.is_protected(pos, user) then
                    minetest.dig_node(pos)
                end
            end
            -- add flooring (if air)
            local pos = vector.add(pointed_thing.under, {x=x, y=0, z=z})
            if minetest.get_node(pos).name == "air" and not minetest.is_protected(pos, user) then
                minetest.set_node(pos, {name = "default:cobble"})
            end
        end
    end
    -- top and bottom sections
    for x=xmin+1,xmax-1 do
        for z=zmin,zmax,3 do
            -- delete nodes (not torches)
            for y=1,4 do
                local pos = vector.add(pointed_thing.under, {x=x, y=y, z=z})
                if minetest.get_node(pos).name ~= "default:torch_ceiling" and not minetest.is_protected(pos, user) then
                    minetest.dig_node(pos)
                end
            end
            -- add flooring (if air)
            local pos = vector.add(pointed_thing.under, {x=x, y=0, z=z})
            if minetest.get_node(pos).name == "air" and not minetest.is_protected(pos, user) then
                minetest.set_node(pos, {name = "default:cobble"})
            end
        end
    end

    -- add lighting
    local pos = vector.add(pointed_thing.under, {x=0, y=4, z=0})
    local ceiling = minetest.get_node(vector.add(pos, {x=0, y=1, z=0})).name
    if (ceiling == "default:stone" or ceiling == "default:desert_stone") and
            minetest.get_node(pos).name == "air" and not minetest.is_protected(pos, user) and
            minetest.find_node_near(pos, 2, {name = "default:torch_ceiling"}) == nil then
        minetest.set_node(pos, {name = "default:torch_ceiling"})
    end
end

-- dig tunnel based on direction given
local dig_tunnel = function(cdir, user, pointed_thing)
    if minetest.check_player_privs(user, "tunneling") then
        if cdir == 0 then                                   -- pointed 0 (north)
            dig_rect(-1, 1, 0, 2, user, pointed_thing)
        elseif cdir == 1 then                               -- pointed -22.5
            dig_rect(-2, 1, 0, 2, user, pointed_thing)
        elseif cdir == 2 then                               -- pointed -45 (northwest)
            dig_plus(-2, 1, -1, 2, user, pointed_thing)
        elseif cdir == 3 then                               -- pointed -67.5
            dig_rect(-2, 0, -1, 2, user, pointed_thing)
        elseif cdir == 4 then                               -- pointed -90 (west)
            dig_rect(-2, 0, -1, 1, user, pointed_thing)
        elseif cdir == 5 then                               -- pointed -90-22.5
            dig_rect(-2, 0, -2, 1, user, pointed_thing)
        elseif cdir == 6 then                               -- pointed -90-45 (southwest)
            dig_plus(-2, 1, -2, 1, user, pointed_thing)
        elseif cdir == 7 then                               -- pointed -90-67.5
            dig_rect(-2, 1, -2, 0, user, pointed_thing)
        elseif cdir == 8 then                               -- pointed +/-180 (south)
            dig_rect(-1, 1, -2, 0, user, pointed_thing)
        elseif cdir == 9 then                               -- pointed +22.5
            dig_rect(-1, 2, -2, 0, user, pointed_thing)
        elseif cdir == 10 then                              -- pointed +45 (northeast)
            dig_plus(-1, 2, -2, 1, user, pointed_thing)
        elseif cdir == 11 then                              -- pointed +67.5
            dig_rect(0, 2, -2, 1, user, pointed_thing)
        elseif cdir == 12 then                              -- pointed +90 (east)
            dig_rect(0, 2, -1, 1, user, pointed_thing)
        elseif cdir == 13 then                              -- pointed +90+22.5
            dig_rect(0, 2, -1, 2, user, pointed_thing)
        elseif cdir == 14 then                              -- pointed +90+45 (southeast)
            dig_plus(-1, 2, -1, 2, user, pointed_thing)
        elseif cdir == 15 then                              -- pointed +90+67.5
            dig_rect(-1, 2, 0, 2, user, pointed_thing)
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
        tool_capabilities = {
            full_punch_interval = 1.2,
            max_drop_level=0,
            groupcaps={
                cracky = {times={[3]=1.6}, maxlevel=1},
            },
            damage_groups = {fleshy=2},
        },

        -- dig tunnel with right mouse click (double tap on android)
        on_place = function(itemstack, placer, pointed_thing)
            if pointed_thing.type=="node" then
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
