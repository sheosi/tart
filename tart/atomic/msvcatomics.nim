import atomicwrapper
import macros
import strutils

proc readWriteBarrier*(){.importc:"_ReadWriteBarrier",nodecl.}
proc memoryBarrier*(){.importc:"MemoryBarrier",nodecl.}

proc interlockedIncrement16*(addend: pointer) {.importc: "InterlockedIncrement16", header: "<windows.h>", cdecl.}
proc interlockedIncrementAcquire16*(addend: pointer) {.importc: "InterlockedIncrementAcquire16", header: "<windows.h>", cdecl.}
proc interlockedIncrementRelease16*(addend: pointer) {.importc: "InterlockedIncrementRelease16", header: "<windows.h>", cdecl.}
proc interlockedIncrementNoFence16*(addend: pointer) {.importc: "InterlockedIncrementNoFence16", header: "<windows.h>", cdecl.}

proc interlockedIncrement*(addend: pointer) {.importc: "InterlockedIncrement", header: "<windows.h>", cdecl.}
proc interlockedIncrementAcquire*(addend: pointer) {.importc: "InterlockedIncrementAcquire", header: "<windows.h>", cdecl.}
proc interlockedIncrementRelease*(addend: pointer) {.importc: "InterlockedIncrementRelease", header: "<windows.h>", cdecl.}
proc interlockedIncrementNoFence*(addend: pointer) {.importc: "InterlockedIncrementNoFence", header: "<windows.h>", cdecl.}

proc interlockedIncrement64*(addend: pointer) {.importc: "InterlockedIncrement64", header: "<windows.h>", cdecl.}
proc interlockedIncrementAcquire64*(addend: pointer) {.importc: "InterlockedIncrementAcquire64", header: "<windows.h>", cdecl.}
proc interlockedIncrementRelease64*(addend: pointer) {.importc: "InterlockedIncrementRelease64", header: "<windows.h>", cdecl.}
proc interlockedIncrementNoFence64*(addend: pointer) {.importc: "InterlockedIncrementNoFence64", header: "<windows.h>", cdecl.}


proc interlockedAdd*(addend: pointer, value: clong ): clong {.importc: "InterlockedAdd", header: "<windows.h>", cdecl.}
proc interlockedAddAcquire*(addend: pointer, value: clong ): clong {.importc: "InterlockedAddAcquire", header: "<windows.h>", cdecl.}
proc interlockedAddRelease*(addend: pointer, value: clong ): clong {.importc: "InterlockedAddRelease", header: "<windows.h>", cdecl.}
proc interlockedAddNoFence*(addend: pointer, value: clong ): clong {.importc: "InterlockedAddNoFence", header: "<windows.h>", cdecl.}

proc interlockedAdd64*(addend: pointer, value: clonglong  ): clonglong {.importc: "InterlockedAdd64", header: "<windows.h>", cdecl.}
proc interlockedAddAcquire64*(addend: pointer, value: clonglong ): clonglong {.importc: "InterlockedAddAcquire64", header: "<windows.h>", cdecl.}
proc interlockedAddRelease64*(addend: pointer, value: clonglong ): clonglong {.importc: "InterlockedAddRelease64", header: "<windows.h>", cdecl.}
proc interlockedAddNoFence64*(addend: pointer, value: clonglong ): clonglong {.importc: "InterlockedAddNoFence64", header: "<windows.h>", cdecl.}

proc interlockedCompareExchange16*(p: pointer; exchange, comparand: cshort): cshort  {.importc: "InterlockedCompareExchange16", header: "<windows.h>", cdecl.}
proc interlockedCompareExchange16Acquire*(p: pointer; exchange, comparand: cshort): cshort  {.importc: "InterlockedCompareExchange16Acquire", header: "<windows.h>", cdecl.}
proc interlockedCompareExchange16Release*(p: pointer; exchange, comparand: cshort): cshort  {.importc: "InterlockedCompareExchange16Release", header: "<windows.h>", cdecl.}
proc interlockedCompareExchange16NoFence*(p: pointer; exchange, comparand: cshort): cshort  {.importc: "InterlockedCompareExchange16NoFence", header: "<windows.h>", cdecl.}

