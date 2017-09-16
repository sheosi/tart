import tart/scriptutils
import tables
import ospaths

const projectName = "project"

task prepareEnv, "Installs the necessary things for building":

  var hasNimble = true
  #Test whether we have nimble installed
  try:
    exec("nimble -v")
  except:
    writeError "Nimble executable not found, please put it inside your PATH and try again"
    hasNimble = false

  if hasNimble:
    exec("nimble -y install allegro5")

  if not testPkgs( {"Allegro 5": "allegro-5"}.toTable):
    return

#task test, "Tests project modules":

task config, "Configures the project":
  echo "Not yet implemented, for configuring the project set 'projectName' inside 'project.nims' and also the 'nimcachedir' line inside 'tart/nim.cfg' "

task build, "Builds the project":
  switch("threads" , "on")
  switch("path", "tart")
  switch("path" , "tart/structures")
  switch("path", "tart/scheduler")
  switch("path", "tart/atomic")
  switch("out", "project")

  switch("define", "debug")
  switch("lineDir", "on")
  switch("debuginfo")
  setCommand("c","tart/main")

task test, "Executes all modules tests":

  for file in walkDir("./modules"):
    let split = splitFile(file)

    # Do not execute main
    if split.name != "main":
      checkFile(file, "--p tart")

  setCommand "nop"

task run, "Builds the project and run it":
    exec("nim build project")
    exec("./project")
    setCommand "nop"

