# Diagnostics used on this port

All of these live in [ps3recomp](https://github.com/sp00nznet/ps3recomp) and are
off by default. They were written while driving this title and are
title-agnostic.

Both in `ps3recomp/libs/video/cellGcmSys.c`, both off by default:

* `GCM_FIFO_SNAP=N` — dumps the raw words at *both* ends of the ring, what
  `get` is about to decode and what the title just wrote at `put`.
* `GCM_DRAINDBG=1` now also prints `[DRAINEND] <reason>` — why each pass
  stopped and how far it got, with every break site in the walk tagged.
* `GCM_CTXDBG=1` — report `gCellGcmCurrentContext`: which context the title is
  actually driving, and its begin/end/current/callback. This is what showed VF5
  never uses the one `cellGcmInit` handed back.
* `GCM_GET_EQ_PUT=1` — publish `get` as having reached `put`. A probe, not a
  fix: it removes the back-pressure a title uses to avoid overwriting commands
  the GPU has not read. It answers one question — is the title reading `get`?

And elsewhere in the runtime:

* `MSGDIALOG_ANSWER=no` — answer every yes/no prompt NO instead of YES. The
  auto-answer is a guess about what the title wants and yes is not always the
  boot-friendliest branch. (For VF5 it changes nothing; the prompt was not the
  gate — but that took one run to establish rather than a rebuild.)


* `TTY_BT=<substring>` — dump the call chain whenever the title prints a line
  containing it. Three hooks in that function and one in `lv2_register.c`
  already did exactly this for one hardcoded string each, which only ever
  helped the title they were written for. A title's own error message is the
  cheapest breakpoint there is: it fires exactly when the thing went wrong, on
  the thread it went wrong on. Link with `/MAP` and every RVA in the chain maps
  straight back to a `func_XXXXXXXX`, i.e. a guest address. This is what found
  AMGL's `gcmReserve` above.


