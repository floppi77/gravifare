-- Baut build/aseprite-workspace/gf_movers/movers.aseprite aus den Ebenen body.png, detail.png, outline.png (tools/art/gen_movers.py pre)
-- und schreibt das zusammengesetzte Blatt movers_flat.png (Export: gen_movers.py export nach assets/art/movers.png).
-- Aufruf aus der Projektwurzel: aseprite -b --script tools/art/aseprite/build_movers.lua
local dir = "build/aseprite-workspace/gf_movers/"
local names = { "body", "detail", "outline" }
local first = Image{ fromFile = dir .. "body.png" }
local spr = Sprite(first.width, first.height, ColorMode.RGB)
spr.layers[1].name = names[1]
spr:newCel(spr.layers[1], 1, first, Point(0, 0))
for i = 2, #names do
  local l = spr:newLayer(); l.name = names[i]
  spr:newCel(l, 1, Image{ fromFile = dir .. names[i] .. ".png" }, Point(0, 0))
end
spr:saveAs(dir .. "movers.aseprite")
spr:saveCopyAs(dir .. "movers_flat.png")
print("movers.aseprite: " .. spr.width .. "x" .. spr.height .. ", " .. #spr.layers .. " Ebenen")
