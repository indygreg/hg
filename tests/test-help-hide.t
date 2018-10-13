Test hiding some commands (which also happens to hide an entire category).

  $ hg --config help.hidden-command.clone=true \
  > --config help.hidden-command.init=true help
  Mercurial Distributed SCM
  
  list of commands:
  
  Remote repository management:
  
   incoming      show new changesets found in source
   outgoing      show changesets not found in the destination
   paths         show aliases for remote repositories
   pull          pull changes from the specified source
   push          push changes to the specified destination
   serve         start stand-alone webserver
  
  Change creation:
  
   commit        commit the specified files or all outstanding changes
  
  Change manipulation:
  
   backout       reverse effect of earlier changeset
   graft         copy changes from other branches onto the current branch
   merge         merge another revision into working directory
  
  Change organization:
  
   bookmarks     create a new bookmark or list existing bookmarks
   branch        set or show the current branch name
   branches      list repository named branches
   phase         set or show the current phase name
   tag           add one or more tags for the current or given revision
   tags          list repository tags
  
  File content management:
  
   annotate      show changeset information by line for each file
   cat           output the current or given revision of files
   copy          mark files as copied for the next commit
   diff          diff repository (or selected files)
   grep          search revision history for a pattern in specified files
  
  Change navigation:
  
   bisect        subdivision search of changesets
   heads         show branch heads
   identify      identify the working directory or specified revision
   log           show revision history of entire repository or files
  
  Working directory management:
  
   add           add the specified files on the next commit
   addremove     add all new files, delete all missing files
   files         list tracked files
   forget        forget the specified files on the next commit
   remove        remove the specified files on the next commit
   rename        rename files; equivalent of copy + remove
   resolve       redo merges or set/view the merge status of files
   revert        restore files to their checkout state
   root          print the root (top) of the current working directory
   status        show changed files in the working directory
   summary       summarize working directory state
   update        update working directory (or switch revisions)
  
  Change import/export:
  
   archive       create an unversioned archive of a repository revision
   bundle        create a bundle file
   export        dump the header and diffs for one or more changesets
   import        import an ordered set of patches
   unbundle      apply one or more bundle files
  
  Repository maintenance:
  
   manifest      output the current or given revision of the project manifest
   recover       roll back an interrupted transaction
   verify        verify the integrity of the repository
  
  Help:
  
   config        show combined config settings from all hgrc files
   help          show help for a given topic or a help overview
   version       output version and copyright information
  
  additional help topics:
  
  Mercurial identifiers:
  
   filesets      Specifying File Sets
   hgignore      Syntax for Mercurial Ignore Files
   patterns      File Name Patterns
   revisions     Specifying Revisions
   urls          URL Paths
  
  Mercurial output:
  
   color         Colorizing Outputs
   dates         Date Formats
   diffs         Diff Formats
   templating    Template Usage
  
  Mercurial configuration:
  
   config        Configuration Files
   environment   Environment Variables
   extensions    Using Additional Features
   flags         Command-line flags
   hgweb         Configuring hgweb
   merge-tools   Merge Tools
   pager         Pager Support
  
  Concepts:
  
   bundlespec    Bundle File Formats
   glossary      Glossary
   phases        Working with Phases
   subrepos      Subrepositories
  
  Miscellaneous:
  
   deprecated    Deprecated Features
   internals     Technical implementation topics
   scripting     Using Mercurial from scripts and automation
  
  (use 'hg help -v' to show built-in aliases and global options)

Test hiding some topics.

  $ hg --config help.hidden-topic.deprecated=true \
  > --config help.hidden-topic.internals=true \
  > --config help.hidden-topic.scripting=true help
  Mercurial Distributed SCM
  
  list of commands:
  
  Repository creation:
  
   clone         make a copy of an existing repository
   init          create a new repository in the given directory
  
  Remote repository management:
  
   incoming      show new changesets found in source
   outgoing      show changesets not found in the destination
   paths         show aliases for remote repositories
   pull          pull changes from the specified source
   push          push changes to the specified destination
   serve         start stand-alone webserver
  
  Change creation:
  
   commit        commit the specified files or all outstanding changes
  
  Change manipulation:
  
   backout       reverse effect of earlier changeset
   graft         copy changes from other branches onto the current branch
   merge         merge another revision into working directory
  
  Change organization:
  
   bookmarks     create a new bookmark or list existing bookmarks
   branch        set or show the current branch name
   branches      list repository named branches
   phase         set or show the current phase name
   tag           add one or more tags for the current or given revision
   tags          list repository tags
  
  File content management:
  
   annotate      show changeset information by line for each file
   cat           output the current or given revision of files
   copy          mark files as copied for the next commit
   diff          diff repository (or selected files)
   grep          search revision history for a pattern in specified files
  
  Change navigation:
  
   bisect        subdivision search of changesets
   heads         show branch heads
   identify      identify the working directory or specified revision
   log           show revision history of entire repository or files
  
  Working directory management:
  
   add           add the specified files on the next commit
   addremove     add all new files, delete all missing files
   files         list tracked files
   forget        forget the specified files on the next commit
   remove        remove the specified files on the next commit
   rename        rename files; equivalent of copy + remove
   resolve       redo merges or set/view the merge status of files
   revert        restore files to their checkout state
   root          print the root (top) of the current working directory
   status        show changed files in the working directory
   summary       summarize working directory state
   update        update working directory (or switch revisions)
  
  Change import/export:
  
   archive       create an unversioned archive of a repository revision
   bundle        create a bundle file
   export        dump the header and diffs for one or more changesets
   import        import an ordered set of patches
   unbundle      apply one or more bundle files
  
  Repository maintenance:
  
   manifest      output the current or given revision of the project manifest
   recover       roll back an interrupted transaction
   verify        verify the integrity of the repository
  
  Help:
  
   config        show combined config settings from all hgrc files
   help          show help for a given topic or a help overview
   version       output version and copyright information
  
  additional help topics:
  
  Mercurial identifiers:
  
   filesets      Specifying File Sets
   hgignore      Syntax for Mercurial Ignore Files
   patterns      File Name Patterns
   revisions     Specifying Revisions
   urls          URL Paths
  
  Mercurial output:
  
   color         Colorizing Outputs
   dates         Date Formats
   diffs         Diff Formats
   templating    Template Usage
  
  Mercurial configuration:
  
   config        Configuration Files
   environment   Environment Variables
   extensions    Using Additional Features
   flags         Command-line flags
   hgweb         Configuring hgweb
   merge-tools   Merge Tools
   pager         Pager Support
  
  Concepts:
  
   bundlespec    Bundle File Formats
   glossary      Glossary
   phases        Working with Phases
   subrepos      Subrepositories
  
  (use 'hg help -v' to show built-in aliases and global options)
