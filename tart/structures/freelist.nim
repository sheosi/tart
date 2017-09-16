import atomicwrapper
import rtArray

import strutils

const
  ArrayDummySize* = when defined(cpu16): 10_000 else: 100_000_000
  #RefsMask = 0x7FFFFFFF # For 32 bits
  RefsMask = 0x7FFF # For 16 bits
  #ShouldBeOnFreeList = 0x80000000 # For 32 bits
  ShouldBeOnFreeList = 0x8000# For 16 bits


type
  #Node*[T] = tuple [data:T, refs:Atomic[uint16], next:Atomic[ptr Node[T]]]
  Node*[T] = tuple [data:T, refs:Atomic[uint16], next:Atomic[pointer]]
  # Unfortenately, this makes the Nim compiler crash
  FreeList*[T] = tuple [head:Atomic[pointer], memPtr: Atomic[pointer]]


proc `[]`[T](a: ptr T, b: uint): ptr T =
  cast[ptr T](cast[uint](a) +   b * uint(sizeof(T)) )

proc init*[T](self: var Node[T], next: ptr Node[T] = nil) =
  self.refs.value =  1
  self.next.value = next

# Not thread-safe
proc init*[T](self: var FreeList[T], size: uint8) =
  self.memPtr.value = alloc(sizeof(Node[T])*int(size))
  var mem = cast[ptr Node[T]](self.memPtr.value)
  self.head.value= cast[pointer](mem)

  for i in 0..size:
    var next =
      if i <= (size - 1) : mem[i+1]
      else: nil

    mem[i][].init(next) # Initialize node

proc destroy*[T](self: var FreeList[T]) =
  dealloc(self.memPtr.value)

  # Since the refcount is zero, and nobody can increase it once it's zero
  # (except us, and we run only one copy of this method at a time, e.g. the
  # single thread case), then we know we can safely change the next pointer of
  # the node; however, once the refcount is back above zero, then other threads
  # could increase it (happens under heavy contention, when the refcount goes
  # to zero in between a load and a refcount increment of a node in try_get,
  # back up to something non-zero, then the refcount increment of a node in
  # try_get, then back up to something non-zero, then the refcount increment is
  # done by the other thread) -- so, if the CAS to add the node to the actual
  # list fails, decrease the refcount and leave the add operation to the next
  # thread who puts the refcount back at zero (which could be us, hence the
  # loop).

proc addKnowingRefcountIsZero[T](self: var FreeList[T], node: ptr Node[T]) {.inline.} =

  var head = self.head.value(MemOrder.Relaxed)
  while true:
    node.next.value = (head, MemOrder.Relaxed)
    node.refs.value = (1, MemOrder.Relaxed)
    if not self.head.compareExchangeStrong(head, node, MemOrder.Relaxed,
     MemOrder.Relaxed):

      # Hmmm, the add failed but we can only try again when the
      # refcount goes back to 1
      if valInc(node.refs ,ShouldBeOnFreeList - 1 , MemOrder.Relaxed ) == 1:
        continue

    return

proc add*[T](self: var FreeList[T], data: ptr T) {.inline.} =
  # As long as there's no error by part of the programmer, we can assume a ptr to
  # T is the same as a ptr to the Node, becasue is the start of it.
  let node = cast [ptr Node[T]](data)
  # We know that the should-be-on-freelist bit is 0 at this point, so it's safe
  # to set it using a fetch_add


  if valInc( node.refs ,ShouldBeOnFreeList , MemOrder.Release ) == 0:
    # We were the last ones referencing this node, and we know we want to add it
    # to the free list, so let's do it!
    self.addKnowingRefcountIsZero(node)

  echo node.refs.value.int.toHex()

proc tryGet*[T](self: var FreeList[T]): ptr T {.inline.} =
  var head : ptr Node[T] = cast[ptr Node[T]](self.head.value(MemOrder.Acquire))

  when defined(debug):
    if head == nil:
      raise newException(ValueError, "Ran out of items to get")

  while head != nil:
    var prevHead = head
    var refs = head.refs.value(MemOrder.Relaxed)
    if (refs and REFS_MASK) == 0 or not head.refs.compareExchangeStrong(refs,refs+1, MemOrder.Acquire, MemOrder.Relaxed):
      head = cast[ptr Node[T]](self.head.value(MemOrder.Acquire))
      continue

    # Good, reference count has been incremented (it wasn't at zero), which means
    # ShouldBeOnFreeList must be false not matter the refcount (because
    # nobody ekse knowd it's been taken off yet, it can't have put back on).
    var next : ptr Node[T] = cast[ptr Node[T]](head.next.value(MemOrder.Relaxed))
    if self.head.compareExchangeStrong(head, next, MemOrder.Acquire, MemOrder.Relaxed):

      # Yay, got the node. This means it was on the list, which means
      # shouldBeOnFreeList must be false no matter the refcount (because
      # nobody else knows it's been taken off yet, it can't have been put back
      # on).
      assert((head.refs.value(MemOrder.Relaxed) and ShouldBeOnFreeList) == 0 )

      # Decrease refcount twice, once for our ref, and once the list's ref
      dec(cast[var Atomic[uint16]](addr head.refs),2, MemOrder.Relaxed)

      return addr head.data

    # OK, the head must have changed on us, but we still need to decrease the
    # refcount we increased
    refs = valDec(prevHead.refs , 1,  MemOrder.AcqRel )
    if cast[int](refs) == ShouldBeOnFreeList + 1:
      self.addKnowingRefcountIsZero(prevHead)

  return nil

proc headUnsafe*[T](self: FreeList[T]): ptr Node =
  self.head.load[T](MemOrder.Relaxed)

when isMainModule:
  import unittest

  suite "FreeList":
    setup:
      var freeList : FreeList[int]
      freeList.init(1)

    teardown:
      freeList.destroy()

    test "Take":
      assert(freeList.tryGet() != nil)

    test "Take and Add":
      let mem = freeList.tryGet()
      assert(mem != nil)
      freeList.add(mem)

    test "Return works":
      let mem = freeList.tryGet()
      assert(mem != nil)
      freeList.add(mem)

      let mem2 = freeList.tryGet()
      assert(mem2 != nil)
      freeList.add(mem2)
