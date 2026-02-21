-- coil_plate.lua
-- Builds an axisymmetric coil-over-plate eddy current model in FEMM

-- Safety: start clean
newdocument(0)          -- 0 = magnetics problem
mi_probdef(10000, "millimeters", "axi", 1e-8, 0, 30)  -- f, units, type, precision, depth, minangle

-- Geometry parameters (mm)
local plate_r   = 50
local plate_t   = 5

local coil_r1   = 4.5
local coil_r2   = 6.5
local coil_h    = 2
local gap_z     = 0      -- change this for different lift-off (mm)
local coil_y1   = gap_z
local coil_y2   = gap_z + coil_h

local air_r     = 80
local air_ymin  = -30
local air_ymax  = 50

-- Helpers: draw rectangle with corners (x1,y1) to (x2,y2)
function draw_rect(x1,y1,x2,y2)
  mi_addnode(x1,y1); mi_addnode(x2,y1); mi_addnode(x2,y2); mi_addnode(x1,y2)
  mi_addsegment(x1,y1,x2,y1)
  mi_addsegment(x2,y1,x2,y2)
  mi_addsegment(x2,y2,x1,y2)
  mi_addsegment(x1,y2,x1,y1)
end

-- Outer air box
draw_rect(0, air_ymin, air_r, air_ymax)

-- Plate (top at y=0, thickness plate_t downward)
draw_rect(0, 0, plate_r, -plate_t)

-- Coil (rectangle cross-section), positioned at gap_z above plate
draw_rect(coil_r1, coil_y1, coil_r2, coil_y2)

-- Materials: assumes default library has these names
-- If any material name fails on your machine, tell me what your list shows and I'll adjust.
mi_getmaterial("Air")
mi_getmaterial("Copper")
mi_getmaterial("Aluminum, 6061-T6")

-- Circuit for coil
mi_addcircprop("Coil", 1, 1)  -- name, amps, series(1)/parallel(0)

-- Block labels + assignments
-- Air
mi_addblocklabel(10, 10)
mi_selectlabel(10, 10)
mi_setblockprop("Air", 0, 0, "", 0, 0, 0)
mi_clearselected()

-- Plate (aluminum)
mi_addblocklabel(10, -2)
mi_selectlabel(10, -2)
mi_setblockprop("Aluminum, 6061-T6", 0, 0.5, "", 0, 0, 0)  -- mesh size 0.5 mm
mi_clearselected()

-- Coil (copper, circuit, turns)
mi_addblocklabel((coil_r1+coil_r2)/2, (coil_y1+coil_y2)/2)
mi_selectlabel((coil_r1+coil_r2)/2, (coil_y1+coil_y2)/2)
mi_setblockprop("Copper", 0, 0.5, "Coil", 0, 1, 100)  -- circuit=Coil, group=1, turns=100
mi_clearselected()

-- Boundary condition on outer air box: A=0
mi_addboundprop("A0", 0, 0, 0, 0, 0, 0, 0, 0, 0)
-- Apply A0 to all segments on outer boundary by selecting them
-- Select 4 outer edges by clicking midpoints
mi_selectsegment(air_r/2, air_ymin)          -- bottom
mi_selectsegment(air_r, (air_ymin+air_ymax)/2) -- right
mi_selectsegment(air_r/2, air_ymax)          -- top
mi_selectsegment(0, (air_ymin+air_ymax)/2)     -- left (axis line)
mi_setsegmentprop("A0", 0, 1, 0, 0)
mi_clearselected()

-- Save model
mi_saveas("coil_plate_axi.fem")

-- Done building. You can now mesh/solve from GUI or uncomment below:
-- mi_createmesh()
-- mi_analyze()
-- mi_loadsolution()