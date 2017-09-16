import al
import graphics2d
import tartapi
import atomicwrapper
import locks


type FontAlign* {.pure.}= enum
  Left = FontAlignLeft, Center = FontAlignCenter , Right = FontAlignRight,
  LeftPixel   = FontAlignLeft   or FontAlignInteger
  CenterPixel = FontAlignCenter or FontAlignInteger
  RightPixel  = FontAlignRight  or FontAlignInteger

var font: Atomic[PFont]

var counter : Atomic[int]

const textFont = "/usr/share/fonts/truetype/droid/DroidSans.ttf"
proc typographyInit(self: ptr Job) {.onEvent:"allegro init".} =
  font.value = al.loadFont(textFont, 46, 0)

  if font.value == nil:
      raise newException(Exception,"Failed to load font")

proc drawText*(sprite: Sprite, str: string, color: Color = mapRgb(255,255,255), fontAlign = FontAlignLeft ) =
  let currentFont = font.value
  let bmpWidth  = currentFont.getTextWidth(str)
  let bmpHeight = currentFont.getFontLineHeight()
  let fontBitmap = createBitmap( bmpWidth , bmpHeight)

  withLock drawLock:

    let oldDisplay = getTargetBitmap()
    fontBitmap.setTargetBitmap()
    drawFilledRectangle(0,0,cfloat(bmpWidth),cfloat(bmpHeight),mapRgb(0,0,0))
    font.drawText(color, 0,0, fontAlign, str)

    oldDisplay.setTargetBitmap()
    sprite.bitmap = fontBitmap


