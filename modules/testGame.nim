import typography
import graphics2d
import render2d
import tartapi
import random
import rtArray
import al
from math import floor,ceil

const blocksH = 5
const blocksV = 5
const bulletWidth = 8

const bulletMinX = floor((16 - bulletWidth)/2)
const bulletMaxX = 16 - (ceil((16 - bulletWidth)/2))
var blocks:   array[blocksV * blocksH,Atomic[uint]]
var ship:     Atomic[uint]
var bullet:   Atomic[uint]
var endText:  Atomic[uint]
var canShoot: Atomic[bool]

var counter: Atomic[uint16]

# hard coded right now
const windowWidth = 640
const windowHeight = 480

proc removeBlock*(num: uint16) =
  let last = valDec counter
  let oldBlock = blocks[num].value
  blocks[num].value = blocks[last - 1].value

  # To erase old blocks just paint them  in black
  let emptyBlock = createBitmap(32,32)
  drawAt emptyBlock:
    drawFilledRectangle(0,0,32,32,mapRgb(0,0,0))

  oldBlock.exchangeBitmap(emptyBlock)

proc removeShoot*() =
  # To erase the shoot just paint them  in black
  let emptyShoot = createBitmap(16,16)
  drawAt emptyShoot:
    drawFilledRectangle(0,0,16,16,mapRgb(0,0,0))


  bullet.exchangeBitmap(emptyShoot)
  bullet.x = 0
  bullet.y = 0

proc randomBlock*(): PBitmap =
  result = createBitmap(32,32)

  # Let's make the color random, but with a pixelly color
  let r = uint8(random(1..6) * 51)
  let g = uint8(random(1..6) * 51)
  let b = uint8(random(1..6) * 51)

  drawAt result:
    drawFilledRectangle(0,0,31,31,mapRgb(r,g,b))


proc gameUpdate*(self: ptr Job){.onEvent: "tmp frame render".} =

  if not canShoot:

    # Update position
    bullet.y = bullet.y - 5

    let bX = bullet.x
    let bY = bullet.y

    # Instead of a for, let's write a while to force reload of variable,
    # it might change
    var i = 0'u16
    while i < counter:
      let x = blocks[i].x
      let y = blocks[i].y

      if ((bX + bulletMinX > x and bx + bulletMinX < x + 32) or
        (bX + bulletMaxX > x and bx +  bulletMaxX <  x + 32)
        ) and bY > y and bY < y + 32:
        removeBlock(i)
        removeShoot()

        canShoot.value = true

        if counter == 0:
          endText.value = graphics2d.createSprite(3)
          endText.drawText("YOU WON!")
          endText.x = 200
          endText.y = 200


      inc i

    if bY < 0:
      removeShoot()
      canshoot.value = true

  var keyboard: TKeyboardState
  keyboard.getKeyboardState()

  if keyboard.isKeyDown(KEY_LEFT):  ship.x = ship.x - 5
  if keyboard.isKeyDown(KEY_RIGHT): ship.x = ship.x + 5

  if keyboard.isKeyDown(KEY_SPACE) and canshoot:
    canshoot.value = false

    let newBulletBitmap = createBitmap(16,16)

    drawAt newBulletBitmap:
      drawFilledRectangle(0,0,15,15,mapRgb(0,0,0))
      drawFilledRectangle(bulletMinX,0,bulletMaxX,16,mapRgb(255,255,255))

    bullet.value.exchangeBitmap( newBulletBitmap )

    bullet.x = ship.x + 24
    bullet.y = ship.y + 24


proc shipGame*(self: ptr Job){.onEvent: "Game Start".} =

  randomize()

  canShoot.value = true

  counter.value = blocksH * blocksV

  ship.value = graphics2d.createSprite(2)

  bullet.value =  graphics2d.createSprite(3)

  removeShoot()

  let newShipBitmap = createBitmap(64,64)

  drawAt newShipBitmap:
    drawFilledRectangle(10,48,53,63, mapRgb(255,255,255)) # Body
    drawFilledRectangle(27,37,37,48, mapRgb(255,255,255)) # Canon

  ship.value.exchangeBitmap( newShipBitmap )

  ship.value.y = 400
  ship.value.x = 298

  # Calculate how much in the horizontalsides is empty
  let blocksSizeH = blocksH * 32
  let blocksSpaceH = (blocksH - 1) * 10
  let occupiedSpaceH = blocksSizeH + blocksSpaceH
  let sideEmptySpaceH = (windowWidth - occupiedSpaceH)/2

  # Same for vertical
  let blocksSizeV = blocksV * 32
  let blocksSpaceV = (blocksV - 1) * 10
  let occupiedSpaceV = blocksSizeV + blocksSpaceV
  let sideEmptySpaceV = (windowHeight - occupiedSpaceV)/2



  for v in 0..blocksV - 1:
    for h in 0..blocksH - 1:
      let newBlock = graphics2d.createSprite(2)
      newBlock.x = sideEmptySpaceH + float(h * (32 + 10))
      newBlock.y = sideEmptySpaceV + float(v * (32 + 10))
      newBlock.bitmap = randomBlock()


      (cast [var Atomic[uint]](addr blocks[v*blocksH + h] )).value = newBlock
