# Virtua Fighter 5 — Static Recompilation

> Turning Sega AM2's *Virtua Fighter 5* (2007, `BLUS30020`) from a PS3 disc
> binary into a native Windows executable — no emulator underneath.

*Virtua Fighter 5* is Yu Suzuki's series at its most austere: no items, no
gimmicks, seventeen fighters and a frame-perfect combat engine that AM2 built on
the Lindbergh arcade board and brought to PS3 in early 2007. It is also an unusually clean
recompilation target — see below.

This project takes the disc's own `EBOOT.BIN`, disassembles every PowerPC
function, lifts them to C++, and links the result against
[ps3recomp](https://github.com/sp00nznet/ps3recomp) — clean-room HLE runtime
libraries that stand in for the PS3 operating system. Same approach as
[twistedmetal](https://github.com/sp00nznet/twistedmetal),
[flow](https://github.com/sp00nznet/flow) and
[simpsonsarcade-ps3](https://github.com/sp00nznet/simpsonsarcade-ps3).

**You supply your own disc.** No game binary, asset, or key is committed here.

## Why this title

Static recompilation cost is set by a title's *operating-system surface* — the
`proc_prx_param` → libstub import table — far more than by genre, binary size or
how the game looks. VF5's is unusually small:

| | |
|---|---|
| Imported functions | **107** |
| Imported modules | **10** |
| PSN / online imports | **0** |
| `cellSpurs` imports | **0** |
| exec segment | 6.3 MB |

The whole list, and every one of the ten already implemented in ps3recomp:

```
cellSysutil(23)  sysPrxForUser(22)  cellGcmSys(19)  cellAudio(11)
cellResc(11)     sys_fs(8)          cellSync(5)     sys_io(4)
cellRtc(3)       cellSysmodule(1)
```

That is the entire OS dependency. **No `sceNp`, no `sys_net`, no `cellNetCtl`**
— nothing to gate the boot on a PSN handshake. **No `cellSpurs`** — the SPURS
jobchain/task pipeline that has been the long pole on other ports is simply not
in this binary; VF5 drives its four SPU programs through raw
`sys_spu_thread_group_*` plus five `cellSync` primitives, the path ps3recomp
implements most directly.

The bet: with the live NV4097 → D3D12 engine executing titles' real vertex and
fragment programs, a title whose only real dependencies are GCM, audio, pad and
the filesystem should reach geometry with the least new runtime work — and it is
a genuine 3D game, so what it draws is a real test of the engine rather than a
UI composite.

It held. `vf5.exe` linked on the first attempt with **nothing title-specific in
the tree**: no `hle_extra.cpp`, no forked `boot_main`, no patched functions.

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
| Boot | **renders** — 0 dropped draw groups, zero failed file opens, zero unresolved imports |
| Game data install | **done** — the title's own check runs to "Check complete."; needs the one-time setup in *Building* |
| On screen | **NOW LOADING, "Presented by SEGA", CRIWARE, "Created by AM2"** — its own boot sequence, read back from the swapchain |
| Past the logos | **not reached** — renders four boot logos, then renders without presenting |
| Attract mode | **not reached** — needs CRI Sofdec video decode |

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

## What is on screen

![NOW LOADING](docs/now_loading.png)

![CRIWARE boot logo](docs/criware.png)

Both read back from the D3D12 swapchain with `LD_FRAME_DUMP` — the title's own
**NOW LOADING** screen in its own font, from the sprite and font archives it
loads, then the **CRIWARE** boot logo, animating across consecutive frames.

## Where it stops

It renders its own boot sequence -- **NOW LOADING**, **"Presented by SEGA"**,
the **CRIWARE** logo with its ADX/Sofdec sub-marks, and **"Created by AM2, AM
R&D DEPT. #2"** -- all read back from the D3D12 swapchain with `LD_FRAME_DUMP`,
so they are what the port actually drew. Then it stops, without ever reaching a
title screen.

*(The analysis that used to be here located the stop at a render gate cleared at
guest flip 782 and concluded attract mode needed CRI Sofdec. It was measured
while the title was failing 339 file opens a run and had already been told its
game data was corrupt, so it was not describing the boot a correct run takes.
Sofdec is still absent and still needed for the attract movie; it is no longer
established that Sofdec is what this stop is.)*

### The stop, precisely

The title renders its four boot logos, loads the sprite and animation archives
for its **advertise** (attract/title) sequence -- `rom/2d/spr_s_adv.farc`,
`aet_s_adv.bin` -- and then stops flipping, while still burning ~1.2 cores.

Three real bugs were found and fixed on the way here, each removing a distinct
failure. None of them is the last one.

**1. `cellGcmAddressToOffset` failed 976 times a boot.** ps3recomp auto-maps an
unmapped main-memory page on first use, but the fallback was gated on
`address < 0x40000000` -- a magic number, not a description. VF5's RSX heap
lives at 0x4A900000..0x4B400000 and it hands the RSX 0x4B400040, which fell past
the bound. With no offsets there was nothing to draw with. **976 -> 0.**

**2. Its AMGL keeps its own command buffers.** `GCM_CTXDBG=1` shows the title
repointing `gCellGcmCurrentContext` away from ours at
`begin=0x4B300000 end=0x4B37FFFC`, with its own callback, and moving it again as
each segment fills. It calls `cellGcmSetDefaultCommandBuffer` to recover;
ps3recomp only zeroed a host-side struct, so the title stayed on the exhausted
segment and asked again -- 636 times, with 91 `[AMGL]:[ERROR] Command Buffer
Overflow!`. Run with **`GCM_DEFAULT_CTX_REPOINT=1`** and that goes to **0
overflows**, with command packets reaching the draw engine up from 12,756 to
15,097 over the same five minutes.

**3. Its save load is not a blocker, and the dialog about it is a red herring.**
`cellSaveDataFixedLoad2` looks for the prefix `BLUS30020-SYSTEM`; with no save
its own funcStat puts up *"Do you want to cancel the load operation?"* from
inside the callback and returns `ERR_NODATA`. Answered YES the title accepts
that and carries on; answered NO it retries forever and reaches frame 544
instead of 3,800. So ps3recomp's default blanket YES is the right answer here,
counter-intuitive as that reads -- see `MSGDIALOG_ANSWER` upstream.

**What is left.** With all three in place the FIFO is fully drained every tick
(`getoff == put`), `ref` is never used by this title at all (`GCM_SCANREF`
reports **0** `SET_REFERENCE` commands in the whole ring), the live engine drops
nothing (`exec` equals `seen`), and the title still stops after loading its
attract assets. Holding the render gate at `0x104D320A`
(`PPU_FORCE_READ_ADDR=104D320A PPU_FORCE_READ_VAL=1`) makes it flip 23,040 times
with zero packets and black frames, so that skips the rendering state rather
than unblocking it.

The next question is what the title is waiting on between loading
`spr_s_adv.farc` and drawing it -- it is not the FIFO, not a fence, and not the
save.

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
PS3_VFS_ROOT=vfs PS3_HDD0_ROOT=$PWD/gamedata/dev_hdd0 \
    GCM_DEFAULT_CTX_REPOINT=1 RSX_LIVE_DRAW=1 ./build/vf5 game/EBOOT.elf
```

Two things in that line are easy to get wrong, and both look like a port bug
rather than a setup mistake.

**`PS3_VFS_ROOT` is `vfs`, not `vfs/PS3_GAME/USRDIR`.** The title asks for its
files by full guest path (`/dev_bdvd/PS3_GAME/USRDIR/rom/sound/snd_db.txt`) and
the VFS joins that under the root, so pointing the root at the USRDIR doubles
the path:

```
[fs] open FAIL '/dev_bdvd/PS3_GAME/USRDIR/rom/sound/snd_db.txt'
  -> 'vfs/PS3_GAME/USRDIR/PS3_GAME/USRDIR/rom/sound/snd_db.txt'
```

339 failed opens per run. This README documented the wrong root until now,
which is worth saying plainly: the earlier "134 files loaded" figure was
measured with most of the disc unreachable.

**Virtua Fighter 5 needs its game data installed, or it refuses to start.** On
a real PS3 the title copies its streamed audio and movies to the HDD on first
run, then checks that install. With nothing there it puts up its own dialog and
stops:

```
[DIALOG] Do you want to use game data? ...
[DIALOG] Game data is corrupt. To use game data...please exit the game and
         delete this game data.
```

That is the title behaving correctly on a machine where the install never
happened, not a recompilation failure. Emulate the install once:

```powershell
New-Item -ItemType Directory -Force gamedata\dev_hdd0\game\BLUS30020
Copy-Item vfs\PS3_GAME\PARAM.SFO gamedata\dev_hdd0\game\BLUS30020\
Copy-Item vfs\PS3_GAME\ICON0.PNG gamedata\dev_hdd0\game\BLUS30020\
New-Item -ItemType Junction -Path gamedata\dev_hdd0\game\BLUS30020\USRDIR `
         -Target (Resolve-Path vfs\PS3_GAME\USRDIR)
```

**Save data.** The title loads a system save at boot and looks for the prefix
`BLUS30020-SYSTEM` under `gamedata/dev_hdd0/home/00000001/savedata`. A load of
an absent save legitimately reports no data and the boot carries on, so creating
it is optional -- but an *empty* directory of that name is not a save, and
ps3recomp now says so (isNewData keys on PARAM.SFO). Before that fix an empty
one made the title's stat callback report its save BROKEN.

A junction rather than a copy: the installed USRDIR *is* the disc's USRDIR, so
there is no reason to spend the disk space. With that in place the title runs
its real check through to `[DIALOG] Check complete.`, opens every file it asks
for -- **zero** failed opens -- and boots on through its logo sequence.

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
tools/           relift.sh regenerates every one of the above, plus
                 merge_split_loops.py and a screenshot helper
docs/            the working log, the diagnostics list, and two frame captures
```

Nothing derived from the game binary is committed. `tools/relift.sh`
regenerates all of it from your own dump.

## Credits & legal

MIT licensed — see [LICENSE](LICENSE).

Built on [ps3recomp](https://github.com/sp00nznet/ps3recomp) and its
contributors' work — in particular [@canersaka](https://github.com/canersaka)'s
live NV4097 draw engine and [@sagemono](https://github.com/sagemono)'s RSX
backend. *Virtua Fighter 5* is © Sega / AM2. This repository contains no game
code, assets, or decryption keys, and is useless without your own legally
obtained copy.
