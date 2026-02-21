-- coil_plate_sweep_export_FINAL.lua
-- FINAL sweep script tuned for *your* FEMM/Lua environment:
--   ✓ NO pcall
--   ✓ NO math.* (uses PI constant)
--   ✓ NO string.* (no string.format)
--   ✓ Does NOT depend on Re()/Im()
--   ✓ File I/O uses HANDLE-STYLE: openfile()->handle; write(handle,...); closefile(handle)
--   ✓ If CSV cannot be opened, it STILL prints CSV rows to the Lua console (so you can copy/paste)

showconsole()

-- =========================
-- User parameters (edit these)
-- =========================
freq_hz   = 10000
units     = "millimeters"
I_amps    = 1
turns     = 100
series    = 1
minangle  = 30
precision = 1e-8

-- Geometry (mm)
plate_r   = 50
plate_t   = 5
coil_r1   = 4.5
coil_r2   = 6.5
coil_h    = 2
air_r     = 80
air_ymin  = -30
air_ymax  = 50

-- Sweep settings (mm)
gap_start = 0
gap_end   = 10
gap_step  = 0.5

-- Output (relative, no folder)
CSV_FILE  = "coil_plate_sweep.csv"

-- If your FEMM working directory is not writable, this fallback usually is:
FALLBACK_CSV_FILE = "C:\\\\femm42\\\\examples\\\\coil_plate_sweep.csv"

PI = 3.141592653589793

function pad3(n)
  if n < 10 then return "00"..n end
  if n < 100 then return "0"..n end
  return ""..n
end

function num2str(x)
  if format then return format("%.6g", x) end
  return tostring(x)
end

-- ---------- geometry helpers ----------
function draw_rect(x1,y1,x2,y2)
  mi_addnode(x1,y1); mi_addnode(x2,y1); mi_addnode(x2,y2); mi_addnode(x1,y2)
  mi_addsegment(x1,y1,x2,y1)
  mi_addsegment(x2,y1,x2,y2)
  mi_addsegment(x2,y2,x1,y2)
  mi_addsegment(x1,y2,x1,y1)
end

function build_model(gap_z, fem_name)
  newdocument(0)
  mi_probdef(freq_hz, units, "axi", precision, 0, minangle)

  draw_rect(0, air_ymin, air_r, air_ymax)
  draw_rect(0, 0, plate_r, -plate_t)

  coil_y1 = gap_z
  coil_y2 = gap_z + coil_h
  draw_rect(coil_r1, coil_y1, coil_r2, coil_y2)

  mi_getmaterial("Air")
  mi_getmaterial("Copper")
  mi_getmaterial("Aluminum, 6061-T6")

  mi_addcircprop("Coil", I_amps, series)

  -- Air label
  mi_addblocklabel(10, 10)
  mi_selectlabel(10, 10)
  mi_setblockprop("Air", 0, 0, "", 0, 0, 0)
  mi_clearselected()

  -- Plate label
  mi_addblocklabel(10, -2)
  mi_selectlabel(10, -2)
  mi_setblockprop("Aluminum, 6061-T6", 0, 0.5, "", 0, 0, 0)
  mi_clearselected()

  -- Coil label
  cx = (coil_r1 + coil_r2)/2
  cy = (coil_y1 + coil_y2)/2
  mi_addblocklabel(cx, cy)
  mi_selectlabel(cx, cy)
  mi_setblockprop("Copper", 0, 0.5, "Coil", 0, 1, turns)
  mi_clearselected()

  -- Boundary A=0 on outer edges + axis
  mi_addboundprop("A0", 0, 0, 0, 0, 0, 0, 0, 0, 0)
  mi_selectsegment(air_r/2, air_ymin)
  mi_selectsegment(air_r, (air_ymin+air_ymax)/2)
  mi_selectsegment(air_r/2, air_ymax)
  mi_selectsegment(0, (air_ymin+air_ymax)/2)
  mi_setsegmentprop("A0", 0, 1, 0, 0)
  mi_clearselected()

  -- Must save before solve
  mi_saveas(fem_name)
end

-- ---------- circuit extraction ----------
function get_RXL()
  a1,a2,a3,a4,a5,a6 = mo_getcircuitproperties("Coil")

  -- Best case: 6 numeric returns: Ir, Ii, Vr, Vi, Fr, Fi
  if a4 ~= nil and type(a1)=="number" and type(a2)=="number" and type(a3)=="number" and type(a4)=="number" then
    Ir = a1; Ii = a2; Vr = a3; Vi = a4
    denom = Ir*Ir + Ii*Ii
    if denom == 0 then return 0,0,0 end
    R = (Vr*Ir + Vi*Ii)/denom
    X = (Vi*Ir - Vr*Ii)/denom
    L = X/(2*PI*freq_hz)
    return R,X,L
  end

  -- Fallback: 3 returns (complex). Prefer re()/im() if present.
  I = a1; V = a2
  Z = V/I

  if re ~= nil and im ~= nil then
    R = re(Z)
    X = im(Z)
  else
    -- last resort: table
    if type(Z)=="table" then
      if Z.re ~= nil then R = Z.re else R = Z[1] end
      if Z.im ~= nil then X = Z.im else X = Z[2] end
    else
      R = 0; X = 0
    end
  end

  L = X/(2*PI*freq_hz)
  return R,X,L
end

-- ---------- CSV open (handle-style, with fallback) ----------
function open_csv(path)
  fh = openfile(path, "w")
  if fh ~= nil and type(fh) == "userdata" then
    return fh
  end
  return nil
end

fh = open_csv(CSV_FILE)
out_path = CSV_FILE

if fh == nil then
  fh = open_csv(FALLBACK_CSV_FILE)
  out_path = FALLBACK_CSV_FILE
end

if fh == nil then
  print("WARNING: Could not open a CSV file for writing.")
  print("I will print CSV lines to the Lua console instead.")
  print("You can copy/paste the output into Notepad and save as coil_plate_sweep.csv")
else
  write(fh, "gap_mm,R_ohm,X_ohm,L_H\n")
end

print("gap_mm,R_ohm,X_ohm,L_H")

g = gap_start
idx = 0

while g <= (gap_end + 1e-12) do
  idx = idx + 1
  fem_name = "coil_plate_gap_"..pad3(idx)..".fem"

  build_model(g, fem_name)
  mi_createmesh()
  mi_analyze()
  mi_loadsolution()

  R,X,L = get_RXL()
  line = num2str(g)..","..num2str(R)..","..num2str(X)..","..num2str(L).."\n"

  if fh ~= nil then
    write(fh, line)
  end
  print(line)

  mo_close()
  mi_close()

  g = g + gap_step
end

if fh ~= nil then
  closefile(fh)
  messagebox("Sweep complete.\nWrote CSV:\n"..out_path)
else
  messagebox("Sweep complete.\nNo CSV written (file open failed).\nCopy the printed lines from the Lua console and save as .csv.")
end
