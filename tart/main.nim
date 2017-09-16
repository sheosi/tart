import macros
import os
import tablep
import sharedtable
import scheduler
import mainthread
import async
import job
import strutils
import maybe


# Import all Nim files in the modules folder
macro importModules(): untyped =
  result = newStmtList()
  let modulesNode = newIdentNode("../modules")

  for file in walkDir( "modules" , true):

    let splitName = file.path.splitFile
    if splitName.ext == ".nim":
      result.add(
        newNimNode( nnkImportStmt).add(
          infix(modulesNode,"/", newIdentNode(splitName.name) )
        )
      )

macro getNumModules(): untyped =
  var numMod = 0

  for file in walkDir( "modules" , true):

    let splitName = file.path.splitFile
    if splitName.ext == ".nim":
      inc numMod

  result = newIntLitNode(numMod)

proc extractName(node: NimNode): NimNode {.compileTime.} =
  case node[0].kind
    of nnkPostfix:
      result = node[0][1]
    of nnkIdent:
      result = node[0]
    else:
      raise newException(Exception, "Name format not supported: " & $node[0].kind)

macro onEvent*(eventName: string, code: untyped): untyped =
  result = newStmtList()
  code.addPragma ident("thread")
  result.add code
  result.add newCall("hookFunc",[newStrLitNode(eventName.strVal.toLowerAscii()), extractName(code) ])


const numModules* = getNumModules
const dictSize* = 32

var hookDict* : SharedTable[string, TableP[numModules * 2,Jobfunction]]


proc newHook*(name: string) =
  when defined(debug):
    if ?hookDict[name]:
      raise newException(ValueError, "This has been already created")
  hookDict.add(name)
  hookDict[name].unbox[].init()

proc `$`*[T:ptr TableP](self:T): string =
  cast[uint](self).int.toHex()
# Hook func adds a new function to the hook, in order to making it easier,
# hookFunc will determine whether the dictionary and the entry is initialized.
proc hookFunc*(name: string, fun: JobFunction) {.thread.} =

  if not hookDict.initialized:
    hookDict.init(dictSize)

  var dictResult = hookDict[name]

  if not ?dictResult:
    newHook(name)
    dictResult = hookDict[name]


  dictResult.unbox[].append(fun)

# When we need to make it faster here we have just the initialization
proc hookFuncDirect*(name: string, fun: JobFunction) {.thread.} =
  let dictResult = hookDict[name]

  when defined(debug):
    if not ?dictResult:
      raise newException(OSError, "Dictionary entry not initialized")

  dictResult.unbox[].append(fun)

proc normalize*(str: string): string =
   str.toLowerAscii()

proc callHook*(name: string){.thread.} =
  echo "Calling hook " & name
  var result = hookDict[name.normalize()].unbox[]
  echo name & ":" & $result.len & " (0x" & $hookDict[name].unbox & ")"
  if result.whenJobsFinished != nil:

    if result.len > 0'u16:
      let parent = newJob(result.whenJobsFinished, result.len.int32)
      for fp in result:
        discard addJob(fp,parent)
    else:
      discard addJob(result.whenJobsFinished)

  else:
    for fp in result:
      discard addJob(fp)

proc initialHook(job: ptr Job) =
  # Let's call the hook manually, we don't want to have the next onFinished
  # called by every thread

  var result = hookDict["thread init"].unbox[]

  for fp in result:
    discard addJob(fp, job.parent)

import atomicwrapper

proc setHookFinalizedCallback*(name: string, fun: Jobfunction) {.thread.} =
  hookDict[name].unbox[].whenJobsFinished= fun

proc initialFinished(job: ptr Job) =

  callHook("game init")

proc gameInitFinished(job: ptr Job) =
  callHook("allegro init")

proc allegroInitFinished(job: ptr Job) =
  var tmpRender = hookDict["tmp frame render"].unbox[]

  for callback in tmpRender:
    hookFuncDirect("frame render", callback)

  setHookFinalizedCallback("frame render", tmpRender.whenJobsFinished)

  callHook("game start")

proc callFrameRender(job: ptr Job)  =
  callHook("frame render")


when isMainModule:
  if not hookDict.initialized:
    hookDict.init(dictSize)

  importModules()

  scheduler.globalInit()
  async.initAsync()
  mainthread.initMainThreadProcess()

  if not ?hookDict["thread init"]:
    newHook("thread init")

  if not ?hookDict["frame render"]:
    newHook("frame render")
  else:
    echo "It's not recomended to put anything on frame render directly, as it will run even before it has to, pleas use 'tmp frame render' instead. "

  # Where we put this new job?
  {.warning: "We are putting a very initial (and important job) into the main thread, though we might need this, as some things just assume that".}

  var callbackJob = newMainThreadJob( initialFinished, workerThreadsCount.int32)

  setHookFinalizedCallback("game init", gameInitFinished)
  setHookFinalizedCallback("allegro init", allegroInitFinished)

  init(initialHook , callbackJob, callFrameRender )
