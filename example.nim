import x11 / [xlib, x]
import xevloop

# Create a window
var display = XOpenDisplay(nil)
if display == nil:
  quit "Failed to open display"

let screen = DefaultScreen(display);
let window = XCreateSimpleWindow(display, RootWindow(display, screen), 10, 10, 100, 100, 1,
                           BlackPixel(display, screen), WhitePixel(display, screen));

var finished = false
var wmDeleteWindow = XInternAtom(display, "WM_DELETE_WINDOW", false.TBool)

proc handleKeyPress(kev: TXKeyEvent) {.xevent: KeyPress.} =
  echo "Key pressed! Keycode: ", kev.keycode

proc handleKeyRelease(kev: TXKeyEvent) {.xevent: KeyRelease.} =
  echo "Key released! Keycode: ", kev.keycode
  if kev.keycode == 53:
    echo "Q key pressed"
    finished = true

proc handleClientMessage(cev: TXClientMessageEvent) {.xevent: ClientMessage.} =
  if cev.data.l[0].TAtom == wmDeleteWindow:
    echo "The Window Manager closed our window"
    finished = true

# Select the events we want and map the window
discard XSelectInput(display, window, KeyRelease or KeyPressMask or ButtonRelease);
discard XMapWindow(display, window);
discard XSetWMProtocols(display, window, wmDeleteWindow.addr, 1)

# Handle X events!
display.runXEventLoop:
  echo "After event"
  if finished:
    # We're done, quit the loop
    break xeventLoop
do:
  echo "Unknown event" # This is really a ButtonRelease event
  finished = true

discard XCloseDisplay(display)
