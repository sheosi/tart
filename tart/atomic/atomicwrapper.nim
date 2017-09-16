type
  Atomic*[T] = distinct T
  MemOrder* {.pure.} = enum
    Relaxed = 0, Consume, Acquire, Release, AcqRel, SeqCst

  ValOrderTuple*[T] = tuple[value:T, order: MemOrder]

  AtomicSlice*[T] = distinct Slice[var Atomic[T]]
  SliceAtomicLiteral*[T] = tuple[a:var Atomic[T], b: T]
  SliceLiteralAtomic*[T] = tuple[a:T, b:var Atomic[T]]

when defined(msvc):
  import msvcatomics

const someGcc = defined(gcc) or defined(llvm_gcc) or defined(clang)


template alignedVar* (name: expr, T: typedesc, alignment: int): stmt {.immediate.}  =
  when someGcc:
    when alignment == 1:
      var name: T

    elif alignment == 2:
      var name {.codegenDecl: "$# $# __attribute__ ((aligned ( 2 )))".}: T

    elif alignment == 4:
      var name {.codegenDecl: "$# $# __attribute__ ((aligned ( 4 )))".}: T

    elif alignment == 8:
      var name {.codegenDecl: "$# $# __attribute__ ((aligned ( 8 )))".}: T

    else :
      {.fatal: "Can't use desired alignment'".}

  elif defined(msvc):
    var name: T

  else:
    {.warning: "Unknown compiler alignment not guaranteed".}
    var name: Atomic[T]

template atomicVar* (name: expr, T: typedesc) =
  alignedVar(name, T, sizeof(T))

converter getRelaxed*[T](val: var Atomic[T]): T {.inline.}=
  return val.value

proc value*[T](val: var Atomic[T], order: MemOrder = MemOrder.Relaxed): T =
  when someGcc:
    when not (T is AtomType):
      atomicLoadN( cast[ptr ptr T](addr val), order.AtomMemModel )
    else:
      atomicLoadN( cast[ptr T](addr val), order.AtomMemModel )
  elif defined(msvc): #In MSVC simple reads are atomic
    MsvcProtectAcquire: cast[T](val)

  else: {.fatal: "Atomic getter not implemented for this platform".}

proc `value=`*[T](val: var Atomic[T],  newVal: T) =
  when someGcc:
    atomicStoreN( cast [ptr T](addr val), newVal, MemOrder.Relaxed.AtomMemModel)
  elif defined(msvc): #In MSVC simple write are atomic
    MsvcProtectRelease: val = cast[Atomic[T]](newVal)

  else: {.fatal: "Atomic setter not implemented for this platform"}




proc `value=`*[T](val: var Atomic[T],  valOrder: ValOrderTuple[T]) =
  when someGcc:
    atomicStoreN( cast [ptr T](addr val), valOrder.value, valOrder.order.AtomMemModel)
  elif defined(msvc):
    MsvcProtectRelease: val = cast[Atomic[T]](valOrder.val)

  else: {.fatal: "Atomic setter not implemented for this platform"}

# Duplicated because system already has an inc operation, this avoid confusion for Nim
proc inc*[T](val: var Atomic[T], order: MemOrder = MemOrder.Relaxed) =
  when someGcc:
    discard atomicAddFetch( cast[ptr T](addr val),1, order.AtomMemModel)

  elif defined(msvc):
    MsvcAtomic(interlockedAdd,[32,64],addr val)

  else: {.fatal: "Atomic \"inc\" is not implemented in this achitecture".}

proc inc*[T](val: var Atomic[T], value: T, order: MemOrder = MemOrder.Relaxed) =
  when someGcc:
    discard atomicAddFetch( cast[ptr T](addr val),value, order.AtomMemModel)

  elif defined(msvc):
    MsvcAtomic(interlockedAdd,[32,64],addr val)

  else: {.fatal: "Atomic \"inc\" is not implemented in this achitecture".}


