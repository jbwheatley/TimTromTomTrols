# TimTromTomTrols
Things I Made The RObot Make TO Make The RObot Less Shit

| Hook | What it does |
| --- | --- |
| `block-commit-style.sh` | Denies commits with heredoc messages, Co-Authored-By trailers, or emoji. |
| `clear-read-record.sh` | Clears the session read record on compaction so reads are allowed again. |
| `no-munit-timeout-change.sh` | Denies edits that add or raise munitTimeout and munitIOTimeout values. |
| `no-redundant-read.sh` | Denies re-reading a file already read this session and unchanged since. |
| `no-scala-comments.sh` | Denies comments written into Scala and sbt sources. |
| `no-shell-source-edits.sh` | Denies shell redirects, tee and in-place edits targeting Scala or sbt sources. |
| `require-claude-md-rules-read.sh` | Denies CLAUDE.md edits until maintaining-claude-md.md has been read this session. |
| `scala-reads-via-semanticdb.sh` | Denies text reads of indexed Scala source, routing them through the MCP server. |
| `semanticdb-staleness.sh` | Warns after MCP calls when the index or classpath snapshot is stale. |
