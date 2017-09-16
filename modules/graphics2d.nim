from window import display
import al
import tartapi
import render2d
import rtArray
import sharedtable
import locks
import maybe
import job
import atomicwrapper
import basetypes
export basetypes

# Those two are needed for the drawLock template
export locks
export atomicwrapper

# TODO: Return an unique identifier

# Our bitmap is actually an identifier, and we intend it to be unique.
# In 32 bits machines this is how it looks.

const maskIndex        = 0b0000_1111_1111_1111_1111_1111_1111_1111'u32
const extractLayerMask = 0b1111_0000_0000_0000_0000_0000_0000_0000'u32

# LLLL RRRR RRRR RRRR RRRR RRRR RRRR RRRR
# The L means the number of layer, while the R represent a number which is always
# incrementing and acts as a unique identifier to a bitmap. This ammount of R
# means that we have 268435456 pictures before having to reset, giving plenty of
# time to either not use them or let the application "forget" about them.

const layersSize = [10,10,40,10,10]

# We are using here just one lock because experimentation on a x86-64 machine
# demonstrated that for fast accesses (which is mostly what we will be doing
# here) using just one lock against a lock per entry was 40% faster.

var arraysLock: Lock
var layersBitmap {.guard: arraysLock.}: RtArray[RtArray[PBitmap]]
var layersX {.guard: arraysLock.}: RtArray[RtArray[float]]
var layersY {.guard: arraysLock.}: RtArray[RtArray[float]]
var layersNumElements: RtArray[Atomic[uint16]]

# Should be better with distinct, but for now it's too uncofortable
#type Sprite* = distinct uint
type Sprite* = uint

# Allegro only supports to write to one bitmap, so let's have a lock for it
var drawLock*: Lock


var nextIndex: RtArray[uint]

var bitmapTable: SharedTableAtomic[uint32,uint]

proc `bitmap=`* (self: Sprite, value: PBitmap) {.thread.}

proc createSprite*(layer: uint8): Sprite {.thread.} =
  when defined(debug):
    if layer > layersSize.len.uint8:
      raise newException(ValueError, "Unvalid layer '" & $layer & "'" )

  # Make as bitmap
  let actualIndex = nextIndex[layer]
  let baseIndex = actualIndex and maskIndex
  inc nextIndex[layer]


  # Join layer number and index
  result = cast[Sprite]( (layer.uint() shl 28) or baseIndex )

  # Add to dictionary
  bitmapTable[result.uint32] = actualIndex

  # Add empty bitmap
  result.bitmap = createBitmap(32,32)

  # Update indexes
  inc layersNumElements[layer]

  echo "Saving sprite " & $result.uint32 & ", exists? " & $ ?bitmapTable[result.uint32]

proc extractLayer(num: uint32): uint32 {.inline.} =
  (extractLayerMask and num) shr 28

proc x*(self: Sprite): float =
  let index = self.uint32
  let layer = extractLayer(index)


  {.locks:[arraysLock].}:
    let arrayIndex = bitmapTable[index].unbox
    result = layersX[layer][arrayIndex]

proc y*(self: Sprite): float =
  let index = self.uint32
  let layer = extractLayer(index)

  {.locks:[arraysLock].}:
    let arrayIndex = bitmapTable[index].unbox
    result = layersY[layer][arrayIndex]

proc bitmap* (self: Sprite): PBitmap =
  let index = self.uint32
  let layer = extractLayer(index)

  {.locks:[arraysLock].}:
    let arrayIndex = bitmapTable[index].unbox
    result = layersBitmap[layer][arrayIndex]

proc `x=`*(self: Sprite, val: float) =
  let index = self.uint32
  let layer = extractLayer(index)

  {.locks:[arraysLock].}:
    let arrayIndex = bitmapTable[index].unbox
    layersX[layer][arrayIndex] = val

proc `y=`*(self: Sprite, val: float) =
  let index = self.uint32
  let layer = extractLayer(index)

  {.locks:[arraysLock].}:
    let arrayIndex = bitmapTable[index].unbox
    layersY[layer][arrayIndex] = val

proc `bitmap=`* (self: Sprite, value: PBitmap) =

  let index = self.uint32

  when defined(debug):
    if index == 0:
      raise newException(ValueError, "Assigning to uninitialized sprite")

    if value == nil:
      raise newException(ValueError, "New bitmap is invalid (pointer to nil)")

  let layer = extractLayer(index)
  let arrayIndex = bitmapTable[index].unbox

  {.locks:[arraysLock].}:
    layersBitmap[layer][arrayIndex] = value

proc exchangeBitmap*(self: Sprite, newBitmap: PBitmap) =
  let oldBitmap = self.bitmap
  self.bitmap = newBitmap
  oldBitmap.destroy()



# Set the number of initial layers and the number of initial images per layer
proc initRender2D (self: ptr Job) {.onEvent: "Main Init".} =
  withLock arraysLock:
    layersBitmap = newRtArray[RtArray[PBitmap]](layersSize.len)
    layersX = newRtArray[RtArray[float]](layersSize.len)
    layersY = newRtArray[RtArray[float]](layersSize.len)
    layersNumElements = newRtArray[Atomic[uint16]](layersSize.len)
    for i in  0..layersSize.len-1:
      echo "Initializing layerNum" & $i
      layersBitmap[i] = newRtArray[PBitmap](layersSize[i])
      layersX[i] = newRtArray[float](layersSize[i])
      layersY[i] = newRtArray[float](layersSize[i])


  nextIndex = newRtArray[uint](layersSize.len)
  bitmapTable.init(64)

initRender2D(nil)

proc draw (self: ptr Job) {.onEvent: "tmp frame render".}=
  # Draw
  echo "Drawing now"

  when defined(debug):
      if isNil display.value:
        raise newException(ValueError, "Display is nil")

      if not layersNumElements.initialized:
        raise newException(ValueError, "Array of number of elements is uninitialized")

  withLock drawLock:

    let old = getTargetBitmap()
    setTargetBitmap(display.value.getBackbuffer)
    clearToColor white

    for nLayer in 0..layersNumElements.size:
      echo "Accessing layer " & $nLayer

      if layersNumElements[nLayer].value == 0:
        continue # Empty continue

      echo $nLayer & ":" & $layersNumElements[nLayer].value
      #for nImg in items(0'u16..layersNumElements[nLayer]):
      for nImg in 0'u16..layersNumElements[nLayer].value - 1:
        {.locks:[arraysLock].}:
          let bmp = layersBitmap[nLayer][nImg]
          let x = layersX[nLayer][nImg]
          let y = layersY[nLayer][nImg]

          when defined(debug):
            if bmp == nil:
              raise newException(ValueError, "Bitmap is nil for layer: " & $nLayer & " num: " & $nImg)
          drawBitmap(bmp , x, y, 0)

    flipDisplay()
    setTargetBitmap(old)


template drawAt*(toDrawOn:PBitmap,code: untyped) =
  withLock drawLock:
    let old = getTargetBitmap()
    setTargetBitmap(toDrawOn)
    code
    setTargetBitmap(old)

proc terminate (self: ptr Job) {.onEvent: "Game End".}=
  for i in  0..layersSize.len:
    {.locks:[arraysLock].}:
      layersBitmap[i].destroy()

  {.locks:[arraysLock].}:
    layersBitmap.destroy()
