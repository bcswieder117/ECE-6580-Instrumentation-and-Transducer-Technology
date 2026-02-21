-- coil_plate_solve.lua
-- Assumes coil_plate_axi.fem is already open

mi_createmesh()
mi_analyze()
mi_loadsolution()

print("Solved successfully.")