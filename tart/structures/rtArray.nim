#rtArray is an array whose size is decided at runtime

const ArrayDummySize* = when defined(cpu16): 10_000 else: 100_000_000
type
  DynArray* {.unchecked.}[T] = array[0..ArrayDummySize, T]
  RtArray*[T] = ptr Dynarray[T]

proc allocSharedDynArray*[T](size: Natural): ptr DynArray[T] =
  let arrayPointer = allocShared(size * sizeof(T) )
  result = cast[ptr DynArray[T]]( arrayPointer )

proc newRtArray*[T]( size: Natural): RtArray[T] {.inline.} =
  result = allocSharedDynArray[T](size)

proc initialized*(self: RtArray): bool =
  self != nil

proc destroy*(self: RtArray) =
  self.deallocShared()

iterator mitems*[T](self: var RtArray[T],maxIndex: Natural): var T {.inline.} =
  for i in 0..maxIndex:
    yield self[i]

proc size*[T]( self: RtArray[T]): Natural {.inline.} =
  sizeof(self) div sizeof(T) # Integer diviision
