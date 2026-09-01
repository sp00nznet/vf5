# Virtua Fighter 5 — Static Recompilation

> Turning Sega AM2's *Virtua Fighter 5* (2007, `BLUS30020`) from a PS3 disc
> binary into a native Windows executable — no emulator underneath.

*Virtua Fighter 5* is Yu Suzuki's series at its most austere: no items, no
gimmicks, seventeen fighters and a frame-perfect combat engine that AM2 built on
the Lindbergh arcade board and brought to PS3 in early 2007. It is also, by a
wide margin, the **cleanest recompilation target in the PS3 retail library** —
see below.

This project takes the disc's own `EBOOT.BIN`, disassembles every PowerPC
function, lifts them to C++, and links the result against
[ps3recomp](https://github.com/sp00nznet/ps3recomp) — clean-room HLE runtime
libraries that stand in for the PS3 operating system. Same approach as
[twistedmetal](https://github.com/sp00nznet/twistedmetal),
[flow](https://github.com/sp00nznet/flow) and
[simpsonsarcade-ps3](https://github.com/sp00nznet/simpsonsarcade-ps3).

**You supply your own disc.** No game binary, asset, or key is committed here.

## Why this title

Picked out of a 1,080-title sweep of the USA retail library
(`scout/SCOUT.md`), triaged on the one signal that predicts porting effort —
the real `proc_prx_param` → libstub import table, not genre and not binary size.

VF5 came back with the **smallest OS surface in the entire library**:

| | VF5 | Twisted Metal | flOw | YDKJ |
|---|---|---|---|---|
| Imported functions | **107** | 439 | — | 265 |
| Imported modules | **10** | 34 | — | 23 |
| PSN / online imports | **0** | 111 | some | 4 modules |
| `cellSpurs` imports | **0** | 46 | yes | yes |
| exec segment | 6.3 MB | 16 MB | — | 5.2 MB |

Ten modules, all of them already implemented in ps3recomp:

```
cellSysutil(23)  sysPrxForUser(22)  cellGcmSys(19)  cellAudio(11)
cellResc(11)     sys_fs(8)          cellSync(5)     sys_io(4)
cellRtc(3)       cellSysmodule(1)
```

That is the whole list. **No `sceNp`, no `sys_net`, no `cellNetCtl`** — nothing
to gate the boot on a PSN handshake, which is what Twisted Metal spends its
first seconds on and what Jackbox (222 online imports) would drown in. **No
`cellSpurs`** — the SPURS jobchain/task pipeline that parked Simpsons Arcade for
weeks and still parks flOw simply is not in this binary. VF5 drives its four SPU
programs through raw `sys_spu_thread_group_*` plus five `cellSync` primitives,
which is the path ps3recomp implements most directly.

The bet: with caner's live NV4097 → D3D12 engine now executing titles' real
vertex and fragment programs, a title whose only real dependencies are GCM,
audio, pad and the filesystem should reach geometry with the least new runtime
work of anything in the library — and it is a genuine 3D game, so what it draws
is a real test of the engine rather than a UI composite.

## Status

| Phase | State |
|---|---|
| Disc inventory | **done** — `BLUS30020`, disc game, no game-side PRX |
| `EBOOT.BIN` → plain `EBOOT.ELF` | **done** — `../twistedmetal/tools/decrypt_self.py`, 8.1 MB ELF |
| Import / NID analysis | **done** — 107 imports, 10 libraries, 99 named (92%) |
| Function boundary detection | **done** — 17,856 functions, `.opd` + prologue/leaf/extent |
| SPU image extraction | **done** — 4 embedded SPU ELFs, 344 KB |
| SPU lifting | **done** — all 4 lifted (4,121 functions), registered by fingerprint |
| PPU lifting | **done** — 18,514 functions emitted, 7,855 unique call targets, 105 MB of C++ |
| HLE NID table | **done** — 1,040 handlers across 88 modules |
| Build & link | **done** — 89 MB x86-64 exe, clang-cl 21 + Ninja, 0 errors, no title-specific code |
| Boot | **runs clean at ~63 fps, zero unresolved imports, zero errors** — clears and flips every frame; no geometry yet, see below |

### The binary

```
EBOOT.elf     8,109,128 bytes   ELF64 big-endian PowerPC64, ET_EXEC
                                entry 0x690E58 -> OPD { func 0x1022C, toc 0x6BB088 }
                                8 program headers, 38 sections
  PT_LOAD[0]  0x00010000  R-X  0x648958   code + rodata
  PT_LOAD[1]  0x00660000  RW-  0x0614C4   data
  PT_LOAD[2]  0x10000000  R--  0x070CD8
  PT_LOAD[3]  0x10080000  RW-  0x06EE00   (+ 6.2 MB .bss)
```

Retail, so it is stripped. Function recovery leans on the `.opd` table plus
ps3recomp's prologue/leaf/extent heuristics.

**`--code-end 0x5CC830`.** The last `SHF_EXECINSTR` section ends there, and it
is also the section that holds the `.lib.stub` import trampolines
(`0x5CBAD0..0x5CC810`) — so the bound has to sit just past them, not before, or
`--hle-stubs` has nothing to rewrite. Everything above `0x5CC830` is `.rodata`
packed into the same R-X segment, which is exactly the data-as-code trap that
cost flOw and YDKJ multi-gigabyte lifts.

## First boot

`vf5.exe` linked on the first attempt with **nothing title-specific in the
tree** — no `hle_extra.cpp`, no bespoke `boot_main`, no patched functions. That
is the whole argument for this title, and it held.

What the first run does:

```
[cellGame] title id from PARAM.SFO: 'BLUS30020'
[crt] sys_initialize_tls: block 0x0E000000, r13=0x0E007000
[sys_memory] allocate(size=0xA400000)                      164 MB heap
[HLE] _cellGcmInitBody(cmdSize=0x6FF000, ioSize=0x700000)
[cellGcmSys] SetTile x15                                   the title's own RSX tile map
[cellVideoOut] GetResolution(id=2) -> 1280x720
init_display:1280x720                                      <- the title's own log line
[cellGcmSys] SetDisplayBuffer(id=0/1/2, pitch=5120, 1280x720)
[live-draw] display buffer 0/1/2 registered
[rsx] live-draw engine up (D3D12); backend init OK -- window open
[cellPad] Init(max_connect=2)
[SYS] sys_ppu_thread_create ... name="flpt_readnw_thread"  x19
[fs] open .../objset/obj_db.bin, tex_db.bin, rom/2d/aet_db.bin,
     rom/rob/mot_db.farc, rom/live_data.farc, ps3/en/GAMEDATA.farc,
     lang/en/string_array.bin, sound/voice_en/voice.als, ...
```

So: CRT, TLS, heap, GCM, the title's fifteen RSX tiles, triple-buffered 720p
display buffers registered with the live engine, a D3D12 window, pad init,
nineteen of the game's own file-reader threads, and its real asset databases
opening off the disc. Then it parks in a 60 Hz `event_queue_receive(q=3,
timeout=16666)` and draws nothing — `groups[seen=0 exec=0]`.

### The boot, and every gate cleared so far

**All 107 imports now dispatch to a real implementation — zero unresolved NIDs.**
Five gaps, each one found by the previous one being closed:

**1. `sys_spinlock_*`** — `0x8C2BB498` / `0x722A0254` / `0x5267CB35`, 40 calls,
unnamed in ps3recomp's database. Brute-forcing `compute_nid()` over the
`sysPrxForUser` export list identified them as
`sys_spinlock_initialize` / `_trylock` / `_unlock`. A `sys_spinlock_t` is one
32-bit word in guest memory and nothing else, so the implementation is a host
test-and-set on that word. All four registered, names added to the database.

**2. The whole `_sys_heap_*` family was unregistered.** Every function existed
in `sysPrxForUser.c` — under a name *without* the leading underscore, so
`gen_hle_nids.py` hashed NIDs nothing imports and the family fell through to the
unresolved default. `_sys_heap_create_heap` handed back 0, every allocation off
that heap returned 0, and the title took its out-of-memory path.

**3. …which opened a message dialog, and `cellMsgDialogOpen` was unregistered
too.** Only `Open2` was, so the older entry point got the unresolved default and
the title waited forever for a callback that could never fire. With `Open`
registered, the dialog is finally *visible* — and it is the game-data prompt,
not an error:

```
[DIALOG] Do you want to use game data? The HDD access indicator will flash
         while game data is in use. Do not switch off the power during this time.
[cellMsgDialog] Auto-responding: YES
```

**4. `cellAudioGetPortBlockTag`** — the next thing the title hit, 39 calls. The
tag a title reads to tell whether the audio block it is about to fill has been
consumed; without it the mixer thread has no way to advance. `read_index`
already counted blocks consumed, so it *is* the tag counter — implemented with
the same normalisation the hardware does.

**5. `cellAudioOutGetState`** — one call, the last one. There is no "no audio
device" case a recompiled port can be in, so it reports enabled, LPCM, stereo,
48 kHz.

Past all five the title runs properly: nineteen `flpt_readnw_thread` file
readers, its worker pool waking ~48 Hz, its loader thread pumping a 9-second
event queue that delivers ~180 events/sec, its asset databases open, clearing
and flipping a black loading screen.

### AMGL's command buffer — found and fixed

The title's own error message turned out to be the cheapest breakpoint
available. `TTY_BT="Command Buffer Overflow"` (new, below) gives the chain, and
it lands in textbook libgcm `gcmReserve` at `0x00595358`:

```
00595370:  lwz   r10, 0x8(r3)     ; current = ctx->current
00595374:  lwz   r0,  0x4(r3)     ; end     = ctx->end
00595378:  addi  r9, r10, 8       ; need 8 more bytes
00595384:  cmplw cr7, r9, r0
00595388:  bgt   cr7, 0x5953C0    ; no room -> call ctx->callback
...
005953D4:  bctrl
005953DC:  cmpdi cr7, r3, 0
005953E0:  bne   cr7, <return>    ; non-zero: give up
005953E4:  lwz   r10, 0x8(r31)    ; zero: reload current and write ANYWAY
```

and the callback AMGL installed, `0x0048BB70`, is *only*:

```
0048BBB4:  lwz  r3, 0x2948(r2)    ; "[AMGL]:[ERROR] Command Buffer Overflow!"
0048BBC4:  bl   0x539FB0          ; printf
0048BBD0:  li   r3, 0             ; ...and return 0
```

`gcmReserve` reads 0 as "retry" and writes past `end` regardless. That was the
overrun.

Then `GCM_CTXDBG=1` (new) showed *which* buffer:

```
[CTX] gCellGcmCurrentContext@0x1071CDC0 -> 0x1071CDB0  begin=4AE00000
      end=4AE7FFFC current=4AE004E4 callback=006A8030  (ours=0x0F800000)
```

The title never uses the context `cellGcmInit` handed back. It drives a **512 KB
ring of its own at EA 0x4AE00000** — exactly where every `put` it writes
resolves — with its own do-nothing callback. Hardware never fills that ring
because it is recycled once the RSX has consumed it, so the runtime now does
that on the title's context when it is provably safe: the walker has drained
everything submitted (`get == put`) and `current` is within a page of `end`.
Append the JUMP at `current` the way the SDK's own callback does, reset
`current` to `begin`, point `put`/`get` there. Inert for any title whose own
callback recycles.

| | before | after |
|---|---|---|
| `Command Buffer Overflow` | 144,709 | **0** |
| `AddressToOffset failed` | 1,802 | **0** |
| guest clears reaching the engine | 819, stopping 1.6% in | **2,038 and still climbing at cutoff** |
| frame rate | ~32 fps | **~63 fps** |

**The title now renders continuously for the whole run instead of dying 1.6%
into it.**

### What is still in the way

`packets[seen=0] groups[seen=0]` — it clears and flips every frame but submits
no geometry, and stops opening files at twenty. It is sitting in its load state.

What the log says about that state: the loader thread (tid 5) does one
`cond_wait(cond=4)` after the last read and is never signalled again. Its
signaller is the main thread, which is otherwise healthy — running its frame
loop at 63 fps, pumping an event queue that delivers ~180 events/sec, worker
pool waking ~48 Hz. So it is a producer/consumer that has stopped handing out
work, not a hang.

Ruled out by probe, again rather than by argument:

| Hypothesis | Probe | Result |
|---|---|---|
| The dormant `CriSr` SPU thread gates it | `RD_SPU_INTERP=1 RD_SPU_INTERP_ASYNC=1` | no change on any counter |
| A lost wakeup on cond 4 | `FLOW_CONDKICK=1` caps infinite cond waits at 1.5 s | no change |
| A failed file open | every `cellFs` call in the run | 20 opens, 37 reads, **zero failures** |

Notable: the title never calls `cellFsLseek` despite importing it, and reads
`voice.afs` in 2048-byte sectors — CRI's file-system shape. `cellRescInit` is
still never reached, so nothing downstream of the load has started.

### The SPU registry gap — closed

Two registries have always existed. `build_spu_workloads.py` registers each
lifted image by FNV-1a-64 content fingerprint, which is what the `cellSpurs`
path looks up; `sys_spu_thread_group_start` only ever called
`spu_lookup_ppu_fallback(entry_point)`, a different table. VF5 imports **no
`cellSpurs` at all** and drives one plain SPU thread group, so it reported "no
fallback" with its image lifted and registered the whole time — none of its SPU
code had ever run. Now:

```
[SPU] thread tid=0x2000 image @0x100BFB80 (124468 bytes) matched lifted
      workload fp=0x5E90B27CBCB5CC2E image_id=2
[SPU] group_start id=0x1000 tid=0x2000 -> spawned host thread
```

`group_start` only sees the `sys_spu_image` *descriptor* and the registry is
keyed by the ELF's bytes, so `_sys_spu_image_import` now records which ELF each
descriptor came from. The image is the one the thread group is named for:
`CriSr thread group` — CRI's sound renderer, feeding the `_cellsurMixerMain`
thread. It runs the lifted code and stays alive, as a service loop should.

It did not move the boot on its own, but it is a genuine title-agnostic gap and
every future title driving raw SPU thread groups needed it closed.

### The dialog answer was arriving too early

The biggest single unlock of the session, and it had nothing to do with
graphics. `cellMsgDialogOpen2` invoked the guest callback **synchronously, from
inside the open call, before it returned**. Hardware does not: the answer
arrives later, from the title's own `cellSysutilCheckCallback`. The difference
is not cosmetic —

```
state = WAITING;
cellMsgDialogOpen(..., cb, &state);   // our cb sets state = DONE, right here
state = WAITING;                      // ...and the title overwrites it
```

— and a title that arms its wait state *after* the call loses the answer and
waits forever. That is exactly what VF5 does, and it is why it sat on a black
screen with its render state fully configured and nothing to draw.

Deferred to the pump, in the same 55 seconds:

| | before | after |
|---|---|---|
| files opened | 20 | **123** |

and what it opens is the front end: the `vf5ps3_j*.adx` music set, both voice
banks, `spr_c_cmn`/`spr_n_cmn` sprite archives, `spr_c_fnt`/`spr_c_fnt24` fonts,
**`shader_cg_88.farc`**, and `aet_c_cmn.bin` / `aet_n_cmn.bin` — the UI
animation data the attract screens are built from.

(A title that never pumps sysutil would never see a deferred answer at all, so
the old synchronous call stays as the fallback until a pump is observed.)

### The current blocker: a corrupted OPD table

The run ends in a named abort:

```
[ppu] FATAL: stuck calling 0x500088B0 (2000 times) -- aborting run
[ppu]   r9=0x006ADE30 -> 500088B0 6B0048B9 500088B0 6B009CBA
[ppu]   tid=6 lr=0x00510980 r2=0x6B0048B9 r3=0x1070AD40
```

`func_005108C4` is CRI's worker body and the call is the plain ELFv1 idiom:

```
005108EC:  lwz r9, 0x30(r31)   ; r9 = OPD
005108F8:  lwz r0, 0x0(r9)     ; code
0051090C:  lwz r2, 0x4(r9)     ; toc
00510910:  bctrl
00510920:  beq 0x5108EC        ; loop while the callback says "again"
```

so it loops until the callback runs, and the callback can never run. But
`r9 = 0x006ADE30` is **static data in the ELF**, and the EBOOT ships a perfectly
good OPD table there:

```
file:     0050B948 006BB088   0050B99C 006BB088   0050BA90 006BB088 ...
runtime:  500088B0 6B0048B9   500088B0 6B009CBA
```

Every descriptor has the correct TOC `0x006BB088` on disc. At runtime the table
has been **overwritten with a byte-permuted copy of itself** — and the transform
is exact:

```
ror64(bswap64(0x0050B948006BB088), 16) == 0x500088B06B0048B9
```

Per 8-byte descriptor: every 16-bit halfword byte-swapped, then halfwords 1 and
3 exchanged. That is the signature of a misaligned vector store — an
`lvsl`/`lvsr` + `vperm` copy idiom with the wrong lane order, which is exactly
how a PPC memcpy moves unaligned bytes. Nothing about it is game logic: the
title's own static function table is being scrambled underneath it.

`0x500088B0` looks like a heap pointer and is not — it is a permutation of the
real bytes that happens to land in the `_sys_heap` window's range. Chasing it as
an allocator bug (the `_sys_heap_*` free list below was rewritten first) does
not help: the address is byte-identical across runs and the allocator makes
exactly **two** allocations in the whole run.

The next step is naming the store. `YDKJ_AWATCH8` only sees `vm_write8`, so a
bulk or vector store is invisible to it; the page-guard watchpoint
(`ppu_guard_page`) is the tool, but it currently arms only after a *lifted*
store to the watched word, which by definition this is not. Arming it directly
on `0x006ADE30` at boot is a small change and would name the writer in one run.

While in the area, `_sys_heap_*` did get a real allocator: size-binned free
lists instead of a bump pointer with a no-op free, so a title whose middleware
allocates and frees continuously reuses memory instead of walking the window.
Correct, and not what was wrong here.

### Thread inventory

Worth writing down, because it renames the problem:

| tid | name | state |
|---|---|---|
| 1 | main | frame loop, clears + flips |
| 3 | `_sys_mixerSurBusReq` | Sony libmixer |
| 4 | `_cellsurMixerMain` | pumps event queue 1 — healthy |
| 5 | `cri_dlg` | idle on cond 4 (normal with no dialogue queued) |
| 6–9 | `cri_adxm_{vv,vsync,fs,idle}_proc` | CRI ADXM workers; **tid 7 is the one that aborts** |
| 10+ | `flpt_readnw_thread` | spawned per read request |

Sony's surround mixer plus CRI's ADX movie/audio stack, with file readers
spawned per request.

### The render state is fully configured — there are simply no draws

`YDKJ_RSXTRACE` over 200,000 methods of the title's own stream: surfaces
(`0x0200`–`0x022C`), viewport (`0x0A20`–`0x0A3C`), vertex attribute offsets
(`0x1680`–`0x16BC`) and formats (`0x1740`–`0x177C`), texture units
(`0x1A00`+, `0x1B20`–`0x1BB4`), vertex program upload (`0x1EFC`–`0x1F0C`,
11,222 of each), polygon/cull state (`0x1828`–`0x1840`).

The sorted method list jumps straight from `0x177C` to `0x1828`: **the entire
`0x1800`–`0x1824` draw block — `SET_BEGIN_END`, `DRAW_ARRAYS`,
`DRAW_INDEX_ARRAY`, `INLINE_ARRAY` — is absent.** Everything is bound and
nothing is drawn, which is a game-state problem, not a renderer one. The FIFO
walker is demonstrably on the title's own ring by then
(`getoff=00A550A0 put=00A550A0`), so this is what the title actually submits.

### Diagnostics added while chasing this

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

## Building

Prereqs: a built `ps3recomp` (`../ps3recomp/build/ps3recomp_runtime.lib`),
clang-cl, Ninja, Python 3.9+.

```bash
# 1. your own disc -> game/EBOOT.elf
python ../twistedmetal/tools/decrypt_self.py \
    vfs/PS3_GAME/USRDIR/EBOOT.BIN -o game/EBOOT.elf --keys <your scetool keys>

# 2. lift: PPU tree, HLE NID table, 4 SPU images + their fingerprint registry
./tools/relift.sh

# 3. build
cmake -S . -B build -G Ninja \
    -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl
cmake --build build

# 4. run, through the live NV4097 -> D3D12 engine
PS3_VFS_ROOT=vfs/PS3_GAME/USRDIR RSX_LIVE_DRAW=1 ./build/vf5 game/EBOOT.elf
```

`RSX_LIVE_DRAW=1` selects caner's ([@canersaka](https://github.com/canersaka))
live draw engine, wired into ps3recomp's *generic* boot harness rather than
forked per title; unset it and the older `rsx_d3d12_backend` path runs instead.

## Layout

```
game/            your decrypted EBOOT.elf                       (git-ignored)
vfs/             your disc contents, PS3_VFS_ROOT points inside (git-ignored)
imports.json     the 107 imports, named — checked in, it is analysis not content
config.toml      module disposition (all ten are "hle")
analysis/        find_functions + extracted SPU ELFs            (git-ignored)
src/compat/      <dirent.h>/<unistd.h> Windows shims for clang-cl
src/recomp/      lifted PPU tree                                (git-ignored)
src/gen/         generated HLE NID table                        (git-ignored)
src/spu_gen/     lifted SPU images                              (git-ignored)
tools/relift.sh  regenerates every one of the above
```

Nothing derived from the game binary is committed. `tools/relift.sh`
regenerates all of it from your own dump.

## Credits & legal

Built on [ps3recomp](https://github.com/sp00nznet/ps3recomp) and its
contributors' work — in particular [@canersaka](https://github.com/canersaka)'s
live NV4097 draw engine and [@sagemono](https://github.com/sagemono)'s RSX
backend. *Virtua Fighter 5* is © Sega / AM2. This repository contains no game
code, assets, or decryption keys, and is useless without your own legally
obtained copy.
