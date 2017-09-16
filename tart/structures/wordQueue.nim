import math
from tartutils import isPowerOfTwo

# A shared Queue thought to host word-sized data so that it can be replaced cas
# with a standard CAS.

import atomicwrapper

type
  WordQueue* [Size: static[int] , T]  =  tuple # Better less overhead
    baseArray           : array[Size,Atomic[T]]
    startIndex,endIndex : Atomic[uint16]

template getCircularIndex*(Max: static[int], value: uint16): uint16 =

  when isPowerOfTwo(Max ):
    (value - 1) and (Max - 1 )
  else:
    (value - 1) mod Max

proc init*[Size: static[int], T](self: var WordQueue[Size, T]) =
  self.startIndex.value = 0
  self.endIndex.value   = 0

proc len*[Size: static[int], T](self: var WordQueue[Size, T]): uint16 =
  self.endIndex.value - self.startIndex.value

# Unless in debug this makes no garantees about indexes
proc pop*[Size: static[int], T](self: var WordQueue[Size,T]): T =

  while result == nil:
    var startPos : uint16 = self.startIndex.value(MemOrder.Acquire)

    if self.endIndex.value(MemOrder.Acquire) - startPos <= 0:
      return nil

    # We got a good value?
    let index = getCircularIndex(Size,startPos+1)
    result = self.baseArray[index].exchange(nil,)

  inc self.startIndex , MemOrder.Release


proc push*[Size:static[int], T](self: var WordQueue[Size,T], value: T) =

  while true:
    var endPos = self.endIndex.value(MemOrder.Acquire)

    when defined(debug):
      if not endPos - self.startIndex.value(MemOrder.Acquire) < Size:
        raise newException(ValueError, "Queue is full")

    # If empty put
    let index = getCircularIndex(Size,endPos+1)
    if self.baseArray[index].compareExchange(nil, value, MemOrder.AcqRel): break

  inc self.endIndex , MemOrder.Release


when isMainModule:
  import unittest

  suite "Word Queue":
    setup:
      var self: WordQueue[511,ptr int]
      self.init()

    test "Pop nothing is nil":
      assert(self.pop() == nil)

    test "Basic push and pop":
      var a = 3
      self.push(addr a)
      assert(self.pop() == addr a)

    test "Len test":
      var a = 3
      self.push(addr a)
      assert(self.len == 1)
      discard self.pop()
      assert(self.len == 0)


