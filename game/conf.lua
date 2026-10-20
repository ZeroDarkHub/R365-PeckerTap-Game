function love.conf(t)
  t.identity = "peckertap"
  t.version = "11.5"
  t.console = true

  t.window.title = "Pecker Tap"
  t.window.width = 640
  t.window.height = 480
  t.window.fullscreen = os.getenv("PECKERTAP_WINDOWED") ~= "1"
  t.window.fullscreentype = "exclusive"
  t.window.vsync = 1
  t.window.resizable = false
  t.window.borderless = true
  t.window.highdpi = false
  t.window.usedpiscale = false
  t.window.msaa = 0

  t.modules.physics = false
  t.modules.video = false
end
