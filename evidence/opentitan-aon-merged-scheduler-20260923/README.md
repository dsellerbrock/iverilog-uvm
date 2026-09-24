# Selected AON runtime replay after the scheduler change

`result.json` records the installed VVP SHA, the preexisting pinned-release
AON image SHA, exact arguments, and report counts. The saved runtime log is
`smoke.log.gz`. This replay finished at 348420188 ps with `TEST PASSED CHECKS`
and zero UVM warnings, errors, or fatals. The image was built at the earlier
`07d8ba6` checkpoint and was **not** recompiled at this branch HEAD; this
checks the changed runtime scheduler against that image, not a fresh full
OpenTitan build or DV suite.
