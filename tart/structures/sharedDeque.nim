import atomicwrapper
import math

type SharedDeque*[Size:static[int], T] = tuple
  top,bottom: Atomic[uint16]
  baseArray: array[Size,T]


template sharedDequeDecl*(name: expr, Size: int ,T: typedesc) =
  alignedVar(name,SharedDeque[Size,T],2)

template accessIndex*[T](size: int ,num: T): T =
  when size.isPowerOfTwo():
    num and (size - 1 )
  else:
    num mod size

#The value which serves us as 0
template universalNil*(T: typedesc): expr =
  when T is ptr any or T is pointer:
    nil
  else: 0

proc init* [Size:static[int] , T](self: var SharedDeque[Size,T])=
  self.top.value = 0
  self.bottom.value = 0

proc push* [Size:static[int] ,T](self: var SharedDeque[Size,T], obj: T) =
    let b = self.bottom.value
    let accIndex = accessIndex(Size,b).uint16
    self.baseArray[ accIndex ] = obj


    threadFence(MemOrder.Acquire)
    inc self.bottom

proc pop*[Size:static[int], T](self: var SharedDeque[Size,T]): T =
    let b = self.bottom.value - 1
    self.bottom.value = b

    threadFence(MemOrder.AcqRel)
    let t = self.top.value

    if t <= b:
        # non-empty queue
        let accIndex = accessIndex[T](Size,b).uint16
        result = self.baseArray[ accIndex  ]
        if t != b:
          # there's still more than one item left in the queue
          return

        # this is the last item in the queue
        if not self.top.compareExchange(t,t+1):
            # failed race against steal operation
            echo "Failed to race against steal"
            result = universalNil(T)# Here 0 means nil

        self.bottom.value = t+1

    else:
        # deque was already empty
        self.bottom.value = t
        result =  universalNil(T)

proc steal*[Size: static[int],T] (self: var SharedDeque[Size, T]): T =
    var t = self.top.value(MemOrder.Acquire)
    var b = self.bottom.value
    if t < b:
        # non-empty queue
        result = self.baseArray[ accessIndex[T](Size,t).uint16]

        if not self.top.compareExchange(t+1,t,  MemOrder.Relaxed):
            # a concurrent steal or pop operation removed an element from the 
            # deque in the meantime.

            result = universalNil(T)

    else:
        # empty queue
        result = universalNil(T)

#Unit tests
when isMainModule:
  import unittest
  suite "Shared Deque Tests":
    test "Push and Pop":
      var testDeque: SharedDeque[500,int]
      testDeque.push(5)
      check( testDeque.pop() == 5 )

    test "IsLockFree":
      sharedDequeDecl(testDeque, 500, int)
      #var topLockFree: bool =
      check  atomicIsLockFree(sizeof(testDeque.top),  cast[ptr uint16]( addr testDeque.top) )
      check  atomicIsLockFree(sizeof(testDeque.bottom),  cast[ptr uint16]( addr testDeque.bottom) )

    #test
