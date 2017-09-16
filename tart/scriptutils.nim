import queues
import tables
from ospaths import splitFile,`/`

type Style* = enum
  styleReset = 0
  styleBright,            ## bright text
  styleDim,                   ## dim text
  styleUnknown,               ## unknown
  styleUnderscore = 4,        ## underscored text
  styleBlink,                 ## blinking/bold text
  styleReverse = 7,           ## unknown
  styleHidden                 ## hidden text

proc style*(style : Style, str : string) : string {.noSideEffect.}=
  result = "\e[" & $ord(style) & "m" & str & "\e[" & $ord(styleReset) & "m"

type ForegroundColor* = enum
    fgReset = 0,
    fgBlack = 30,
    fgRed,
    fgGreen,
    fgYellow,
    fgBlue,
    fgMagenta,
    fgCyan,
    fgWhite

proc color*(color : ForegroundColor, str : string) : string {.noSideEffect.} =
    result ="\x1b["& $ord(color) & "m" & str & "\x1b["& $ord(fgReset)&"m"


const termSize = 80

iterator walkDir*(path: string): string =
  var dirStack : Queue[string] = initQueue[string](32)
  dirStack.enqueue(path)
  while dirStack.len > 0:
    let dir = dirStack.dequeue()
    for file in listFiles(dir):
      yield file

    for subdir in listDirs(dir):
      dirStack.enqueue(subdir)

proc line*(str: string): string =
  result = " "
  for i in 0..termSize - str.len - 2:
    result &= "-"

  result = str & result

proc writeError*(str: string) =
  echo style(styleBright,(color (fgRed,"Error ")) & str)

proc checkFile*(file: string, options: string = "") =
    var filenameSplit = file.splitFile()
    if filenameSplit.ext == ".nim":
        echo ""
        echo line(style(styleBright,filenameSplit.name))
        try:
          selfExec("c --threads:on --verbosity:0 --hints: off " & options & file)
        except:
          echo ""
          writeError(file  & " failed at compilation.")
          return

        let fileNoExt = filenameSplit.dir/filenameSplit.name

        try:
          exec (fileNoExt)
        except:
          echo ""
          writeError fileNoext & " failed at execution."

proc testPkg*(file:string): bool =
  try:
    exec("pkg-config " & file)
    return true
  except:
    return false

proc testPkgs*(packages:Table[string,string]): bool =
  try:
    echo ("Pkg-config version: ")
    exec ("pkg-config --version")
  except:
    writeError "Couldn't any suitable method of checking libraries, you can continue, but we can't ensure it will work."
    return true

  result = true
  for name,package in pairs packages:
    if not testPkg(package):
      result = false
      writeError "Couldn't find package " & name & "."
