Tunnelmaker 2.0
===============

A Minetest Mod to easily create arbitrarily curved tunnels, pathways, and bridges.

![Tunnelmaker Screenshot](screenshot.png "Tunnelmaker")

By David G (kestral246@gmail.com), with significant contributions by Mikola.

Warning: Version 2 only supports Minetest 5.0+.
-----------------------------------------------
In addition there's been a MAJOR change with controls.
------------------------------------------------------
For Minetest 0.4.x, use the git branch legacy, or the following zip file: [tunnelmaker-legacy.zip](https://github.com/kestral246/tunnelmaker/archive/legacy.zip).

Features
--------
- Create paths, bridges, and tunnels in all sixteen possible advtrains track directions with one click.
- Also digs up or down in the eight possible advtrains slope track directions.
- Digging mode and options can be set using new User Options menu.
- Supports Advanced trains mod with gravel embankment, arched and optionally lined tunnels, and two widths of bridges.
- Supports Bike mod with two widths of cobblestone pathways and bridges, along with unlined tunnels.
- Supports general excavation with unlined and lined tunnels.
- Adds reference nodes to help digging and laying advtrains track—now easy to remove when done.
- Adds glass enclosure when in water to create water tunnels.
- Requires "tunneling" privilege, and checks protections before digging.
- No crafting recipe, so needs to be given to player.
- Works in both creative and survival modes, but tunneling does not place any nodes into user's inventory.
- Supports client-side translation files. Currently only have Russian and my attempt at a French translation. **Other languages will be gratefully accepted.** Reference template file is available in locale directory.

![Bike path up mountain](images/bike_path.png "Bike path up mountain")

Controls (Caution MAJOR change!)
--------------------------------
- **Left-click:** Super dig one node. One click digs any node (non-repeating) and places it in player's inventory. However, it can't be used to pick up dropped items.
- **Shift-left-click:** Dig tunnel in direction player pointed. Note that this won't place any of the dug nodes in player's inventory.
- **Right-click:** Cycle through vertical digging modes, up, down, and horizontal.
- **Shift-right-click:** Bring up User Options menu (see below).

In addition:

- **Aux-left-click:** Also digs tunnel (useful if flying).
- **Aux-right-click:** Also digs tunnel (needed for Android).

The reason for this change is that while updating this mod I had to test it a lot, and I've lost track of the number of times I've accidentally pressed right-click and dug a tunnel when I didn't want to. The only solution was to move tunnel digging to another key combination.

How to enable
-------------
- Install tunnelmaker mod, requires default and stairs. For nicer bike path ramps, I recommend installing the angledstairs mod, which was used for the picture above, but it's not required.
- Grant player "tunneling" privilege (/grant &lt;player&gt; tunneling).
- To give player a tunnelmaker tool use (/give &lt;player&gt; tunnelmaker:tool1).

How to dig
----------
*See diagram below that shows track configurations supported by advtrains.*

- Move to digging location and highlight node at ground level. (Gray node in diagrams marked with an '×'.)
- Point player in desired digging direction. (Inventory icon will change to show current direction.)
- Hold down shift key while left-clicking mouse to dig tunnel.


Digging for slopes
------------------
*Note that advtrains only supports sloped track for orthogonal and diagonal track directions.*

- Move to digging location and highlight node at ground level.
- Point player in desired digging direction.
- Right-click mouse to select digging mode.  Inventory icon will cycle through possible modes with each click:  'U' for digging up, 'D' for digging down, and no letter for default horizontal.
- Shift-left-click mouse to dig tunnel.
- There is a user option to control whether to reset direction after each dig or not (see below).

![Tunnelmaker Icons](images/icons.png "Tunnelmaker Icons")

User Options menu
----------------
Use shift-right-click to bring up this menu.

![Tunnelmaker User Options](images/user_options.gif "Tunnelmaker User Options")

Descriptions of all the options:

- **Digging mode** Select one of the three digging modes: General purpose, Advanced trains, or Bike paths.
- **Wide paths / lined tunnels** Select between narrow and wide paths, and whether tunnels are lined with stone or not.
- **Continuous up/down digging** Don't reset up/down after each dig.
- **Clear tree cover** Remove all plant material above dig up to 30 nodes above ground. CPU intensive, so shuts off after two minutes.
- **Remove reference nodes** Easily remove reference nodes by walking over them. Also shuts off after two minutes.
- **Lock desert mode to: either "Desert" or "Non-desert"** Option only available when "add_desert_material = true" has been added to minetest.conf. Overrides use of desert materials in desert biomes. Useful for transition regions.

Advtrains digging reference
---------------------------
The following diagrams show how to make curved tunnels that support the different track configurations used by advtrains. There are three basic directions that are supported: 0° (orthogonal, rook moves), 45° (diagonal, bishop moves), and 26.6° (knight moves, two blocks forward and one block to the side).

- *Note that it's always possible to dig in any direction, but turns with angles other than those shown won't be supported by advtrains track.*
- *Also note that there are other limitations to advtrains slope track.  Documentation TBD.*

![Turns from 0°](images/dir0.png "Turns from 0")

![Turns from 26.6°](images/dir26.png "Turns from 26.6")

![Turns from 45°](images/dir45.png "Turns from 45")

License
-------
- **textures:** License CC0-1.0 
- **code:**  My changes to original code are CC0-1.0
- **original compassgps license:** Original code by Echo, PilzAdam, and TeTpaAka is WTFPL. Kilarin (Donald Hines) changes are CC0 (No rights reserved)

Thanks
------
- [advtrains](https://github.com/orwell96/advtrains/) / orwell96, et.
al. - For providing the amazing advtrains mod that this mod tries to make
just a little easier to use.
- [compassgps](https://github.com/Kilarin/compassgps) / Kilarin (Donald Hines),
et. al. - Top level code to change icon based on direction player is pointing.
