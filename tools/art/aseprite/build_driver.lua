-- Baut build/aseprite-workspace/gf_driver/driver.aseprite aus den Einzelbildern frame_00.png … frame_16.png (tools/art/gen_driver.py pre):
-- Ebene "body" (schattierte Figur), Ebene "outline" (Kontur in der abgedunkelten Farbe des jeweiligen Nachbarn, „colormatched“), Tags, Bilddauern.
-- Aufruf aus der Projektwurzel: aseprite -b --script tools/art/aseprite/build_driver.lua
local dir = "build/aseprite-workspace/gf_driver/"
local N, W, H = 17, 40, 56
local spr = Sprite(W, H, ColorMode.RGB)
spr.layers[1].name = "body"
local outl = spr:newLayer(); outl.name = "outline"
for i = 0, N - 1 do
  if i > 0 then spr:newEmptyFrame() end
  local img = Image{ fromFile = string.format("%sframe_%02d.png", dir, i) }
  spr:newCel(spr.layers[1], i + 1, img, Point(0, 0))
  local ol = Image(W, H, ColorMode.RGB)
  local function a(x, y) if x < 0 or y < 0 or x >= W or y >= H then return 0 end return app.pixelColor.rgbaA(img:getPixel(x, y)) end
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      if a(x, y) == 0 then
        -- die Nachbarn mit Deckkraft; die dunkelste Farbe unter ihnen bestimmt den Ton (Kontur zieht sich nicht ins Helle)
        local best, bl = nil, 1e9
        for _, d in ipairs({ {1, 0}, {-1, 0}, {0, 1}, {0, -1} }) do
          local nx, ny = x + d[1], y + d[2]
          if a(nx, ny) > 0 then
            local p = img:getPixel(nx, ny)
            local l = app.pixelColor.rgbaR(p) * 0.3 + app.pixelColor.rgbaG(p) * 0.59 + app.pixelColor.rgbaB(p) * 0.11
            if l < bl then bl, best = l, p end
          end
        end
        if best then
          local r, g, b = app.pixelColor.rgbaR(best), app.pixelColor.rgbaG(best), app.pixelColor.rgbaB(best)
          -- abgedunkelt und leicht ins Blau des Taxi-Umrisses (#0c0f24) gezogen
          ol:putPixel(x, y, app.pixelColor.rgba(math.floor(r * 0.28 + 6), math.floor(g * 0.28 + 8), math.floor(b * 0.3 + 22), 255))
        end
      end
    end
  end
  spr:newCel(outl, i + 1, ol, Point(0, 0))
  spr.frames[i + 1].duration = 0.1
end
local function tag(name, from, to, dir_, color)
  local t = spr:newTag(from + 1, to + 1); t.name = name; t.aniDir = dir_ or AniDir.FORWARD; t.color = color or Color(255, 255, 255)
end
tag("walk", 0, 7, AniDir.FORWARD, Color(120, 200, 255))
tag("stand", 8, 8)
tag("turn", 9, 9)
tag("front", 10, 11)
tag("wave", 12, 14, AniDir.PINGPONG, Color(255, 200, 80))
tag("jump", 15, 15)
tag("land", 16, 16)
spr:saveAs(dir .. "driver.aseprite")
print("driver.aseprite: " .. N .. " Bilder")
