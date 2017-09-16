import atomicwrapper
import hash32
import rtArray
import maybe
from tartutils import isPowerOfTwo
when defined(debug):
  import math


type
  SizeError = object of Exception
  InvalidOpError = object of Exception
  Entry[V] = tuple[key: Atomic[uint32],evalue: V ]
  SharedTable*[K,V] = object
    data: ptr Dynarray[Entry[V]]
    size: uint32

  EntryAtomic[V] = tuple[key: Atomic[uint32],evalue: Atomic[V] ]
  SharedTableAtomic*[K,V] = object
    data: ptr Dynarray[EntryAtomic[V]]
    size: uint32

proc allocSharedDynArray0*[T](size: Natural): ptr DynArray[T] {.inline.} =
  let arrayPointer = allocShared0(size * sizeof(T) )
  result = cast[ptr DynArray[T]]( arrayPointer )

# Not thread-safe
proc init*[K,V](self: var SharedTable[K,V], size:uint32 = 32 ) =
  when defined(debug):
    if not size.isPowerOfTwo:
      raise newException(SizeError, "Size must be power of two")

    if self.size != 0 and self.data != nil:
      raise newException(InvalidOpError, "Already initialized")

  self.size = size
  self.data = allocSharedDynArray0[Entry[V]](size)

proc init*[K,V](self: var SharedTableAtomic[K,V], size:uint32 = 32 ) =
  when defined(debug):
    if not size.isPowerOfTwo:
      raise newException(SizeError, "Size must be power of two")

    if self.size != 0 and self.data != nil:
      raise newException(InvalidOpError, "Already initialized")

  self.size = size
  self.data = allocSharedDynArray0[EntryAtomic[V]](size)

# Not thread-safe
proc destroy*[Table: SharedTable | SharedTableAtomic](self: var Table) =
  self.data.deallocShared()
  self.size = 0

proc inf*(T:typedesc) : T =
  result = high(T)

proc initialized*[TableType: SharedTable | SharedTableAtomic](self: TableType): bool =
  self.data != nil

proc `[]=`*[K,V](self: var SharedTable[K,V], key: K, newValue: V) =

  for idxOrig in hash(key)..inf(uint32):

    var idx = idxOrig and (self.size - 1)

    # Load the key that was there
    let probedKey = self.data[idx].key.value
    if probedKey != key:

      # The entry is either free, or contains another key
      if probedKey != 0:
        continue


      let prevKey =  self.data[idx].key.compareExchangeStrongVal( 0, key)

      if prevKey != 0 and prevKey != key:
        self.data[idx].evalue.value = newValue
        return

    self.data[idx].evalue.value =  newValue
    return

proc `[]=`*[K,V](self: var SharedTableAtomic[K,V], key: K, newValue: V) =
  when defined(debug):
    if self.data == nil:
      raise newException(ValueError, "Table not initialized")

  let hashKey = hash(key)

  for idxOrig in hashKey..inf(uint32):

    var idx = idxOrig and (self.size - 1)

    # Load the key that was there
    let probedKey = self.data[idx].key.value
    if probedKey != key:

      # The entry is either free, or contains another key
      if probedKey != 0:
        continue


      let prevKey = self.data[idx].key.compareExchangeStrongVal( 0'u32, hashKey.uint32)

      if prevKey != 0 and prevKey != key:
        continue


    self.data[idx].evalue.value =  newValue
    return

proc `[]`*[K,V](self: SharedTable[K,V], key: K): Maybe[ptr V] =
  when defined(debug):
    if not self.initialized:
      raise newException(ValueError, "Table not initialized")

  let hashKey = hash(key).uint32 # Hashkey can't process uints directly, let's treat it
                                 # as a pointer

  for idxOrig in hashKey..inf(uint32):
    var idx = idxOrig and ( self.size - 1)

    let probedKey = self.data[idx].key.value
    if probedKey == hashKey:
      return box(addr self.data[idx].evalue)

    if probedKey == 0:
      return Maybe[ptr V](valid: false)


proc `[]`*[K,V](self: SharedTableAtomic[K,V], key: K): Maybe[V] =
  when defined(debug):
    if not self.initialized:
      raise newException(ValueError, "Table not initialized")

  let hashKey = hash(key).uint32

  echo "[" & $key & "]" & ":" & $hashKey

  for idxOrig in hashKey..inf(uint32):
    var idx = idxOrig and ( self.size - 1)

    let probedKey = self.data[idx].key.value
    if probedKey == hashKey:
      return box(self.data[idx].evalue.value)

    if probedKey == 0:
      return Maybe[V](valid: false)

proc add*[K,V](self: SharedTable[K,V], key: K) =
  let hashKey = hash(key).uint32

  for idxOrig in hashKey..inf(uint32):

    var idx = idxOrig and (self.size - 1)

    # Load the key that was there
    let probedKey = self.data[idx].key.value
    if probedKey == hashKey:
      return

    if probedKey == 0:

      if self.data[idx].key.compareExchangeStrong( 0, hashKey):
        echo $key : " Final index(add): " & $idx
        return

when isMainModule:
  import unittest
  const testDictSize = 32

  var testDict: SharedTable[int,int]
  var errorFlag = false
  testDict.init(testDictSize)

  suite "Hash Table":
    setup:
      testDict.destroy()
      testDict.init(testDictSize)

    test "Basic test":
      testDict[1] = 32
      testDict[2] = 64
      check(testDict[1] == 32 and testDict[2] == 64)