proc interlockedCompareExchange*(p: pointer; exchange, comparand: clong): clong  {.importc: "InterlockedCompareExchange", header: "<windows.h>", cdecl.}
proc interlockedCompareExchangeAcquire*(p: pointer; exchange, comparand: clong): clong  {.importc: "InterlockedCompareExchangeAcquire", header: "<windows.h>", cdecl.}
proc interlockedCompareExchangeRelease*(p: pointer; exchange, comparand: clong): clong  {.importc: "InterlockedCompareExchangeRelease", header: "<windows.h>", cdecl.}
proc interlockedCompareExchangeNoFence*(p: pointer; exchange, comparand: clong): clong  {.importc: "InterlockedCompareExchangeNoFence", header: "<windows.h>", cdecl.}

proc interlockedCompareExchange64*(p: pointer; exchange, comparand: clonglong): clonglong  {.importc: "InterlockedCompareExchange64", header: "<windows.h>", cdecl.}
proc interlockedCompareExchange64Acquire*(p: pointer; exchange, comparand: clonglong): clonglong  {.importc: "InterlockedCompareExchange64Acquire", header: "<windows.h>", cdecl.}
proc interlockedCompareExchange64Release*(p: pointer; exchange, comparand: clonglong): clonglong  {.importc: "InterlockedCompareExchange64Release", header: "<windows.h>", cdecl.}
proc interlockedCompareExchange64NoFence*(p: pointer; exchange, comparand: clonglong): clonglong  {.importc: "InterlockedCompareExchange64NoFence", header: "<windows.h>", cdecl.}

template MsvcProtectRelease*(action: stmt) =
  if order == MemOrder.SeqCst:
    memoryBarrier()
    action
    memoryBarrier()

  else:
    action
    if order == MemOrder.Release or order == MemOrder.AcqRel:
      readWriteBarrier()

template MsvcProtatomicLoadNectAcquire*(action: stmt) =
  if order == MemOrder.SeqCst:
    memoryBarrier()
    action
    memoryBarrier()

  else:
    if order == MemOrder.Acquire or order == MemOrder.AcqRel:
      readWriteBarrier()
    action

proc msvcInterlockedIncrement*[T](val: pointer, order: MemOrder) =
  when sizeof(T) == 2:
    result = case order
    of MemOrder.Relaxed:
      interlockedIncrement16NoFence(val)
    of MemOrder.Consume:
      {.warning: "Degrading consume operation to Acquire".}
      interlockedIncrement16Acquire(val)
    of MemOrder.Acquire:
      interlockedIncrement16Acquire(val)
    of MemOrder.Release:
      interlockedIncrement16Release(val)
    of MemOrder.AcqRel:
      interlockedIncrement16Acquire(val)
      readWriteBarrier()
    of MemOrder.SeqCst:
      interlockedIncrement16(val)

  elif sizeof(T) == 4:
    result = case order
    of MemOrder.Relaxed:
      interlockedIncrementNoFence(val)
    of MemOrder.Consume:
      {.warning: "Degrading consume operation to Acquire".}
      interlockedIncrementAcquire(val)
    of MemOrder.Acquire:
      interlockedIncrementAcquire(val)
    of MemOrder.Release:
      interlockedIncrementRelease(val)
    of MemOrder.AcqRel:
      interlockedIncrementAcquire(val)
      readWriteBarrier()
    of MemOrder.SeqCst:
      interlockedIncrement(val)

  elif sizeof(T) == 8:
    result = case order
    of MemOrder.Relaxed:
      interlockedIncrement64NoFence(val)
    of MemOrder.Consume:
      {.warning: "Degrading consume operation to Acquire".}
      interlockedIncrement64Acquire(val)
    of MemOrder.Release:
      interlockedIncrement64Release(val)
    of MemOrder.AcqRel:
      interlockedIncrement64Acquire(val)
      readWriteBarrier()
    of MemOrder.SeqCst:
      interlockedIncrement(val)

  else:
    {.fatal: "The required size is not supported for interlockedIncrement on MSVC".}

proc msvcInterlockedAdd*[T](addend: pointer, value: T): T =
  when sizeof(T) == 4:
    result = case order
    of MemOrder.Relaxed:
      interlockedAddNoFence(addend, cast[])
