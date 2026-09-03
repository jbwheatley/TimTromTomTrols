val writeSemanticClasspath =
  taskKey[File]("Write every module's test classpath to .claude/scala-semantic-classpath.txt for the MCP server")

val everyModuleTestClasspath = ScopeFilter(inAnyProject, inConfigurations(Test))

lazy val root = (project in file("."))
  .enablePlugins(com.github.mercurievv.scalasemantic.sbtplugin.ScalaSemanticMcpPlugin)
  .settings(
    writeSemanticClasspath := Def.uncached {
      val converter = fileConverter.value
      val entries = fullClasspath
        .all(everyModuleTestClasspath)
        .value
        .flatten
        .map(entry => converter.toPath(entry.data).toAbsolutePath.toString)
        .distinct
      val listing = (ThisBuild / baseDirectory).value / ".claude" / "scala-semantic-classpath.txt"
      IO.write(listing, entries.mkString("\n") + "\n")
      listing
    }
  )
