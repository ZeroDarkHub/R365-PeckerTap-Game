-- Pecker Tap for R36S
-- Native LÖVE/SDL2 port of the browser game in
-- ~/Desktop/peckertap/src/landingpage.jsx. The gameplay coordinate system, physics,
-- collision boxes, difficulty curve, animation timing, and synthesized audio
-- follow that source directly.

-- The browser game is 360x540. The R36S edition keeps that exact 540px design
-- height and extends the world to 720x540, which scales uniformly to 640x480.
-- This fills the landscape LCD without stretching any artwork.
local BASE_W = 360
local W, H = 720, 540
local SCREEN_W, SCREEN_H = 640, 480
local GROUND_H = 64
local GRAVITY = 0.12
local FLAP_FORCE = -4.3
local PIPE_WIDTH = 52
local PIPE_CAP_H = 16
local PIPE_SPEED_BASE = 2.2
local PIPE_SPEED_INC = 0.04
local PIPE_GAP_BASE = 152
local PIPE_GAP_MIN = 108
local PIPE_GAP_DEC = 1.8
local PIPE_SPAWN_BASE = 138
local PIPE_SPAWN_MIN = 82
local PIPE_SPAWN_DEC = 2
local STEP = 1 / 60

local C = {
  sky0={0.310,0.765,0.969}, sky1={0.529,0.808,0.922}, sky2={0.702,0.898,0.988},
  cloud={1,1,1}, cloudShadow={0.847,0.933,0.973},
  ground={0.365,0.541,0.235}, groundStripe={0.290,0.478,0.180}, dirt={0.545,0.388,0.333},
  pipeLight={0.439,0.831,0.290}, pipeMid={0.361,0.733,0.235}, pipeDark={0.220,0.502,0.118},
  birdBody1={1,0.871,0.227}, birdBody2={1,0.659,0}, birdWing={1,0.549,0},
  birdBeak={1,0.420,0.208}, eye={0.102,0.102,0.180},
  yellow={1,0.851,0.239}, orange={1,0.549,0}, white={1,1,1}, red={1,0.420,0.420},
  green={0.290,0.627,0.157}, greenBorder={0.439,0.831,0.290}, panel={0.059,0.059,0.157,0.92}
}

local BIRD_PALETTES = {
  {need=0,name="YELLOW",body1=C.birdBody1,body2=C.birdBody2,wing=C.birdWing},
  {need=10,name="PINK",body1={1,0.57,0.72},body2={0.92,0.24,0.52},wing={1,0.38,0.60}},
  {need=20,name="BLUE",body1={0.36,0.78,1},body2={0.10,0.40,0.85},wing={0.16,0.58,1}},
  {need=30,name="GREEN",body1={0.48,0.91,0.36},body2={0.12,0.56,0.25},wing={0.22,0.72,0.30}},
  {need=40,name="PURPLE",body1={0.74,0.58,1},body2={0.38,0.20,0.72},wing={0.55,0.33,0.88}},
  {need=50,name="BLACK",body1={0.18,0.20,0.24},body2={0.035,0.045,0.06},wing={0.30,0.32,0.38}}
}

-- The complete loop is 115 seconds. Longer phases and three-second crossfades
-- let each weather mood settle in before clear, breeze, rain, storm, and mist
-- flow into one another.
local WEATHER_SEGMENTS = {
  {name="clear",frames=1200}, {name="breeze",frames=900},
  {name="rain",frames=1200}, {name="storm",frames=900},
  {name="mist",frames=1200}, {name="clear",frames=1500}
}
local WEATHER_FADE = 180
local WEATHER_WIND = {clear=1,breeze=2.0,rain=1.45,storm=2.45,mist=0.55}

-- Exact browser palette progression from src/landingpage.jsx.
local SKY_CYCLES = {
  {{0x3a/255,0x8a/255,0xbf/255},{0x87/255,0xce/255,0xeb/255},{0xb3/255,0xe5/255,0xfc/255}},
  {{0x1a/255,0x3a/255,0x6b/255},{0x2d/255,0x5a/255,0x8e/255},{0x7b/255,0xa7/255,0xc7/255}},
  {{0x0f/255,0x1d/255,0x3d/255},{0x1e/255,0x3a/255,0x5f/255},{0x4a/255,0x6d/255,0x8c/255}},
  {{0x05/255,0x0b/255,0x1a/255},{0x0d/255,0x1f/255,0x3c/255},{0x1a/255,0x2d/255,0x4a/255}},
  {{0x1a/255,0x0a/255,0x2e/255},{0x2d/255,0x1b/255,0x4e/255},{0x4a/255,0x2d/255,0x6b/255}},
  {{0x2d/255,0x1a/255,0x0a/255},{0x5c/255,0x3a/255,0x1a/255},{0x8c/255,0x6a/255,0x3a/255}},
  {{0x5c/255,0x2a/255,0x0a/255},{0xa0/255,0x50/255,0x20/255},{0xd4/255,0x84/255,0x4a/255}},
  {{0x3a/255,0x8a/255,0xbf/255},{0x87/255,0xce/255,0xeb/255},{0xb3/255,0xe5/255,0xfc/255}}
}
local STAR_ALPHA = {0,0.15,0.55,1,1,0.7,0.2,0}

local gameCanvas
local fonts = {}
local sounds = {}
local music
local musicVolume = 0.36
local musicMix = {base=0.36,lead=0.30,drive=0}
local musicTier = -1
local nextQuackAt = tonumber(os.getenv("PECKERTAP_QUACK_AT")) or 9
local quackScheduleState = 0x51554143
local pipeGradients = {}
local gs
local accumulator = 0
local lastAction = -10
local elapsed = 0
local analogLatch = false
local shutdownHold = 0
local screenshotPending = os.getenv("PECKERTAP_CAPTURE")
local screenshotFrames = 0
local screenshotCaptureAt = tonumber(os.getenv("PECKERTAP_CAPTURE_FRAME")) or 12
local quitAfterCapture = false

local function color(c, alpha)
  love.graphics.setColor(c[1], c[2], c[3], alpha or c[4] or 1)
end

local function rand(a, b)
  if not a then return love.math.random() end
  if not b then return love.math.random() * a end
  return a + love.math.random() * (b - a)
end

local function mix(a,b,t) return a+(b-a)*t end

local function font(size)
  size = math.max(7, math.floor(size + 0.5))
  if not fonts[size] then
    local ok, f = pcall(love.graphics.newFont, "assets/PressStart2P-Regular.ttf", size)
    fonts[size] = ok and f or love.graphics.newFont(size)
    fonts[size]:setFilter("nearest", "nearest")
  end
  return fonts[size]
end

local function text(str, x, y, size, c, align, width)
  local f = font(size)
  love.graphics.setFont(f)
  align = align or "center"
  width = width or W
  local left = align == "center" and x - width / 2 or x
  local top = y - f:getHeight()/2
  local outline = math.max(1, math.floor(size * 0.095 + 0.5))
  local alpha = c[4] or 1
  love.graphics.setColor(0, 0, 0, 0.7 * alpha)
  for oy=-outline,outline do
    for ox=-outline,outline do
      if ox*ox + oy*oy <= outline*outline + 0.5 then
        love.graphics.printf(str, left + ox, top + oy, width, align)
      end
    end
  end
  color(c)
  love.graphics.printf(str, left, top, width, align)
end

local function rounded(mode, x, y, w, h, r)
  love.graphics.rectangle(mode, x, y, w, h, r, r)
end

local function loadScores()
  local hi, board = 0, {}
  if love.filesystem.getInfo("scores.txt") then
    local raw = love.filesystem.read("scores.txt") or ""
    local first = true
    for line in raw:gmatch("[^\r\n]+") do
      local n = tonumber(line)
      if n then
        if first then hi = math.max(0, math.floor(n)); first = false
        elseif #board < 5 and n > 0 then board[#board+1] = math.floor(n) end
      end
    end
  end
  return hi, board
end

