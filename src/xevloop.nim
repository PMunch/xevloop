import macros
import x11 / xlib
import tables

type defTuple = tuple[handler: NimNode, kind: NimNode]
var xeventhandlers {.compileTime.} = initTable[int, seq[defTuple]]()

macro xevent*(events: typed, handler: typed): typed =
  ## Pragma that can be attached to procedures that act as event handlers. The
  ## handlers don't return anything, and only take a single argument which is
  ## what the event structure should be cast to. This pragma takes either a
  ## single X11 event, or an array of such events as its argument; these are
  ## the events it will attach to.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##   proc handleKeyPress(kev: TXKeyEvent) {.xevent: KeyPress.} =
  ##     echo "Got key press"
  ##   proc handleKeyRelease(kev: TXKeyEvent) {.xevent: KeyRelease.} =
  ##     echo "Got key release"
  result = newStmtList()
  assert(handler.kind == nnkProcDef, "The handler must be a procedure, use " &
                                     "this as a pragma")
  assert(handler[3][0].kind == nnkEmpty, "Handlers can't return anything")
  assert(handler[3].len == 2 or handler[3].len == 1, "Handlers only take a single argument")
  var def: defTuple
  def.handler = handler[0]
  if handler[3].len == 2:
    def.kind = handler[3][1][1]
  else:
    def.kind = newNilLit()

  proc addOrExtend(key: cint, def: defTuple) =
    if not xeventhandlers.hasKey(key):
      xeventHandlers[key] = @[]
    xeventhandlers[key].add def

  if events.kind == nnkIntLit:
    addOrExtend(events.intVal.cint, def)
  elif events.kind == nnkBracket:
    for event in events:
      assert(event.kind == nnkIntLit, "Events must be integer values")
      addOrExtend(event.intVal.cint, def)
  else:
    assert(events.kind == nnkIntLit or events.kind == nnkBracket, "Event must either be a single integer value, or a list")

macro createXEventHandler*(default: untyped): untyped =
  ## Creates a procedure that takes an X11 event as argument and calls the
  ## defined handler for that event. This can be used to extend an existing X
  ## event loop, or to not lock up the main thread of the application.
  ## Example:
  ##
  ## .. code-block:: nim
  ##   let handleXEvent = createXEventHandler()
  ##   if display.XPending() != 0:
  ##     var ev: TXEvent
  ##     discard display.XNextEvent(ev.addr)
  ##     handleXEvent(ev.addr)
  let ev = newIdentNode("evPtr")
  var body = quote do:
    case `ev`.theType:
    else:
      var ev = `ev`[]
      `default`

  for event, defs in xeventhandlers.pairs:
    var ofBody = newStmtList()
    for def in defs:
      let
        kind = def.kind
        handler = def.handler
      if kind.kind != nnkNilLit:
        ofBody.add quote do:
          let castev = cast[ptr `kind`](`ev`)[]
          `handler`(castev)
      else:
        ofBody.add quote do:
          `handler`()
    body.add nnkOfBranch.newTree(newLit(event), ofBody)
  result = newProc(
    params = [newIdentNode("auto"), nnkIdentDefs.newTree(ev, newIdentNode("PXEvent"), newEmptyNode())],
    body = body, procType = nnkLambda)

macro runXEventLoop*(display: PDisplay, after: untyped, default: untyped): untyped =
  ## Runs the X11 event loop and handles all events that have been masked for
  ## this program. The `default` parameter can be used to pass a block of code
  ## that will be executed if the event is not one that is handled by the
  ## registered handlers.
  ## Example:
  ##
  ## .. code-block:: nim
  ##   display.runXEventLoop()
  var xeventLoop = newIdentNode("xeventLoop")
  var ev = newIdentNode("event")
  result = quote do:
    block `xeventLoop`:
      let handleXEvent = createXEventHandler:
        `default`
      while true:
        var `ev`: TXEvent
        discard XNextEvent(`display`, `ev`.addr)
        handleXEvent(`ev`.addr)
        `after`

template runXEventLoop*(display: PDisplay): untyped =
  runXEventLoop(display):
    discard
  do:
    discard

template runXEventLoop*(display: PDisplay, after: untyped): untyped =
  runXEventLoop(display, after):
    discard

template createXEventHandler*(): untyped =
  createXEventHandler:
    discard
