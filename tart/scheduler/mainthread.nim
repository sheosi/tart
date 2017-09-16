# Some operations need to be done on the main thread.

import job
import wordQueue
import freelist
import atomicwrapper

const maxMainThreadJobs = 128

var
  jobPool: FreeList[Job] # Allocate the object and return the pointer
  pendentJobs: WordQueue[maxMainThreadJobs - 1, ptr Job]

proc newMainThreadJob*(fun: JobFunction): ptr Job =
  result = jobPool.tryGet()
  when defined(debug):
    if result == nil:
      raise newException(ValueError, "We got nil from the jobPool")

  result.initJob(fun)

proc newMainThreadJob*(fun: JobFunction,sons: int32): ptr Job =
  result = jobPool.tryGet()
  when defined(debug):
    if result == nil:
      raise newException(ValueError, "We got nil from the jobPool")

  result.initJob(fun, sons)

proc newMainThreadJob*(fun: JobFunction, parent: ptr Job): ptr Job=
  result = jobPool.tryGet()
  result.initJob(parent, fun)

proc newMainThreadJob*(fun: JobFunction, parent: ptr Job, sons: int32): ptr Job=
  result = jobPool.tryGet()
  result.initJob(parent, fun, sons)

proc deleteMainThreadJob*(job: ptr Job) =
  # A pointer to a Job is the same as the pointer to it's node because it's the
  # first thing inside the node
  jobPool.add(job)

proc mainThreadProcess*() =
  var job = pendentJobs.pop()

  while job != nil:
    execute(job) # Call callback
    deleteMainThreadJob(job)
    job = pendentJobs.pop() # Try to get callback

  # Put itself into the threadPool
  #threadPool.add(threadId())

proc initMainThreadProcess*() =
  jobPool.init(maxMainThreadJobs)
  pendentJobs.init()

proc loadMainThreadJob*(job: ptr Job) =
    pendentJobs.push(job)

when isMainModule:
  import unittest
  from os import sleep

  var testVar = 0

  proc setVarProc(job: ptr Job) =
    testVar = 1

  suite "Main thread":
    test "Basic test":
      initMainThreadProcess()
      var job = getMainThreadJob()
      job.initJob(nil, setVarProc)
      job.loadMainThreadJob()
      mainThreadProcess()
      assert(testVar == 1)