local function saveScores()
  local rows = { tostring(gs.hiScore) }
  for i=1,math.min(5,#gs.leaderboard) do rows[#rows+1] = tostring(gs.leaderboard[i]) end
  love.filesystem.write("scores.txt", table.concat(rows, "\n") .. "\n")
end

local function readFeatherFile(path)
  if not love.filesystem.getInfo(path) then return nil end
  -- love.filesystem.read returns both data and byte count. Store the data
  -- first so tonumber never mistakes that byte count for its optional base.
  local raw=love.filesystem.read(path)
  local value=tonumber(raw)
  if not value then return nil end
  return math.max(0,math.floor(value))
end

local function loadFeathers()
  -- The total only ever increases, so the newest valid value is also the
  -- largest. Keeping two copies prevents a stale or interrupted write from
  -- rolling an unlocked bird back to an earlier color.
  return math.max(readFeatherFile("feathers.txt") or 0,
    readFeatherFile("feathers.backup.txt") or 0)
end

local function saveFeathers()
  local value=tostring(gs.totalFeathers).."\n"
  local primaryOk,primaryError=love.filesystem.write("feathers.txt",value)
  local backupOk,backupError=love.filesystem.write("feathers.backup.txt",value)
  local verified=loadFeathers()
  if not primaryOk or not backupOk or verified~=gs.totalFeathers then
    print(string.format("event=feather_save_failed total=%d primary=%s backup=%s verified=%d",
      gs.totalFeathers,tostring(primaryError or primaryOk),tostring(backupError or backupOk),verified))
    return false
  end
  print(string.format("event=feather_saved total=%d",gs.totalFeathers))
  return true
end

local function birdPalette(total)
  -- Unlocks are permanent: every ten saved feathers selects the next color,
  -- and black remains selected from the fiftieth pickup onward.
  local selected=BIRD_PALETTES[1]
  for _,palette in ipairs(BIRD_PALETTES) do
    if total>=palette.need then selected=palette end
  end
  return selected
end

local function newBird()
  -- Preserve the bird's proven physical screen position while extending the
  -- browser world equally to the left and right.
  return {x=W/2-BASE_W/2+BASE_W*0.22,y=H/2,vy=0,rot=0,squash=1,stretch=1,wingFrame=0,blinkTimer=90,blinkOpen=true}
end

local function newClouds()
  local out,seed = {},0x434c4f55
  local function seeded()
    seed=(seed*1664525+1013904223)%4294967296
    return seed/4294967295
  end
  local count=math.floor(5*W/BASE_W+0.5)
  for i=0,count-1 do
    out[#out+1] = {x=(W/count)*i+seeded()*30,y=20+seeded()*(H*0.22),w=36+seeded()*50,
      speed=0.15+seeded()*0.25,layer=i%2}
  end
  return out
end

local function newStars()
  local out, seed = {}, 42
  local function seeded()
    seed = (seed * 1664525 + 1013904223) % 4294967296
    return seed / 4294967295
  end
  local count=math.floor(55*W/BASE_W+0.5)
  for _=1,count do
    local x,y,r1=seeded(),seeded()*0.78,seeded()
    local radius
    if r1<0.15 then radius=1.5 else radius=seeded()<0.6 and 1 or 0.7 end
    out[#out+1]={x=x,y=y,r=radius,twinkle=seeded()*math.pi*2,twinkleSpd=0.04+seeded()*0.04}
  end
  return out
end

local function newWeatherParticles()
  local out,seed={},0x57454154
  local function seeded()
    seed=(seed*1664525+1013904223)%4294967296
    return seed/4294967295
  end
  for i=1,104 do
    out[i]={x=seeded()*W,y=seeded()*(H-GROUND_H),speed=2.2+seeded()*4.8,
      size=0.7+seeded()*1.8,drift=seeded()*math.pi*2,phase=seeded()*math.pi*2}
  end
  return out
end

local function weatherAt(clock)
  if gs and gs.weatherOverride then return gs.weatherOverride,gs.weatherOverride,0 end
  local total=0
  for _,segment in ipairs(WEATHER_SEGMENTS) do total=total+segment.frames end
  local cursor=clock%total
  for i,segment in ipairs(WEATHER_SEGMENTS) do
    if cursor<segment.frames then
      local nextName=WEATHER_SEGMENTS[i%#WEATHER_SEGMENTS+1].name
      local transition=math.max(0,(cursor-(segment.frames-WEATHER_FADE))/WEATHER_FADE)
      return segment.name,nextName,math.min(1,transition)
    end
    cursor=cursor-segment.frames
  end
  return "clear","clear",0
end

local function weatherAmount(name)
  local current,nextName,t=weatherAt(gs.weatherClock)
  local amount=0
  if current==name then amount=amount+1-t end
  if nextName==name then amount=amount+t end
  return amount
end

local function newState(phase,featherTotal,lifeCount)
  local hi, board = loadScores()
  return {phase=phase or "splash",frame=0,score=0,hiScore=hi,leaderboard=board,bird=newBird(),pipes={},clouds=newClouds(),stars=newStars(),
    particles={},floatScores={},floatFeathers={},groundX=0,shakeMag=0,shakeX=0,shakeY=0,deathTimer=0,menuBob=0,pipeTimer=0,
    skyT=0,skyPhase=1,totalFeathers=featherTotal~=nil and math.max(0,math.floor(featherTotal)) or loadFeathers(),
    lives=math.max(0,math.min(3,math.floor(lifeCount or 3))),nextFeatherIn=2,collectibleState=0x46454154,
    weatherClock=0,weatherParticles=newWeatherParticles(),cloudState=0x434c4f55,effectsState=0x45464658}
end

local ORIGINAL_PIPE_TRAVEL=(BASE_W+16)-(BASE_W*0.22)
local LANDSCAPE_PIPE_TRAVEL=(W+16)-(W/2-BASE_W/2+BASE_W*0.22)
local HORIZONTAL_SPEED_SCALE=LANDSCAPE_PIPE_TRAVEL/ORIGINAL_PIPE_TRAVEL
local function pipeSpeed(score) return (PIPE_SPEED_BASE + score * PIPE_SPEED_INC)*HORIZONTAL_SPEED_SCALE end
local function wingFrame(frame) return math.floor(frame / 6) % 3 end

local function collectibleRandom()
  gs.collectibleState=(gs.collectibleState*1664525+1013904223)%4294967296
  return gs.collectibleState/4294967295
end

local function visualRandom(field,a,b)
  gs[field]=(gs[field]*1664525+1013904223)%4294967296
  local value=gs[field]/4294967295
  if not a then return value end
  if not b then return value*a end
  return a+value*(b-a)
end

local function makePipe(score)
  local gap = math.max(PIPE_GAP_MIN, PIPE_GAP_BASE - score * PIPE_GAP_DEC)
  local minY, maxY = 50, H - GROUND_H - 50 - gap
  local pipe={x=W+16,topH=minY+rand(0,maxY-minY),gap=gap,passed=false}
  gs.nextFeatherIn=gs.nextFeatherIn-1
  if gs.nextFeatherIn<=0 then
    local edge=math.max(25,math.min(33,gap*0.22))
    local upper=collectibleRandom()<0.5
    pipe.feather={y=pipe.topH+(upper and edge or gap-edge),phase=collectibleRandom()*math.pi*2,collected=false}
    gs.nextFeatherIn=3+math.floor(collectibleRandom()*3)
  end
  return pipe
end

local function spawnParticles(x,y,count,palette)
  palette=palette or {C.yellow,C.birdBeak,C.white}
  for i=0,count-1 do
    local angle, speed = visualRandom("effectsState",0,math.pi*2), 1.2+visualRandom("effectsState",0,3.2)
    gs.particles[#gs.particles+1] = {x=x,y=y,vx=math.cos(angle)*speed,vy=math.sin(angle)*speed-1,
      life=1,color=palette[i%#palette+1],size=2+visualRandom("effectsState",0,4)}
  end
end

local function play(name)
  local s = sounds[name]
  if not s then return end
  local clone = s:clone()
  clone:play()
end

local function triggerDeath()
  if gs.phase ~= "play" then return end
  gs.lives=math.max(0,gs.lives-1)
  if gs.lives==0 then
    gs.totalFeathers=0
    saveFeathers()
    print("event=feather_progress_reset reason=third_death")
  end
  play("hit")
  play("defeat")
  if music then
    musicVolume=0.06
    musicMix.base,musicMix.lead,musicMix.drive=0.025,0.018,0
    for _,layer in ipairs(music) do layer:setVolume(0.025) end
  end
  gs.phase, gs.deathTimer, gs.shakeMag = "dying", 0, 11
  spawnParticles(gs.bird.x, gs.bird.y, 14)
  if gs.score>0 then
    gs.leaderboard[#gs.leaderboard+1] = gs.score
    table.sort(gs.leaderboard, function(a,b) return a>b end)
    while #gs.leaderboard > 5 do table.remove(gs.leaderboard) end
  end
  saveScores()
  print(string.format("event=game_over score=%d best=%d lives=%d", gs.score, gs.hiScore, gs.lives))
end

local function tickParticles()
  for i=#gs.particles,1,-1 do
    local p=gs.particles[i]; p.x=p.x+p.vx; p.y=p.y+p.vy; p.vy=p.vy+0.13; p.life=p.life-0.032
    if p.life<=0 then table.remove(gs.particles,i) end
  end
end

local function featherPose(pipe)
  local feather=pipe.feather
  local drift=gs.frame*0.052+feather.phase
  local x=pipe.x+PIPE_WIDTH/2+math.sin(drift)*3.8
  local y=feather.y+math.sin(gs.frame*0.074+feather.phase)*4.5
    +math.sin(gs.frame*0.023+feather.phase*1.7)*1.5
  local angle=-0.08+math.sin(gs.frame*0.043+feather.phase)*0.25
    +math.sin(gs.frame*0.019+feather.phase*0.7)*0.06
  local scale=0.98+math.sin(gs.frame*0.061+feather.phase)*0.035
  return x,y,angle,scale
end

local function collectFeather(pipe,bird)
  local feather=pipe.feather
  if not feather or feather.collected then return end
  local fx,fy=featherPose(pipe)
  local dx,dy=bird.x-fx,bird.y-fy
  if dx*dx+dy*dy>21*21 then return end
  feather.collected=true
  gs.totalFeathers=gs.totalFeathers+1
  saveFeathers()
  play("collect")
  gs.shakeMag=math.max(gs.shakeMag,2.8)
  spawnParticles(fx,fy,18,{C.yellow,{1,0.97,0.55},C.white})
  gs.floatFeathers[#gs.floatFeathers+1]={x=fx,y=fy-18,life=1}
  print(string.format("event=feather_collected total=%d",gs.totalFeathers))
end

local function fixedUpdate()
  gs.frame = gs.frame + 1
  gs.menuBob = math.sin(gs.frame * 0.055) * 5
  if gs.phase == "splash" then
    if gs.frame >= 105 then gs.phase="menu"; gs.frame=0 end
    return
  end
  gs.weatherClock=gs.weatherClock+1
  local weatherNow,weatherNext,weatherT=weatherAt(gs.weatherClock)
  local wind=mix(WEATHER_WIND[weatherNow] or 1,WEATHER_WIND[weatherNext] or 1,weatherT)
  for _,c in ipairs(gs.clouds) do
    c.x=c.x-c.speed*wind
    if c.x+c.w<0 then
      c.x=W+8; c.y=20+visualRandom("cloudState",0,H*0.22); c.w=36+visualRandom("cloudState",0,50)
    end
  end
  local groundSpeed=(gs.phase=="play" or gs.phase=="dying") and pipeSpeed(gs.score) or 0.5
  gs.groundX=(gs.groundX-groundSpeed)%40
  if gs.phase=="menu" then
    gs.bird.x=W/2; gs.bird.y=288+gs.menuBob; gs.bird.vy=0
    gs.bird.rot=0; gs.bird.wingFrame=wingFrame(gs.frame); return
  end
  if gs.phase=="ready" then
    gs.bird.x=W/2-BASE_W/2+BASE_W*0.22; gs.bird.y=H/2+gs.menuBob; gs.bird.vy=0
    gs.bird.rot=0; gs.bird.wingFrame=wingFrame(gs.frame); return
  end
  if gs.phase=="dying" then
    gs.deathTimer=gs.deathTimer+1; gs.bird.vy=gs.bird.vy+0.46*1.6; gs.bird.y=gs.bird.y+gs.bird.vy
    gs.bird.rot=math.min(90,gs.bird.rot+9); gs.shakeMag=gs.shakeMag*0.78
    gs.shakeX=(rand()-0.5)*gs.shakeMag; gs.shakeY=(rand()-0.5)*gs.shakeMag
    if gs.deathTimer>55 then gs.phase="dead" end
    tickParticles(); return
  end
  if gs.phase=="dead" then return end
  local b=gs.bird
  b.vy=b.vy+GRAVITY; b.y=b.y+b.vy
  local target=math.min(90,math.max(-22,b.vy*5.2)); b.rot=b.rot+(target-b.rot)*0.14
  b.squash=b.squash+(1-b.squash)*0.22; b.stretch=b.stretch+(1-b.stretch)*0.22
  b.wingFrame=wingFrame(gs.frame); b.blinkTimer=b.blinkTimer-1
  if b.blinkTimer<=0 then b.blinkOpen=not b.blinkOpen; b.blinkTimer=b.blinkOpen and (80+rand(0,120)) or 7 end
  gs.shakeMag=gs.shakeMag*0.82; gs.shakeX=(rand()-0.5)*gs.shakeMag; gs.shakeY=(rand()-0.5)*gs.shakeMag
  if gs.skyT<1 then gs.skyT=math.min(1,gs.skyT+0.016) end
  gs.pipeTimer=gs.pipeTimer+1
  local spawnEvery=math.max(PIPE_SPAWN_MIN,PIPE_SPAWN_BASE-gs.score*PIPE_SPAWN_DEC)
  if gs.pipeTimer>=spawnEvery then gs.pipeTimer=0; gs.pipes[#gs.pipes+1]=makePipe(gs.score) end
  local speed=pipeSpeed(gs.score)
  for i=#gs.pipes,1,-1 do
    local p=gs.pipes[i]; p.x=p.x-speed
    collectFeather(p,b)
    if p.x<=-PIPE_WIDTH-20 then table.remove(gs.pipes,i)
    elseif not p.passed and p.x+PIPE_WIDTH<b.x then
      p.passed=true; gs.score=gs.score+1
      if gs.score>gs.hiScore then gs.hiScore=gs.score; saveScores() end
      play("score"); gs.floatScores[#gs.floatScores+1]={x=b.x+20,y=b.y-22,life=1}
      if gs.score%10==0 then gs.skyPhase=gs.skyPhase%#SKY_CYCLES+1; gs.skyT=0 end
    end
  end
  for i=#gs.floatScores,1,-1 do
    local f=gs.floatScores[i]; f.y=f.y-1.4; f.life=f.life-0.028
    if f.life<=0 then table.remove(gs.floatScores,i) end
  end
  for i=#gs.floatFeathers,1,-1 do
    local f=gs.floatFeathers[i]; f.y=f.y-1.1; f.life=f.life-0.022
    if f.life<=0 then table.remove(gs.floatFeathers,i) end
  end
  tickParticles()
  local bx,by,bw,bh=b.x-11,b.y-11,22,22
  if b.y>=H-GROUND_H-14 or b.y<=12 then triggerDeath(); return end
  for _,p in ipairs(gs.pipes) do
    if bx+bw>p.x+4 and bx<p.x+PIPE_WIDTH-4 and (by<p.topH or by+bh>p.topH+p.gap) then triggerDeath(); return end
  end
end

local function sky()
  local cur=SKY_CYCLES[gs.skyPhase]
  local nxt=SKY_CYCLES[gs.skyPhase%#SKY_CYCLES+1]
  for y=0,H-1,4 do
    local pos=y/(H-1); local a,b,lt
    if pos<0.5 then a,b,lt=cur[1],cur[2],pos/0.5 else a,b,lt=cur[2],cur[3],(pos-0.5)/0.5 end
    local na,nb
    if pos<0.5 then na,nb=nxt[1],nxt[2] else na,nb=nxt[2],nxt[3] end
    local nr=mix(na[1],nb[1],lt); local ng=mix(na[2],nb[2],lt); local nbl=mix(na[3],nb[3],lt)
    love.graphics.setColor(mix(mix(a[1],b[1],lt),nr,gs.skyT),mix(mix(a[2],b[2],lt),ng,gs.skyT),mix(mix(a[3],b[3],lt),nbl,gs.skyT),1)
    love.graphics.rectangle("fill",0,y,W,4)
  end
end

local function starAlpha()
  local cur=STAR_ALPHA[gs.skyPhase]
  local nxt=STAR_ALPHA[gs.skyPhase%#STAR_ALPHA+1]
  return mix(cur,nxt,gs.skyT)
end

local function drawStars()
  local alpha=starAlpha()
  if alpha<=0 then return end
  for _,s in ipairs(gs.stars) do
    local twinkle=0.8+0.2*math.sin(gs.frame*s.twinkleSpd+s.twinkle)
    love.graphics.setColor(1,1,1,alpha*twinkle)
    love.graphics.circle("fill",s.x*W,s.y*(H-GROUND_H),s.r)
    if s.r>=1.4 then
      love.graphics.setColor(1,1,1,alpha*twinkle*0.4)
      love.graphics.rectangle("fill",s.x*W-3,s.y*(H-GROUND_H)-0.5,6,1)
      love.graphics.rectangle("fill",s.x*W-0.5,s.y*(H-GROUND_H)-3,1,6)
    end
  end
end

local function drawCloud(c, visibility)
  local h=c.w*0.44; color(C.cloud,(c.layer==0 and 0.52 or 0.9)*(visibility or 1))
  love.graphics.circle("fill",c.x+c.w*0.28,c.y+h*0.65,h*0.52)
  love.graphics.circle("fill",c.x+c.w*0.58,c.y+h*0.38,h*0.68)
  love.graphics.circle("fill",c.x+c.w*0.52,c.y+h*0.72,h*0.44)
end

local function drawWeatherBackgroundMode(mode,alpha)
  if alpha<=0 then return end
  if mode=="rain" then
    love.graphics.setColor(0.12,0.24,0.38,0.08*alpha)
    love.graphics.rectangle("fill",0,0,W,H-GROUND_H)
  elseif mode=="storm" then
    love.graphics.setColor(0.025,0.045,0.11,0.28*alpha)
    love.graphics.rectangle("fill",0,0,W,H-GROUND_H)
    local flash=gs.weatherClock%420
    if (flash>=252 and flash<=255) or (flash>=270 and flash<=271) then
      love.graphics.setColor(0.78,0.88,1,0.34*alpha)
      love.graphics.rectangle("fill",0,0,W,H-GROUND_H)
    end
  elseif mode=="mist" then
    love.graphics.setColor(0.86,0.92,0.96,0.08*alpha)
    love.graphics.rectangle("fill",0,0,W,H-GROUND_H)
    for i=1,10 do
      local p=gs.weatherParticles[i]
      local x=(p.x+gs.frame*(0.08+p.size*0.025))%(W+180)-90
      local y=105+(i%5)*68+math.sin(gs.frame*0.012+p.phase)*12
      love.graphics.setColor(0.93,0.97,1,(0.025+p.size*0.014)*alpha)
      love.graphics.ellipse("fill",x,y,80+p.size*34,18+p.size*6)
    end
  end
end

local function drawWeatherBackground()
  local current,nextName,t=weatherAt(gs.weatherClock)
  drawWeatherBackgroundMode(current,1-t)
  drawWeatherBackgroundMode(nextName,t)
end

local function drawWeatherForegroundMode(mode,alpha)
  if alpha<=0 then return end
  if mode=="rain" or mode=="storm" then
    local storm=mode=="storm"
    local count=storm and 104 or 72
    love.graphics.setLineWidth(storm and 1.6 or 1.1)
    for i=1,count do
      local p=gs.weatherParticles[i]
      local fall=storm and 1.65 or 1.15
      local x=(p.x-gs.frame*p.speed*0.52*fall)%(W+50)-20
      local y=(p.y+gs.frame*p.speed*fall)%(H-GROUND_H+30)-15
      love.graphics.setColor(0.72,0.86,1,(storm and 0.34 or 0.24)*alpha)
      love.graphics.line(x,y,x-5-p.size*2,y+11+p.size*5)
    end
  elseif mode=="breeze" then
    love.graphics.setLineWidth(1)
    for i=4,64,6 do
      local p=gs.weatherParticles[i]
      local x=(p.x-gs.frame*(1.5+p.speed*0.3))%(W+90)-45
      local y=55+(p.y%(H-GROUND_H-90))
      love.graphics.setColor(1,1,1,0.12*alpha)
      love.graphics.line(x,y,x+12+p.size*6,y+math.sin(gs.frame*0.03+p.phase)*2)
    end
  end
end

local function drawWeatherForeground()
  local current,nextName,t=weatherAt(gs.weatherClock)
  drawWeatherForegroundMode(current,1-t)
  drawWeatherForegroundMode(nextName,t)
end

local function gradientSample(t)
  local a,b,u
  if t<=0.22 then a,b,u=C.pipeDark,C.pipeLight,t/0.22
  elseif t<=0.78 then a,b,u=C.pipeLight,C.pipeMid,(t-0.22)/0.56
  else a,b,u=C.pipeMid,C.pipeDark,(t-0.78)/0.22 end
  return mix(a[1],b[1],u),mix(a[2],b[2],u),mix(a[3],b[3],u)
end

local function makePipeGradient(w)
  local data=love.image.newImageData(w,1)
  for x=0,w-1 do
    local r,g,b=gradientSample(x/(w-1)); data:setPixel(x,0,r,g,b,1)
  end
  local image=love.graphics.newImage(data); image:setFilter("linear","linear")
  return image
end

local function pipeGradientRect(x,y,w,h)
  love.graphics.setColor(1,1,1,1)
  love.graphics.draw(pipeGradients[w],x,y,0,1,h)
end

local function drawPipe(p)
  local capX,capW=p.x-5,PIPE_WIDTH+10
  pipeGradientRect(p.x,0,PIPE_WIDTH,p.topH-PIPE_CAP_H)
  pipeGradientRect(capX,p.topH-PIPE_CAP_H,capW,PIPE_CAP_H)
  love.graphics.setColor(1,1,1,0.22)
  love.graphics.rectangle("fill",p.x+5,0,6,p.topH)
  love.graphics.rectangle("fill",capX+4,p.topH-PIPE_CAP_H,6,PIPE_CAP_H)
  love.graphics.setColor(0,0,0,0.14); love.graphics.rectangle("fill",p.x+PIPE_WIDTH-9,0,9,p.topH)
  local botY=p.topH+p.gap
  pipeGradientRect(p.x,botY+PIPE_CAP_H,PIPE_WIDTH,H-botY-PIPE_CAP_H)
  pipeGradientRect(capX,botY,capW,PIPE_CAP_H)
  love.graphics.setColor(1,1,1,0.22)
  love.graphics.rectangle("fill",p.x+5,botY+PIPE_CAP_H,6,H-botY)
  love.graphics.rectangle("fill",capX+4,botY,6,PIPE_CAP_H)
  love.graphics.setColor(0,0,0,0.14); love.graphics.rectangle("fill",p.x+PIPE_WIDTH-9,botY,9,H-botY)
end

local function drawFeatherShape(x,y,scale,angle,alpha)
  local a=alpha or 1
  love.graphics.push(); love.graphics.translate(x,y); love.graphics.rotate(angle or 0); love.graphics.scale(scale or 1)

  -- A lightly notched silhouette reads as a real feather even at HUD size.
  love.graphics.setColor(1,0.75,0.08,a)
  love.graphics.polygon("fill",
    0,-17, 4,-14, 7,-11, 6,-8, 9,-6, 7,-3, 10,-1, 7,2,
    8,5, 5,6, 5,9, 2,10, 0,14,
    -3,12, -3,9, -7,8, -5,5, -9,3, -6,0, -9,-2, -6,-5,
    -7,-8, -4,-10, -4,-13)
  love.graphics.setColor(1,0.91,0.24,0.72*a)
  love.graphics.polygon("fill",0,-15,4,-13,7,-10,6,-7,8,-5,6,-2,8,0,5,2,6,5,3,6,2,10,-1,12,-0.5,0)
  love.graphics.setColor(1,0.98,0.62,0.55*a)
  love.graphics.polygon("fill",-1,-14,2,-12,3,-9,1,-5,-2,-4,-3,-9)

  -- Dark under-stroke plus a warm highlight keeps the curved shaft distinct.
  love.graphics.setLineWidth(2.6)
  love.graphics.setColor(0.62,0.30,0.03,0.82*a)
  love.graphics.line(0,-14,0,-7,-0.3,0,-1,8,-2,18)
  love.graphics.setLineWidth(1.15)
  love.graphics.setColor(1,0.95,0.53,a)
  love.graphics.line(0,-14,0,-7,-0.3,0,-1,8,-2,18)

  -- Fine barbs branch away from the shaft in the alternating pattern found
  -- on a feather vane. They are deliberately bold enough for the R36S LCD.
  love.graphics.setLineWidth(1.25)
  love.graphics.setColor(0.67,0.32,0.03,0.76*a)
  love.graphics.line(0,-11,4,-13); love.graphics.line(0,-8,6,-10)
  love.graphics.line(-0.1,-5,7,-7); love.graphics.line(-0.2,-2,8,-4)
  love.graphics.line(-0.3,1,7,-1); love.graphics.line(-0.6,4,6,3)
  love.graphics.line(-0.8,7,4,7); love.graphics.line(-1,9,2,10)
  love.graphics.line(0,-10,-4,-13); love.graphics.line(0,-7,-6,-10)
  love.graphics.line(-0.1,-4,-7,-7); love.graphics.line(-0.2,-1,-8,-4)
  love.graphics.line(-0.4,2,-7,0); love.graphics.line(-0.6,5,-7,3)
  love.graphics.line(-0.8,8,-5,6); love.graphics.line(-1,10,-3,9)

  love.graphics.setLineWidth(1.35)
  love.graphics.setColor(0.54,0.25,0.02,0.76*a)
  love.graphics.polygon("line",
    0,-17, 4,-14, 7,-11, 6,-8, 9,-6, 7,-3, 10,-1, 7,2,
    8,5, 5,6, 5,9, 2,10, 0,14,
    -3,12, -3,9, -7,8, -5,5, -9,3, -6,0, -9,-2, -6,-5,
    -7,-8, -4,-10, -4,-13)
  love.graphics.pop()
end

local function drawCollectible(pipe)
  if not pipe.feather or pipe.feather.collected then return end
  local feather=pipe.feather
  local x,y,angle,featherScale=featherPose(pipe)
  local glow=0.55+0.25*math.sin(gs.frame*0.11+feather.phase)
  love.graphics.setColor(1,0.85,0.22,0.11+glow*0.13); love.graphics.circle("fill",x,y,21)
  love.graphics.setColor(1,0.94,0.42,0.07+glow*0.08); love.graphics.circle("fill",x,y,27)
  for i=0,3 do
    local a=gs.frame*0.021+feather.phase+i*math.pi/2
    love.graphics.setColor(1,0.95,0.55,0.42)
    love.graphics.circle("fill",x+math.cos(a)*19,y+math.sin(a)*14,1.35)
  end
  drawFeatherShape(x,y,0.94*featherScale,angle,1)
end

local function drawGround()
  local gy=H-GROUND_H; color(C.ground); love.graphics.rectangle("fill",0,gy,W,GROUND_H)
  color(C.dirt); love.graphics.rectangle("fill",0,gy+18,W,GROUND_H-18)
  color(C.groundStripe)
  for i=0,W+44,22 do love.graphics.rectangle("fill",((i+gs.groundX)%W)-4,gy,11,18) end
  love.graphics.setColor(1,1,1,0.2); love.graphics.rectangle("fill",0,gy,W,2)
  love.graphics.setColor(0,0,0,0.2); love.graphics.rectangle("fill",0,gy+18,W,2)
end

local function drawBird(b)
  local palette=birdPalette(gs.totalFeathers)
  love.graphics.push(); love.graphics.translate(math.floor(b.x),math.floor(b.y)); love.graphics.rotate(math.rad(b.rot)); love.graphics.scale(b.stretch,b.squash)
  color(palette.body2); rounded("fill",-14,-14,28,28,7)
  color(palette.body1); rounded("fill",-12,-12,24,24,6)
  love.graphics.push(); love.graphics.translate(-3,-4); love.graphics.rotate(-0.3)
  love.graphics.setColor(1,1,1,0.35); love.graphics.ellipse("fill",0,0,6,4.5); love.graphics.pop()
  local wingY=({3,5,7})[math.min(b.wingFrame+1,3)]
  color(palette.wing); rounded("fill",-15,wingY,10,7,3)
  color(C.white); love.graphics.circle("fill",5,-4,5)
  if b.blinkOpen then
    color(C.eye); love.graphics.circle("fill",6,-4,3); color(C.white); love.graphics.circle("fill",7,-5.2,1)
  else
    color(palette.body2); love.graphics.rectangle("fill",1,-7,9,5); color(C.eye); love.graphics.rectangle("fill",2,-6,7,2)
  end
  color(C.birdBeak); love.graphics.polygon("fill",13,-3.5,23,0.5,13,4.5)
  love.graphics.pop()
end

local function pixelHeartShape(x,y,block)
  love.graphics.rectangle("fill",x+block,y,block*2,block)
  love.graphics.rectangle("fill",x+block*4,y,block*2,block)
  love.graphics.rectangle("fill",x,y+block,block*7,block*2)
  love.graphics.rectangle("fill",x+block,y+block*3,block*5,block)
  love.graphics.rectangle("fill",x+block*2,y+block*4,block*3,block)
  love.graphics.rectangle("fill",x+block*3,y+block*5,block,block)
end

local function drawPixelHeart(x,y,active)
  love.graphics.setColor(0.18,0.03,0.08,active and 0.88 or 0.42)
  pixelHeartShape(x+1,y+1,2)
  love.graphics.setColor(active and 0.96 or 0.18,active and 0.16 or 0.10,active and 0.22 or 0.14,active and 1 or 0.48)
  pixelHeartShape(x,y,2)
  if active then
    love.graphics.setColor(1,0.58,0.62,1)
    love.graphics.rectangle("fill",x+4,y+2,2,2)
  end
end

local function drawHUD()
  love.graphics.setColor(0,0,0,0.3); rounded("fill",W/2-32,8,64,36,8)
  text(tostring(gs.score),W/2,26,22,C.white)
  drawFeatherShape(31,26,0.62,-0.12,1)
  text(tostring(gs.totalFeathers),47,26,11,C.yellow,"left",42)
  for i=1,3 do drawPixelHeart(96+(i-1)*18,20,i<=gs.lives) end
end

local function drawMenu()
  local palette=birdPalette(gs.totalFeathers)

  -- The opening screen is arranged as one centered stack, with a dedicated
  -- band for each kind of information so labels stay legible on the 640x480 LCD.
  local titleX,titleY,titleW,titleH=W/2-231,20,462,88
  love.graphics.setColor(0.02,0.04,0.10,0.82); rounded("fill",titleX,titleY,titleW,titleH,14)
  love.graphics.setColor(1,0.851,0.239,0.42); love.graphics.setLineWidth(2); rounded("line",titleX,titleY,titleW,titleH,14)
  text("PECKER TAP",W/2,titleY+36,36,C.yellow,"center",titleW-24)
  text("SKYBOUND ARCADE",W/2,titleY+70,9,{1,0.78,0.29,0.9},"center",titleW-24)

  local statsX,statsY,statsW,statsH=W/2-158,120,316,76
  love.graphics.setColor(0.02,0.04,0.10,0.76); rounded("fill",statsX,statsY,statsW,statsH,12)
  love.graphics.setColor(1,1,1,0.10); love.graphics.setLineWidth(1); rounded("line",statsX,statsY,statsW,statsH,12)
  love.graphics.setColor(1,1,1,0.12); love.graphics.rectangle("fill",W/2,statsY+11,1,statsH-22)
  text("HIGH SCORE",statsX+statsW*0.25,statsY+19,9,{0.82,0.88,0.96},"center",statsW/2-20)
  text(tostring(gs.hiScore),statsX+statsW*0.25,statsY+50,23,C.yellow,"center",statsW/2-20)
  text("FEATHERS",statsX+statsW*0.75,statsY+19,9,{0.82,0.88,0.96},"center",statsW/2-20)
  text(tostring(gs.totalFeathers),statsX+statsW*0.75,statsY+45,23,C.yellow,"center",statsW/2-20)
  text(palette.name.." BIRD",statsX+statsW*0.75,statsY+65,7,{1,0.74,0.34,0.88},"center",statsW/2-16)

  local pulse=0.7+(0.5+0.5*math.sin(gs.frame*0.1))*0.3
  local buttonX,buttonY,buttonW,buttonH=W/2-112,210,224,50
  love.graphics.setColor(0.05,0.22,0.10,0.82); rounded("fill",buttonX,buttonY,buttonW,buttonH,11)
  love.graphics.setColor(0.55,1,0.32,0.54+0.30*pulse); love.graphics.setLineWidth(2); rounded("line",buttonX,buttonY,buttonW,buttonH,11)
  text("TAP TO START",W/2,buttonY+buttonH/2,16,{1,1,1,pulse},"center",buttonW-18)

  local rows=math.max(1,math.min(#gs.leaderboard,5)); local rowH=19
  local panelH=38+rows*rowH+6; local panelY=326; local panelW=250; local panelX=W/2-panelW/2
  love.graphics.setColor(0.02,0.04,0.10,0.68); rounded("fill",panelX,panelY,panelW,panelH,11)
  love.graphics.setColor(1,0.851,0.239,0.30); love.graphics.setLineWidth(1); rounded("line",panelX,panelY,panelW,panelH,11)
  text("TOP SCORES",W/2,panelY+18,11,C.yellow,"center",panelW-24)
  love.graphics.setColor(1,1,1,0.10); love.graphics.rectangle("fill",panelX+14,panelY+34,panelW-28,1)
  if #gs.leaderboard>0 then
    local medals={C.yellow,{0.75,0.75,0.75},{0.80,0.50,0.20},{0.67,0.67,0.67},{0.67,0.67,0.67}}
    for i=1,math.min(#gs.leaderboard,5) do
      local ry=panelY+39+(i-1)*rowH+rowH/2-1
      text("#"..i,panelX+22,ry,9,medals[i],"left",56)
      text(tostring(gs.leaderboard[i]),panelX+panelW-82,ry,10,C.white,"right",60)
    end
  elseif gs.hiScore>0 then
    text("BEST  "..gs.hiScore,W/2,panelY+48,10,C.yellow,"center",panelW-28)
  else
    text("NO SCORES YET",W/2,panelY+48,8,{1,1,1,0.52},"center",panelW-28)
  end
end

local function drawReady()
  text("GET READY!",W/2,80,BASE_W*0.036,C.white)
end

local function drawDead()
  if gs.phase=="dying" and gs.deathTimer<=20 then return end
  local py,panelH=H*0.2,176
  love.graphics.setColor(0,0,0,0.5); love.graphics.rectangle("fill",0,0,W,H)
  color(C.panel); rounded("fill",W/2-100,py,200,panelH,14)
  color(C.yellow); love.graphics.setLineWidth(2.5); rounded("line",W/2-100,py,200,panelH,14)
  text("GAME OVER",W/2,py+30,BASE_W*0.052,C.red)
  love.graphics.setColor(1,1,1,0.07); love.graphics.rectangle("fill",W/2-80,py+48,160,1)
  text("SCORE",W/2-46,py+64,BASE_W*0.024,{0.6,0.6,0.6}); text("BEST",W/2+50,py+64,BASE_W*0.024,{0.6,0.6,0.6})
  text(tostring(gs.score),W/2-46,py+92,24,C.white); text(tostring(gs.hiScore),W/2+50,py+92,24,gs.score>0 and gs.score>=gs.hiScore and C.yellow or C.white)
  if gs.score>0 and gs.score>=gs.hiScore then text("NEW!",W/2+50,py+110,BASE_W*0.022,C.yellow) end
  if gs.phase=="dead" then
    color(C.green,0.82+0.18*math.sin(gs.frame*0.13)); rounded("fill",W/2-70,py+126,140,40,10)
    color(C.greenBorder); love.graphics.setLineWidth(2); rounded("line",W/2-70,py+126,140,40,10); text("PLAY AGAIN",W/2,py+146,BASE_W*0.032,C.white)
  end
end

local function drawPlayfield()
  love.graphics.setCanvas(gameCanvas); love.graphics.clear(0,0,0,1); love.graphics.push(); love.graphics.translate(math.floor(gs.shakeX),math.floor(gs.shakeY))
  sky(); drawStars()
  local cloudVis=math.max(0,1-starAlpha()*1.4)
  if cloudVis>0.01 then
    for _,c in ipairs(gs.clouds) do drawCloud(c,cloudVis) end
  end
  drawWeatherBackground()
  for _,p in ipairs(gs.pipes) do drawPipe(p); drawCollectible(p) end; drawGround()
  for _,p in ipairs(gs.particles) do color(p.color,math.max(0,p.life)); rounded("fill",p.x-p.size/2,p.y-p.size/2,p.size,p.size,2) end
  if gs.phase~="dead" then drawBird(gs.bird) end
  for _,f in ipairs(gs.floatScores) do color(C.yellow,math.max(0,f.life)); text("+1",f.x,f.y,16,C.yellow) end
  for _,f in ipairs(gs.floatFeathers) do text("FEATHER!",f.x,f.y,9,{1,0.90,0.28,math.max(0,f.life)}) end
  drawWeatherForeground()
  love.graphics.pop()
  if gs.phase=="menu" then drawMenu() elseif gs.phase=="ready" then drawHUD(); drawReady()
  elseif gs.phase=="play" then drawHUD() elseif gs.phase=="dying" or gs.phase=="dead" then drawHUD(); drawDead() end
  love.graphics.setCanvas()
end

local function drawOuterBackground()
  love.graphics.clear(0.018,0.027,0.060,1)
end

local function drawSplash()
  drawOuterBackground(); local pulse=0.82+0.18*math.sin(gs.frame*0.08)
  love.graphics.setColor(1,0.851,0.239,0.10); rounded("fill",SCREEN_W/2-245,62,490,350,22)
  love.graphics.setColor(1,0.851,0.239,0.25); love.graphics.setLineWidth(2); rounded("line",SCREEN_W/2-245,62,490,350,22)
  color(C.birdBody1); rounded("fill",SCREEN_W/2-45,104,90,90,18); color(C.birdBody2); love.graphics.setLineWidth(7); rounded("line",SCREEN_W/2-45,104,90,90,18)
  color(C.white); love.graphics.circle("fill",SCREEN_W/2+18,136,16); color(C.eye); love.graphics.circle("fill",SCREEN_W/2+21,137,9); color(C.white); love.graphics.circle("fill",SCREEN_W/2+24,133,3)
  color(C.birdBeak); love.graphics.polygon("fill",SCREEN_W/2+42,144,SCREEN_W/2+76,156,SCREEN_W/2+42,167)
  text("PECKER TAP",SCREEN_W/2,256,34,C.yellow,"center",540)
  color(C.white,pulse); text("R36S EDITION",SCREEN_W/2,312,11,{0.75,0.85,1},"center",420)
  text("SKYBOUND ARCADE",SCREEN_W/2,374,9,{0.45,0.9,0.6},"center",400)
end

local function makeTone(duration, parts)
  local rate, samples = 22050, math.floor(duration*22050)
  local data=love.sound.newSoundData(samples,rate,16,1)
  for i=0,samples-1 do
    local t=i/rate; local v=0
    for _,p in ipairs(parts) do
      if t>=p.start and t<p.start+p.duration then
        local u=(t-p.start)/p.duration; local f=p.f1*(p.f2/p.f1)^u; local env=math.exp(-6*u)
        local wave=p.wave=="square" and (math.sin(2*math.pi*f*(t-p.start))>=0 and 1 or -1)
          or p.wave=="saw" and (2*((f*(t-p.start))%1)-1) or math.sin(2*math.pi*f*(t-p.start))
        v=v+wave*p.gain*env
      end
    end
    data:setSample(i,math.max(-1,math.min(1,v)))
  end
  return love.audio.newSource(data,"static")
end

-- A tight two-call cue cut from a real female mallard field recording. Keeping
-- it as PCM WAV makes playback dependable on the handheld's offline runtime.
local function loadQuack()
  local source=love.audio.newSource("assets/duck-quack-quack.wav","static")
  source:setVolume(0.78)
  return source
end

local function nextQuackDelay()
  quackScheduleState = (quackScheduleState * 1664525 + 1013904223) % 4294967296
  return 10 + (quackScheduleState / 4294967295) * 12
end

-- Original "Skybound Peck" theme, split into synchronized base, lead, and drive
-- layers. Score, sky, and weather continuously reshape their mix while all
-- synthesis remains local and offline.
local function makeSoundtrack()
  local rate, bpm, totalSteps = 22050, 150, 128
  local stepDuration = 60 / bpm / 4
  local duration = totalSteps * stepDuration
  local samples = math.floor(duration * rate)
  local baseData = love.sound.newSoundData(samples, rate, 16, 1)
  local leadData = love.sound.newSoundData(samples, rate, 16, 1)
  local driveData = love.sound.newSoundData(samples, rate, 16, 1)

  local lead = {
    74,77,81,86,84,81,77,0, 70,74,77,82,81,77,74,0,
    72,77,81,84,81,77,72,0, 72,76,79,84,83,79,76,0,
    74,77,81,86,89,86,84,81, 67,70,74,79,77,74,70,0,
    70,74,77,82,84,82,81,77, 69,73,76,81,79,76,73,0
  }
  local chords = {
    {62,65,69}, {58,62,65}, {60,65,69}, {60,64,67},
    {62,65,69}, {55,58,62}, {58,62,65}, {57,61,64}
  }
  local bassRoots = {50,46,53,48,50,43,46,45}
  local arpOrder = {1,2,3,2,1,2,3,2}
  local noiseState = 0x5045434b

  local function hz(note) return 440 * 2 ^ ((note - 69) / 12) end
  local function pulse(phase, duty) return phase % 1 < duty and 1 or -1 end
  local function triangle(phase) return 1 - 4 * math.abs(phase % 1 - 0.5) end
  local function envelope(position, length, attack, release)
    return math.min(1, position / attack, math.max(0, (length - position) / release))
  end
  local function noise()
    noiseState = (noiseState * 1664525 + 1013904223) % 4294967296
    return noiseState / 2147483648 - 1
  end

  for i=0,samples-1 do
    local t = i / rate
    local stepFloat = t / stepDuration
    local stepIndex = math.floor(stepFloat) % totalSteps
    local bar = math.floor(stepIndex / 16) + 1
    local inStep = (stepFloat - math.floor(stepFloat)) * stepDuration
    local baseV,leadV,driveV = 0,0,0

    -- Lead notes last an eighth note, with a tiny vibrato that gives the tune
    -- a hand-played arcade quality without blurring the pitch.
    local leadIndex = math.floor(stepIndex / 2) + 1
    local leadNote = lead[leadIndex]
    if leadNote and leadNote > 0 then
      local notePos = (stepIndex % 2) * stepDuration + inStep
      local noteLen = stepDuration * 2
      local env = envelope(notePos, noteLen * 0.9, 0.012, 0.045)
      local vibrato = math.sin(2 * math.pi * 5.2 * t) * 0.0022
      leadV = leadV + pulse(t * hz(leadNote) + vibrato, 0.25) * env * 0.22
    end

    -- A bright three-note arpeggio supplies the classic handheld shimmer.
    local chord = chords[bar]
    local arpNote = chord[arpOrder[stepIndex % 8 + 1]] + 12
    local arpEnv = envelope(inStep, stepDuration * 0.78, 0.004, 0.028)
    baseV = baseV + pulse(t * hz(arpNote), 0.125) * arpEnv * 0.075

    -- Bass changes on quarter notes and alternates root, octave, and fifth.
    local beat = math.floor((stepIndex % 16) / 4)
    local bassOffsets = {0,12,7,12}
    local bassNote = bassRoots[bar] + bassOffsets[beat + 1]
    local beatPos = (stepIndex % 4) * stepDuration + inStep
    local bassEnv = envelope(beatPos, stepDuration * 3.7, 0.008, 0.08)
    baseV = baseV + triangle(t * hz(bassNote)) * bassEnv * 0.17

    -- Deterministic one-bit percussion: kick on 1/3, snare on 2/4, hats on 8ths.
    local halfBeatPos = (stepIndex % 8) * stepDuration + inStep
    if halfBeatPos < 0.13 then
      local u = halfBeatPos / 0.13
      local kickHz = 105 - 62 * u
      baseV = baseV + math.sin(2 * math.pi * kickHz * halfBeatPos) * math.exp(-7 * u) * 0.28
    end
    local snarePos = ((stepIndex + 4) % 8) * stepDuration + inStep
    local n = noise()
    if snarePos < 0.11 then
      baseV = baseV + n * math.exp(-8 * snarePos / 0.11) * 0.13
    end
    local hatPos = (stepIndex % 2) * stepDuration + inStep
    if hatPos < 0.028 then
      baseV = baseV + n * math.exp(-9 * hatPos / 0.028) * 0.018
      driveV = driveV + n * math.exp(-9 * hatPos / 0.028) * 0.10
    end

    -- The drive layer adds a syncopated octave sparkle and a firmer pulse. It
    -- begins silent, then fades in as the player proves the run.
    if stepIndex%2==1 then
      local driveNote=chord[(math.floor(stepIndex/2)%3)+1]+24
      local driveEnv=envelope(inStep,stepDuration*0.72,0.003,0.025)
      driveV=driveV+pulse(t*hz(driveNote),0.125)*driveEnv*0.07
    end
    if stepIndex%8==6 and inStep<0.09 then
      driveV=driveV+triangle(t*hz(bassRoots[bar]+19))*math.exp(-7*inStep/0.09)*0.09
    end

    -- Fade only the loop seam; this prevents a click without softening the beat.
    local seam = math.min(1, t / 0.012, (duration - t) / 0.012)
    baseData:setSample(i, math.max(-1, math.min(1, baseV * seam)))
    leadData:setSample(i, math.max(-1, math.min(1, leadV * seam)))
    driveData:setSample(i, math.max(-1, math.min(1, driveV * seam)))
  end

  local function layer(data)
    local source=love.audio.newSource(data,"static")
    source:setLooping(true); source:setVolume(0)
    return source
  end
  return {layer(baseData),layer(leadData),layer(driveData)}
end

local function updateMusicMix(dt)
  if not music then return end
  local master=gs.phase=="splash" and 0.36 or gs.phase=="menu" and 0.32
    or (gs.phase=="ready" or gs.phase=="play") and 0.23 or 0.07
  musicVolume=musicVolume+(master-musicVolume)*math.min(1,dt*3.5)
  local night=starAlpha()
  local storm=weatherAmount("storm")
  local rain=weatherAmount("rain")
  local tier=gs.score>=16 and 3 or gs.score>=8 and 2 or gs.score>=3 and 1 or 0
  local energy=({0,0.34,0.68,1})[tier+1]
  local targetBase=musicVolume*(1-night*0.10-storm*0.10)
  local targetLead=musicVolume*(0.94-night*0.36-storm*0.20-rain*0.08)
  local targetDrive=musicVolume*energy*(0.95-night*0.52-storm*0.30-rain*0.10)
  local blend=math.min(1,dt*2.7)
  musicMix.base=mix(musicMix.base,targetBase,blend)
  musicMix.lead=mix(musicMix.lead,targetLead,blend)
  musicMix.drive=mix(musicMix.drive,math.max(0,targetDrive),blend)
  music[1]:setVolume(musicMix.base)
  music[2]:setVolume(musicMix.lead)
  music[3]:setVolume(musicMix.drive)
  if tier~=musicTier then
    musicTier=tier
    print(string.format("event=music_tier tier=%d score=%d",tier,gs.score))
  end
end

local function action()
  if elapsed-lastAction<0.075 then return end
  lastAction=elapsed
  if gs.phase=="splash" then gs.phase="menu"; gs.frame=0; return end
  if gs.phase=="dead" then
    local total=gs.totalFeathers
    local lives=gs.lives>0 and gs.lives or 3
    gs=newState("menu",total,lives)
    saveFeathers()
    return
  end
  if gs.phase=="menu" then gs.phase="ready"; return end
  if gs.phase=="ready" then gs.phase="play" end
  if gs.phase~="play" then return end
  gs.bird.vy=FLAP_FORCE; gs.bird.squash=0.68; gs.bird.stretch=1.32; play("flap")
end

function love.load()
  love.graphics.setDefaultFilter("nearest","nearest")
  love.mouse.setVisible(false); love.mouse.setGrabbed(false)
  love.math.setRandomSeed(tonumber(os.getenv("PECKERTAP_SEED")) or os.time())
  gameCanvas=love.graphics.newCanvas(W,H,{dpiscale=1}); gameCanvas:setFilter("linear","linear")
  pipeGradients[PIPE_WIDTH]=makePipeGradient(PIPE_WIDTH)
  pipeGradients[PIPE_WIDTH+10]=makePipeGradient(PIPE_WIDTH+10)
  sounds.flap=makeTone(0.10,{{start=0,duration=0.09,f1=540,f2=370,gain=0.18,wave="sine"}})
  sounds.score=makeTone(0.27,{{start=0,duration=0.11,f1=660,f2=660,gain=0.09,wave="square"},{start=0.07,duration=0.11,f1=880,f2=880,gain=0.09,wave="square"},{start=0.14,duration=0.11,f1=1100,f2=1100,gain=0.09,wave="square"}})
  sounds.hit=makeTone(0.22,{{start=0,duration=0.18,f1=220,f2=75,gain=0.28,wave="saw"},{start=0.06,duration=0.12,f1=110,f2=60,gain=0.15,wave="sine"}})
  sounds.collect=makeTone(0.34,{{start=0,duration=0.13,f1=880,f2=1047,gain=0.12,wave="square"},{start=0.08,duration=0.14,f1=1175,f2=1397,gain=0.11,wave="square"},{start=0.17,duration=0.15,f1=1568,f2=1760,gain=0.10,wave="sine"}})
  sounds.quack=loadQuack()
  sounds.defeat=makeTone(1.22,{
    {start=0.04,duration=0.17,f1=587,f2=587,gain=0.09,wave="square"},
    {start=0.16,duration=0.18,f1=523,f2=523,gain=0.09,wave="square"},
    {start=0.29,duration=0.19,f1=440,f2=440,gain=0.10,wave="square"},
    {start=0.43,duration=0.21,f1=349,f2=349,gain=0.10,wave="square"},
    {start=0.59,duration=0.24,f1=293,f2=293,gain=0.11,wave="square"},
    {start=0.76,duration=0.42,f1=220,f2=82,gain=0.14,wave="saw"},
    {start=0.78,duration=0.38,f1=196,f2=110,gain=0.13,wave="sine"}
  })
  music=makeSoundtrack()
  for _,layer in ipairs(music) do layer:play() end
  local capturePhase=os.getenv("PECKERTAP_CAPTURE_PHASE") or "menu"
  gs=newState(screenshotPending and capturePhase or "splash")
  local previewSky=tonumber(os.getenv("PECKERTAP_PREVIEW_SKY"))
  if previewSky then gs.skyPhase=math.max(1,math.min(#SKY_CYCLES,math.floor(previewSky))); gs.skyT=0 end
  local previewWeather=os.getenv("PECKERTAP_PREVIEW_WEATHER")
  if previewWeather and WEATHER_WIND[previewWeather] then gs.weatherOverride=previewWeather end
  local previewScore=tonumber(os.getenv("PECKERTAP_PREVIEW_SCORE"))
  if previewScore then gs.score=math.max(0,math.floor(previewScore)) end
  local previewFeathers=tonumber(os.getenv("PECKERTAP_PREVIEW_FEATHERS"))
  if previewFeathers then
    gs.totalFeathers=math.max(0,math.floor(previewFeathers))
  end
  local previewTotalFeathers=tonumber(os.getenv("PECKERTAP_PREVIEW_TOTAL_FEATHERS"))
  if previewTotalFeathers then gs.totalFeathers=math.max(0,math.floor(previewTotalFeathers)) end
  local previewLives=tonumber(os.getenv("PECKERTAP_PREVIEW_LIVES"))
  if previewLives then gs.lives=math.max(0,math.min(3,math.floor(previewLives))) end
  if os.getenv("PECKERTAP_PREVIEW_COLLECTIBLE")=="1" then
    gs.pipes[#gs.pipes+1]={x=gs.bird.x+138,topH=gs.bird.y-76,gap=152,passed=false,
      feather={y=gs.bird.y-45,phase=0,collected=false}}
  end
  if os.getenv("PECKERTAP_TEST_COLLECT")=="1" then
    gs.pipes[#gs.pipes+1]={x=gs.bird.x-PIPE_WIDTH/2,topH=gs.bird.y-70,gap=140,passed=false,
      feather={y=gs.bird.y,phase=0,collected=false}}
  end
  if os.getenv("PECKERTAP_TEST_DEATH")=="1" then triggerDeath() end
  print("event=startup renderer=love2d resolution=640x480 offline=true features=weather,collectibles,dynamic-music")
end

function love.update(dt)
  elapsed=elapsed+dt; accumulator=math.min(accumulator+dt,STEP*5)
  while accumulator>=STEP do fixedUpdate(); accumulator=accumulator-STEP end
  updateMusicMix(dt)
  if elapsed>=nextQuackAt then
    if gs.phase=="menu" or gs.phase=="ready" or gs.phase=="play" then play("quack"); print("event=quack") end
    nextQuackAt=elapsed+nextQuackDelay()
  end
  local sticks=love.joystick.getJoysticks()
  local selectDown,startDown=false,false
  for _,j in ipairs(sticks) do
    selectDown=selectDown or j:isGamepadDown("back")
    startDown=startDown or j:isGamepadDown("start")
    local ay=j:getGamepadAxis("lefty")
    if ay<-0.65 and not analogLatch then analogLatch=true; action() elseif ay>-0.35 then analogLatch=false end
  end
  if selectDown and startDown then shutdownHold=shutdownHold+dt else shutdownHold=0 end
  if shutdownHold>2.0 then
    shutdownHold=-999; print("event=shutdown_requested"); os.execute("/sbin/poweroff >/dev/null 2>&1 &")
  end
end

function love.draw()
  if gs.phase=="splash" then drawSplash() else
    drawPlayfield(); drawOuterBackground(); local scale=SCREEN_H/H; local playW=W*scale; local playX=(SCREEN_W-playW)/2
    love.graphics.setColor(1,1,1,1); love.graphics.draw(gameCanvas,playX,0,0,scale,scale)
  end
  if shutdownHold>0 then
    love.graphics.setColor(0,0,0,0.72); love.graphics.rectangle("fill",0,0,SCREEN_W,SCREEN_H)
    text("HOLD TO SHUT DOWN",SCREEN_W/2,220,13,C.white,"center",520)
    love.graphics.setColor(1,0.75,0.15,1); love.graphics.rectangle("fill",160,260,320*math.min(1,shutdownHold/2),12,6,6)
  end
  if screenshotPending then
    screenshotFrames=screenshotFrames+1
    if screenshotFrames==screenshotCaptureAt then
      love.graphics.captureScreenshot(screenshotPending)
      print("event=screenshot path="..screenshotPending)
      screenshotPending=nil
      quitAfterCapture=true
    end
  elseif quitAfterCapture then
    love.event.quit(0)
  end
end

function love.keypressed(key)
  if key=="space" or key=="up" or key=="w" or key=="return" or key=="z" or key=="x" then action()
  elseif key=="f12" then love.graphics.captureScreenshot("peckertap-r36s.png")
  elseif key=="escape" and os.getenv("PECKERTAP_WINDOWED")=="1" then love.event.quit(0) end
end

function love.gamepadpressed(_,button)
  if button~="back" then action() end
end

function love.joystickpressed(_,button)
  if button and button>=1 then action() end
end

function love.joystickhat(_,_,direction)
  if direction~="c" then action() end
end

function love.mousepressed() action() end
function love.touchpressed() action() end
