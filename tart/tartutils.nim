#Mixed utils
type Backend* {.pure.} = enum
  C, CPP, OBJC, JS, PHP


const backend* = when defined(cpp): Backend.CPP
                elif defined(objc): Backend.OBJC
                elif defined(nimphp): Backend.PHP
                elif defined(js): Backend.JS
                else: Backend.C

#hostCPU: a string that describes the host CPU. Possible values: "i386", "alpha", "powerpc", "powerpc64", "powerpc64el", "sparc", "amd64", "mips", "mipsel", "arm", "arm64".


proc `==`*[T](a: T, b:openarray[T]): bool=
  result = false
  for elm in b:
    if elm == a:
      result = true
      break


template notNil*(self): bool =
  self != nil


#Try to detect architecture's bits
const hostCPUBits* = when defined(cpu64): 64
                     elif defined(cpu32): 32
                     elif defined(cpu16): 16
                     else: 0

const ArrayDummySize* = when defined(cpu16): 10_000 else: 100_000_000

type DynArray* {.unchecked.}[T] = array[0..ArrayDummySize, T]


proc allocSharedDynArray*[T](size: Natural): ptr DynArray[T] =
  let arrayPointer = allocShared(size * sizeof(T) )
  result = cast[ptr DynArray[T]]( arrayPointer )

proc isPowerOfTwo*(num :uint32): bool =
  bool((num and not (num and (num - 1))) == num)
