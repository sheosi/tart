import al
type Color* = TColor

proc rgb* (r,g,b: uint8): Color {.inline.} =
  al.mapRgb(r,g,b)

proc rgb* (r,g,b: float): Color {.inline.} =
  al.mapRgb_f(r,g,b)

proc rgba* (r,g,b,a: uint8): Color {.inline.} =
  al.mapRgba(r,g,b,a)

proc rgba* (r,g,b,a: float): Color {.inline.} =
  al.mapRgba_f(r,g,b,a)

let black* = mapRgb(0,0,0)
let white* = mapRgb(255,255,255)
let transparent* = mapRgba(255,255,255,0)
