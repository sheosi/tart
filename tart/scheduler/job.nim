import atomicwrapper
import tartutils
import strutils

type
  JobFunction* = proc(self: ptr Job){.thread.}
  Job* = object of RootObj
    function: JobFunction
    parent*: ptr Job
    unfinishedJobs: Atomic[int32]
    data*: array[44,char]


    when defined(cpu32):
      padding: array[8,char]

proc initJob*(self: ptr Job, function: JobFunction) =
  self.function = function
  self.parent = nil
  self.unfinishedJobs.value = 1

proc initJob*(self: ptr Job, function: JobFunction, sons: int32) =
  self.function = function
  self.parent = nil
  self.unfinishedJobs.value = 1 + sons

proc initJob*(self,parent: ptr Job, function: JobFunction) =

  when defined(debug):
    if parent == nil:
      raise newException(ValueError, "Parent can't be nul")

  #inc parent.unfinishedJobs



  self.function = function
  self.parent = parent
  self.unfinishedJobs.value = 1

proc initJob*(self,parent: ptr Job, function: JobFunction, sons: int32) =

  when defined(debug):
    if parent == nil:
      raise newException(ValueError, "Parent can't be nul")

  #inc parent.unfinishedJobs

  self.function = function
  self.parent = parent
  self.unfinishedJobs.value = 1 + sons


proc completed*(self: ptr Job): bool {.inline.} =
  self.unfinishedJobs.value == 0

proc isEmpty*(job: ptr Job): bool {.inline.} =
  job == nil

proc execute*(self: ptr Job){.gcsafe.}

proc finish*(job: ptr Job) =
  let unfinishedJobs = decVal(job.unfinishedJobs, 1, MemOrder.SeqCst)

  # if we have one job left and this is called it means that a child did,
  # so check if should add ourselves.
  if unfinishedJobs == 1:
    {.warning: "See whether is better to execute the parent or to queue it".}
    echo "Hey! Executing myself " & toHex(cast[int](job),16)
    execute(job)

  if unfinishedJobs == 0 and job.parent != nil:
      if job.parent.unfinishedJobs.value == 2:
        echo "Maybe we'll ex'execute daddy " & toHex(cast[int](job.parent),16)
      finish(job.parent)

proc execute*(self: ptr Job) =
  when defined(debug):
    if self == nil:
      raise newException(ValueError, "We got a nil Job")

    if self.function == nil:
      raise newException(ValueError, "Pointer to function is nil")
  self.function(self)
  self.finish()


proc dataAs*(self: ptr Job, T: typedesc, position: Natural = 0): untyped {.inline.}=
  when defined(boundChecks):
    if position * T.size > 44:
      raise newException(IndexError, "index out of bounds")

  result = (cast[ptr T](cast[int](addr self.data[0])+ T.sizeof * position))[]

proc setData*[T](self: ptr Job, position: Natural, data:T) {.inline.}=
  when defined(boundChecks):
    if position * T.size > 44:
      raise newException(IndexError, "index out of bounds")

  (cast[ptr data.type](cast[int](addr self.data[0])+ T.sizeof * position))[] = data
