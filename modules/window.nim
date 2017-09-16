import atomicwrapper
import basetypes
import al
import tartapi
from scheduler import schedRunning

var queue: PEventQueue
var display*: Atomic[PDisplay]

type Key* {.pure.} = enum
  Spacebar   = KEY_Space
  ArrowLeft  = KEY_LEFT,
  ArrowRight = KEY_Right,
  ArrowUp    = KEY_Up,
  ArrowDown  = KEY_DOWN,



proc initAllegro(self: ptr Job){.onEvent: "Game Init".} =

  if not al.init():
    quit "Failed to initialize allegro!"

  echo "Initing!"
  display.value = al.createDisplay(640, 480)

  if display.value.isNil:
    quit "Failed to create display!"

  discard al.installEverything()
  discard al.initBaseAddons()

  queue = createEventQueue()

  if queue.isNil:
    quit "Failed to create event queue"

  queue.registerEventSource display.value.eventSource
  queue.registerEventSource getMouseEventSource()
  queue.register getKeyboardEventSource()



  al.clearToColor mapRgb(255,255,255)
  al.flipDisplay()

proc emptyQueue(self: ptr Job){.onEvent: "tmp frame render".} =
  var event: TEvent
  while queue.getNextEvent(event):
      if(event.kind == EVENT_DISPLAY_CLOSE):
         schedRunning = false


proc terminateDisplay(self: ptr Job){.onEvent: "Game End".} =
  queue.destroy
  display.value.destroy

  queue = createEventQueue()

