# The circularAllocator is a small structure for storing data, this frees us
#    from allocation and deallocation, it has some restictions:
#    - This is only useful with Plain Old Data (POD), that is, no constructors
#        and no destructors.
#    - We just expect that the next index returned is not being used anymore.
#    - Has a static size
#    - Not really thread safe only one thread can get memory from
#        it, however everyone can use the memory inside

import math

type
  CircAlloc* [Size: static[int] , T]  =  tuple # Better less overhead
    baseArray           : array[Size,T]
    index               : uint16

proc init*[Size: static[int], T](self: var CircAlloc[Size, T]) =
  self.index = 0

proc alloc*[Size: static[int], T](self: var CircAlloc[Size, T]): ptr T =
  inc self.index

  when isPowerOfTwo(Size ):
    let arrayPos : uint = (self.index - 1) and (Size - 1 )
  else:
    let arrayPos : uint = (self.index - 1) mod Size

  result = addr self.baseArray[ arrayPos ]

when isMainModule:
  import unittest

  suite "Circular Allocator":
   test "Allocation Test":
     var self: CircAlloc[512,int]
     self.init()
     assert self.alloc() != self.alloc()
