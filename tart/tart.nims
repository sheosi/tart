import scriptutils

task test, "Executes all tart tests":

  for file in walkDir("./"):
    let split = splitFile(file)

    # Do not execute main
    if split.name != "main":
      checkFile(file)

  setCommand "nop"
