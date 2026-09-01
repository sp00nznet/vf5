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
| Boot | **runs, zero unresolved imports** — clears and flips; no geometry yet, see below |

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

### What is still in the way

`packets[seen=0] groups[seen=0]` — not one draw. Rendering stops **1.6% into the
run** and after that the log is nothing but the title's own
`[AMGL]:[ERROR] Command Buffer Overflow!` and `cellGcmAddressToOffset failed`
for addresses walking off the end of its own 4 MB mapping.

What the FIFO evidence actually says, after several wrong turns:

* `_cellGcmInitBody` puts the default command buffer at IO `0..0x6FF000`; the
  title maps a second 4 MB at 0x4AB00000 → IO `0x700000..0xB00000` and every
  `put` it writes is `0xA00000 + n`.
* Its early commands (the 819 clears) *are* in the default buffer at IO 0, so
  `get` starting at 0 is right — starting it at the title's own ring instead was
  tried and is strictly worse (clears 819 → 12, overflows 40k → 193k). Reverted.
* The walker does cross the ~10 MB gap (4 MB/tick) and does reach `put`. So
  `get` catching `put` is not the missing piece either.
* No `[JMP]`, no `[SEMA]`, no `SET_OBJECT` is ever decoded on the title's
  stream, and `ctrl->ref` stays `0` for the entire run.

So AMGL's free-space accounting is reading something we never write. It is not
`cellGcmGetReport` (the title never calls it — with zero unresolved NIDs left,
that is now provable rather than assumed). The remaining candidate it *does*
import is `cellGcmGetLabelAddress`: a label AMGL writes from the FIFO and polls
from the PPU. Nothing in the run releases a semaphore into the label window,
which would leave that poll reading its initial value forever. That is the next
thread to pull.

### What the SPU interpreter ruled out

`RD_SPU_INTERP=1` runs the `CriSr` thread today without wiring the raw
thread-group path into the fingerprint registry. Re-measured *after* the dialog
fix (the first measurement was taken at a stall the title had not yet reached,
and was worthless): synchronously it is worse than useless — CriSr is a
persistent service loop, so `group_start` never returns and the boot stops after
one file instead of twenty. Asynchronously it is a wash, identical to baseline
on every counter. The dormant SPU thread is a real gap; it is not this one.

### Diagnostics added while chasing this

Both in `ps3recomp/libs/video/cellGcmSys.c`, both off by default:

* `GCM_FIFO_SNAP=N` — dumps the raw words at *both* ends of the ring, what
  `get` is about to decode and what the title just wrote at `put`.
* `GCM_DRAINDBG=1` now also prints `[DRAINEND] <reason>` — why each pass
  stopped and how far it got, with every break site in the walk tagged.

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
