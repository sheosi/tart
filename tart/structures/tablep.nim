import atomicwrapper

const ArrayDummySize* = when defined(cpu16): 10_000 else: 100_000_000

type
  TableP* [S: static[int],T] = object
    allJobsFinishedCallback : Atomic[pointer]
    data: array[S,Atomic[pointer]]
    elements: Atomic[uint16] #NOTE: This used to change depending on size, but current nim wont allow this
    #when S > 0 and S <= 255:
    #  elements: Atomic[uint8]
    #else :


proc `whenJobsFinished=`*[S,T](self: var TableP[S,T], newVal: T) {.inline.}=
  `value=`(self.allJobsFinishedCallback, cast[pointer](newVal))

proc whenJobsFinished*[S,T](self: var TableP[S,T]): T {.inline.}=
  cast[T](self.allJobsFinishedCallback.value)

iterator items*[S: static[int],T](self: var TableP[S,T]): T =
  if self.elements.value != 0:
    for i in 0 .. self.elements.value - 1:
      yield cast[T](self.data[i].value)

proc init*[S: static[int] ,T](self: var TableP[S, T]) =
  `value=`(self.elements, 0)
  #self.elements.value = 0

proc append*[S: static[int], T](self: var TableP[S, T], newData: T) =
  if self.elements.value == S:
    raise newException(OverflowError, "Can't fit inside the table'")

  `value=`(self.data[self.elements.value],cast[pointer](newData))
  inc self.elements


# TODO: finish the remove
proc remove*[S: static[int], T](self: var TableP[S, T], p: T) =
  var i = 0
  while i <= self.elements - 1:
    if self.data[i] == p:
      self.data[i] = self.data[self.elements - 1]
      dec self.elements
      inc i
      break

proc len*[S: static[int], T](self: var TableP[S,T]): uint16 =
  self.elements.value(MemOrder.Acquire)
