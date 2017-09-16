 import tartutils

# Circular Array is meant to be used only with manual memory
# This way is GC-safe

type CircularArray* [T] =  object
    baseArray          : ptr DynArray[T]
    size               : int

proc newCircularArray*[T]( size:  Natural ): CircularArray[T] =
  result = CircularArray[T](baseArray: allocSharedDynArray[T](size), size: size)

proc newCircularArray*[T]( self: var CircularArray[T], size:  Natural ) {.inline.}=
  self = newCircularArray[T](size)

proc expand*[T](self: var CircularArray[T]) =
  self.size *= 2
  let newArrayPointer = allocShared(self.size * sizeof(T) )
  let newDynArrayPtr  = cast[ptr DynArray[T]]( newArrayPointer )
  let oldDynArray = self.baseArray

  #Let's copy the array
  for i in 0.. self.size - 1:
    newDynArrayPtr[i] = oldDynArray[i]

  self.baseArray = newDynArrayPtr

  deallocShared(oldDynArray)


proc `[]`*[T] (self: CircularArray[T], index: Natural): T =
  result = self.baseArray[index mod self.size ]

proc `[]=`*[T] (self: var CircularArray[T],index: Natural ,obj: T) =
  self.baseArray[index mod self.size]  = obj

proc size*[T] (self: var CircularArray[T]): int =
  result = self.size

proc destroy*[T] (self: var CircularArray[T]) =
  deallocShared( self.baseArray )


#Tests
when isMainModule:
  import unittest

  suite "Circular Array Tests":
    setup:
      var testArray: CircularArray[int] = newCircularArray[int](5)

    teardown:
      destroy(testArray)

    test "Store and Load":
      testArray[0] = 0
      testArray[1] = 1
      testArray[2] = 2
      testArray[3] = 3
      testArray[4] = 4

      check( testArray[0] == 0 )
      check( testArray[1] == 1 )
      check( testArray[2] == 2 )
      check( testArray[3] == 3 )
      check( testArray[4] == 4 )


    test "Overflow test":

      testArray[0] = 0
      testArray[1] = 1
      testArray[2] = 2
      testArray[3] = 3
      testArray[4] = 4
      testArray[5] = 5 #This overwrites position 0



      check( testArray[0] != 0 ) #Should be 5
      check( testArray[0] == 5 )
      check( testArray[1] == 1 )
      check( testArray[2] == 2 )
      check( testArray[3] == 3 )
      check( testArray[4] == 4 )
      check( testArray[5] == 5 )

    test "Expand":

      testArray[0] = 0
      testArray[1] = 1
      testArray[2] = 2
      testArray[3] = 3
      testArray[4] = 4

      testArray.expand()

      testArray[5] = 5
      testArray[6] = 6
      testArray[7] = 7
      testArray[8] = 8
      testArray[9] = 9


      check( testArray[0] == 0 )
      check( testArray[1] == 1 )
      check( testArray[2] == 2 )
      check( testArray[3] == 3 )
      check( testArray[4] == 4 )

      check( testArray[5] == 5 )
      check( testArray[6] == 6 )
      check( testArray[7] == 7 )
      check( testArray[8] == 8 )
      check( testArray[9] == 9 )


    test "Overflow and expand":

      testArray[0] = 0
      testArray[1] = 1
      testArray[2] = 2
      testArray[3] = 3
      testArray[4] = 4

      testArray.expand()

      testArray[5] = 5
      testArray[6] = 6
      testArray[7] = 7
      testArray[8] = 8
      testArray[9] = 9

      testArray[19] = 19 # This should overwrite position 9

      #echo (testArray.baseSeq.high()+1)
      check( testArray[0] == 0 )
      check( testArray[1] == 1 )
      check( testArray[2] == 2 )
      check( testArray[3] == 3 )
      check( testArray[4] == 4 )

      check( testArray[5] == 5 )
      check( testArray[6] == 6 )
      check( testArray[7] == 7 )
      check( testArray[8] == 8 )
      check( testArray[9] == 19 )