proc incVal*[T](val: var Atomic[T], value: T = 1, order: MemOrder = MemOrder.Relaxed): T =
  when someGcc:
    atomicAddFetch( cast[ptr T](addr val),value, order.AtomMemModel)

  elif defined(msvc):
    MsvcAtomic(interlockedAdd,[32,64],addr val)

  else: {.fatal: "Atomic \"inc\" is not implemented in this achitecture".}

proc valInc*[T](val: var Atomic[T], value: T = 1, order: MemOrder = MemOrder.Relaxed): T =
  when someGcc:
    atomicFetchAdd( cast[ptr T](addr val),value, order.AtomMemModel)

  elif defined(msvc):
    MsvcAtomic(interlockedAdd,[32,64],addr val)

  else: {.fatal: "Atomic \"inc\" is not implemented in this achitecture".}


proc increment*[T](val: var Atomic[T],value: T = 1, order: MemOrder = MemOrder.Relaxed): T =
  when someGcc:
    atomicAddFetch( cast[ptr T](addr val),value,order.AtomMemModel)

  elif defined(msvc):
    msvcInterlockedIncrement[T](cast[pointer](addr val), order)

  else: {.fatal: "Atomic \"inc\" is not implemented in this architecture".}

proc dec*[T](val: var Atomic[T], order: MemOrder = MemOrder.Relaxed) =
  when someGcc:
   discard atomicSubFetch( cast[ptr T](addr val),1, order.AtomMemModel)

  elif defined(msvc):
    {.fatal:"Do this for msvc".}
    MsvcAtomic(interlockedAdd,[32,64],addr val)

  else: {.fatal: "Atomic \"inc\" is not implemented in this achitecture".}

proc dec*[T](val: var Atomic[T],value: T, order: MemOrder = MemOrder.Relaxed) =
  when someGcc:
   discard atomicSubFetch( cast[ptr T](addr val),value, order.AtomMemModel)

  elif defined(msvc):
    {.fatal:"Do this for msvc".}
    MsvcAtomic(interlockedAdd,[32,64],addr val)

  else: {.fatal: "Atomic \"inc\" is not implemented in this achitecture".}

proc decVal*[T](val: var Atomic[T], value: T = 1, order: MemOrder = MemOrder.Relaxed): T =
  when someGcc:
    atomicSubFetch( cast[ptr T](addr val),value, order.AtomMemModel)

  elif defined(msvc):
    {.fatal:"Do this for msvc".}
    MsvcAtomic(interlockedAdd,[32,64],addr val)

  else: {.fatal: "Atomic \"inc\" is not implemented in this achitecture".}

proc valDec*[T](val: var Atomic[T],value: T = 1, order: MemOrder = MemOrder.Relaxed): T =
  when someGcc:
    atomicFetchSub( cast[ptr T](addr val),value , order.AtomMemModel)

  elif defined(msvc):
    {.fatal:"Do this for msvc".}
    MsvcAtomic(interlockedAdd,[32,64],addr val)

  else: {.fatal: "Atomic \"inc\" is not implemented in this achitecture".}

proc compareExchange*[T](val: var Atomic[T], expected: T, value: T, order: MemOrder = MemOrder.Relaxed): bool =
  when someGcc:
    #Expected is written so we duplicate it
    var internExpected = expected
    let atomMemModel = order.AtomMemModel
    atomicCompareExchange( cast [ptr T](addr val), addr internExpected,
    unsafeAddr value, false, atomMemModel, atomMemModel)

  elif defined(msvc):
    MsvcAtomic(interlockedCompareExchange)

  else: {.fatal: "Atomic compareExchange not implemented for this platform".}

proc compareExchangeVal*[T](val: var Atomic[T], expected: T, value: T, order: MemOrder = MemOrder.Relaxed): T =
  when someGcc:
    var internExpected = expected
    let atomMemModel = order.AtomMemModel
    result = val.value
    discard atomicCompareExchange( cast [ptr T](addr val), addr internExpected,
    unsafeAddr value, false, atomMemModel, atomMemModel)


  elif defined(msvc):
    MsvcAtomic(interlockedCompareExchange)

  else: {.fatal: "Atomic compareExchange not implemented for this platform".}

