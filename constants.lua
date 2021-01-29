la = love.audio
ld = love.data
le = love.event
lfs = love.filesystem
lg = love.graphics
li = love.image
lk = love.keyboard
lm = love.mouse
lmth = love.math
lt = love.timer
lw = love.window

FLOAT_THRESHOLD = 0.00001

WINDOW_MIN_WIDTH = 640
WINDOW_MIN_HEIGHT = 360

SDF_MAX_BRUSHES = 140
SDF_MAX_LIGHTS = 12
SDF_UNITPLANE = lg.newMesh({{  1, -1,  1,  0 }, -- x, y, u, v
							{ -1, -1,  0,  0 },
							{ -1,  1,  0,  1 },
							{  1,  1,  1,  1 }}, "fan", "static")

NET_LAG_FRAMES = 3
NET_ROLLBACK_FRAMES = 7
NET_RING_FRAMES = NET_LAG_FRAMES + NET_ROLLBACK_FRAMES

FONT_CHARACTERS = " ABCDEFGHIJKLMNOÖPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890!?.,':;-"
FONT_BLOWUP = 1000
FONT_SHRINK = 1 / FONT_BLOWUP

UNIT_TILE = 800
