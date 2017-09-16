# Asynchronous jobs (like files, sound ..)
# Most of them need very small ammounts of CPU and block the thread, that's why
# they have their own threadpool

import job
import sharedDeque
import freelist
import atomicwrapper
import math

const asyncThreads= 10
const maxAsyncJobs = 128

var
  threadPool: FreeList[Thread[ptr Job]]
  jobPool: FreeList[Job] # Allocate the object and return the pointer
  pendentJobs: SharedDeque[maxAsyncJobs - 1, ptr Job]

proc initAsync*() =
  threadPool.init(asyncThreads)
  jobPool.init(maxAsyncJobs)
  pendentJobs.init()

proc deleteAsyncJob*(job: ptr Job) =
  # A pointer to a Job is the same as the pointer to it's node because it's the
  # first thing inside the node
  jobPool.add(job)

proc asyncThread(job: ptr Job) {.thread.} =
  var job = job
  while job != nil:
    execute(job) # Call callback
    deleteAsyncJob(job)
    job = pendentJobs.pop() # Try to get callback

  # Put itself into the threadPool
  #threadPool.add(threadId())

proc newAsyncJob* ( function: Jobfunction, parent: ptr Job) : ptr Job {.gcsafe.} =
  result = jobPool.tryGet()
  result.initJob(parent, function)

proc newAyncJob* ( function: Jobfunction, parent: ptr Job, sons: int32) : ptr Job {.gcsafe.} =
  result = jobPool.tryGet()
  result.initJob(parent, function, sons)


proc newAsyncJob* ( function: Jobfunction): ptr Job {.gcSafe,inline.} =
  result = jobPool.tryGet()
  result.initJob(function)

proc newAsyncJob* ( function: Jobfunction, sons: int32): ptr Job {.gcSafe,inline.} =
  result = jobPool.tryGet()
  result.initJob(function,sons)



proc loadAsyncJob*(job: ptr Job) =
  var thread: ptr Thread[ptr Job] = threadPool.tryGet()
  #If we could had
  if thread != nil:
    thread[].createThread(asyncThread, job)
  else:
    pendentJobs.push(job)

when isMainModule:
  import unittest
  from os import sleep

  var testVar = 0

  proc asyncHello(job: ptr Job) =
    testVar = 1

  suite "Async":
    test "Basic test":
      initAsync()
      var job = getAsyncJob()
      job.initJob(asyncHello)
      job.loadAsyncJob()
      os.sleep(500)
      assert(testVar == 1)