proc compareExchangeStrong*[T](val: var Atomic[T], expected: T, value: T, order: MemOrder , orderFail: MemOrder): bool =
  when someGcc:
    var internExpected = expected
    let atomMemModel = order.AtomMemModel
    let atomMemModelFail = orderFail.AtomMemModel
    atomicCompareExchange( cast [ptr T](addr val), addr internExpected,
    unsafeAddr value, true, atomMemModel, atomMemModelFail)

  elif defined(msvc):
    MsvcAtomic(interlockedCompareExchangeStrong)

  else: {.fatal: "Atomic compareExchange not implemented for this platform".}

proc compareExchangeStrong*[T](val: var Atomic[T], expected: T, value: T, order: MemOrder = MemOrder.Relaxed): bool =
  when someGcc:
    var internExpected = expected
    let atomMemModel = order.AtomMemModel
    atomicCompareExchange( cast [ptr T](addr val), addr internExpected,
    unsafeAddr value, true, atomMemModel, atomMemModel)


  elif defined(msvc):
    MsvcAtomic(interlockedCompareExchangeStrong)

  else: {.fatal: "Atomic compareExchange not implemented for this platform".}


proc compareExchangeStrongVal*[T](val: var Atomic[T], expected: T, value: T, order: MemOrder = MemOrder.Relaxed): T =
  when someGcc:
    var internExpected = expected
    let atomMemModel = order.AtomMemModel
    let successful = atomicCompareExchange( cast [ptr T](addr val), addr internExpected,
    unsafeAddr value, true, atomMemModel, atomMemModel)

    result = if successful: value
            else: internExpected

  elif defined(msvc):
    MsvcAtomic(interlockedCompareExchangeStrong)

  else: {.fatal: "Atomic compareExchange not implemented for this platform".}

proc exchange*[T](val: var Atomic[T], newValue: T, order: MemOrder = MemOrder.Relaxed): T =
  when someGcc:
    var internValue: T = newValue
    atomicExchange(cast[ptr T](addr val), addr internValue, addr result, order.AtomMemModel)

  else: {.fatal: "Atomic exchange not implemented for this platform".}

proc threadFence*(order: MemOrder) =
  when someGcc:
    atomicThreadFence(order.AtomMemModel)

  else: {.fatal: "Thread Fence not implemented for this platform".}

proc `<=`*[T](arg1, arg2: var Atomic[T]): bool =
  arg1.value <= arg2.value

proc `==`*[T](arg1, arg2: var Atomic[T]): bool =
  arg1.value == arg2.value

proc `..`*[T](arg1,arg2: var Atomic[T]): AtomicSlice[T] =
  (a: arg1, b: arg2)

iterator items*[T](slice: AtomicSlice[T]): T =
  for x in slice.a.value..slice.b.value:
    yield x

proc `..`*[T](arg1: var Atomic[T], arg2: T): SliceAtomicLiteral[T] =
  (a: arg1, b: arg2)

iterator items*[T](slice: SliceAtomicLiteral[T]): T =
  for x in slice.a.value..slice.b:
    yield x

proc `..`*[T](arg1: T, arg2: var Atomic[T]): SliceLiteralAtomic[T] =
  (a: arg1, b: arg2)

iterator items*[T](slice: SliceLiteralAtomic[T]): T =
  for x in slice.a..slice.b.value:
    yield x

when isMainModule:
  import unittest

  suite "AtomicWrapper":
    test "Check MemOrder constants":
      assert (MemOrder.Relaxed.cint == ATOMIC_RELAXED.cint)
      assert (MemOrder.Consume.cint == ATOMIC_CONSUME.cint)
      assert (MemOrder.Acquire.cint == ATOMIC_ACQUIRE.cint)
      assert (MemOrder.Release.cint == ATOMIC_RELEASE.cint)
      assert (MemOrder.AcqRel .cint == ATOMIC_ACQ_REL.cint)
      assert (MemOrder.SeqCst .cint == ATOMIC_SEQ_CST.cint)

    test "Increment 'inc'":
      alignedVar(someVal,Atomic[int],4)
      #var someVal: Atomic[int]
      someVal.value = 3
      inc someVal
      assert (someVal.value == 4)

