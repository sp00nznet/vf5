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
| Boot | **reaches the render loop, clears the screen** — no geometry yet, see below |

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

### Where it stopped, and what moved it

**1. `sys_spinlock_*` was unimplemented — fixed.** `0x8C2BB498` / `0x722A0254` /
`0x5267CB35` were the only unresolved NIDs in the whole boot (40 calls) and were
unnamed in ps3recomp's database. Brute-forcing `compute_nid()` over the
`sysPrxForUser` export list identified them as `sys_spinlock_initialize` /
`_trylock` / `_unlock`. Implemented in `ppu_sysprx.cpp` as a test-and-set on the
guest word (which is all a `sys_spinlock_t` is), all four registered including
`sys_spinlock_lock`, and the names added to `nid_database.py`. Unresolved NIDs
for the family: **40 -> 0**.

**2. The title's own graphics layer prints `[AMGL]:[ERROR] Command Buffer
Overflow!`** — that string is *the game's*, not ours. This is the live frontier.
What the FIFO trace says:

```
[DRAIN] getoff=0042F168 put=00AE8A84 ref=00000000 ctx.current=4A400418
```

* `_cellGcmInitBody` puts the default command buffer at IO `0..0x6FF000`
  (`ioAddr` 0x4A400000). The title then `cellGcmMapMainMemory`s a second 4 MB at
  0x4AB00000, which lands at IO `0x700000..0xB00000`, and drives the RSX from
  the *last* megabyte of it — every `put` it writes is `0xA00000 + n`.
* `get` meanwhile circulates inside the default ring at IO 0, following JUMPs
  libgcm parked there. It burns its entire million-word budget without arriving.
  Twisted Metal and flOw both write one ring whose JUMPs lead to `put`; VF5 does
  not, and nothing in the walker noticed — the existing stuck-detector only
  fires when `get` stops *moving*, and a walker going in circles moves plenty.
* Because `get` never advances into the title's ring, the ring is never
  reclaimed, AMGL's buffer-full callback can never free space, and `put` runs
  off the end of its own mapping — which is the `cellGcmAddressToOffset failed
  for 0x4AF000B0` flood (0x4AF00000 is exactly one past the 4 MB).

Two rules added to the shared FIFO walker, both no-ops for a title that keeps
up: stop honouring one-flip-per-drain once the backlog exceeds 64 KB, and treat
a full-budget burn on several consecutive passes as "circling" and follow the
write head (`GCM_FIFO_CIRCLE_PASSES`, default 4). Measured effect:

| | before | after |
|---|---|---|
| `Command Buffer Overflow` in 45 s | 78,601 | 40,297 |
| `AddressToOffset failed` | thousands | 91 |
| guest clears reaching the engine | 342 | 819 |

Real movement, not a fix. **`packets[seen=0] groups[seen=0]` — still not one
draw**, no `SET_OBJECT` is ever decoded, and `ctrl->ref` stays `0x00000000` for
the entire run, which is the tell: if AMGL sizes its free space off the
reference value, nothing we do to `get` alone will ever unblock it. The walker
is still not on the title's real command stream.

The honest next step is not another walker heuristic. It is modelling which
buffer the RSX is actually bound to — the title calls `cellGcmSetQueueHandler`
(`0x006A8038`) and `cellGcmSetDefaultCommandBuffer`, and our implementation of
the latter zeroes a *host* struct and ignores the switch entirely.

**3. The SPU thread group never runs — and this is very likely the real
blocker, ahead of (2).** The group is named in the log:

```
[SPU] group_create -> id=0x1000 num=1 prio=100 type=0x0 name=CriSr thread group
[HLE] _sys_spu_image_import(img=0x401440F8 src=0x100BFB80) -> entry=0x00090 nsegs=3
[SPU] thread_init group=0x1000 index=0 img=0x401440F8 -> tid=0x2000 entry=0x00000090
[SPU] group_start id=0x1000 (1 thread(s), none spawned: 0 ran synchronously,
                             1 had no fallback)
```

`CriSr` is CRI middleware — the same family that turned out to be the whole
story for Simpsons Arcade. `src=0x100BFB80` is an SPU ELF embedded in the
EBOOT's last PT_LOAD, and it is **one of the four images `relift.sh` already
extracts, lifts and registers**. It still reports "no fallback".

The cause is two registries where only one is consulted. `build_spu_workloads.py`
registers each lifted image by FNV-1a-64 content fingerprint
(`spu_workload_register_img`), which is what the SPURS path looks up. The raw
`sys_spu_thread_group_start` path in `runtime/syscalls/lv2_register.c` only ever
calls `spu_lookup_ppu_fallback(entry_point)` — a different table, keyed by entry
point — so a title that starts a plain SPU thread group gets "no fallback" even
with its image lifted and registered. VF5 uses the raw path exclusively (it
imports no `cellSpurs` at all), so **none of its SPU code has ever executed.**

Wiring the raw path to fall back to the fingerprint registry is the next change.
It is not a one-liner: the run needs the image's indirect-branch table id
(`spu_begin_image`) so branches resolve in the right image, and a raw SPU thread
is entered with four 64-bit args rather than the SPURS task ABI
`spu_lifted_fallback` assumes. Both are knowable; neither is guesswork worth
shipping unverified.

**Also fixed on the way, though VF5 has not reached it yet:** `cellResc` was a
pure state-tracking stub — `cellRescSetConvertAndFlip` incremented a counter and
returned `CELL_OK` without flipping anything, and both handler setters stored a
guest OPD in a *host* function pointer and called it directly, which is a crash
waiting for the first title that sets one. VF5 presents entirely through RESC
(11 imports: `SetSrc`, `SetDsts`, `SetConvertAndFlip`, `SetFlipHandler`,
`GcmSurface2RescSrc`), so this had to be real. It now issues a real
`cellGcmSetFlipCommand`, rotating through the display buffers the title
registered, and invokes handlers through `ps3_invoke_guest`. The log confirms
`cellRescInit` is never reached yet — the title is still stuck behind (3).

### Diagnostics added while chasing this

Both in `ps3recomp/libs/video/cellGcmSys.c`, both off by default:

* `GCM_FIFO_SNAP=N` — dumps the raw words at *both* ends of the ring, what
  `get` is about to decode and what the title just wrote at `put`. This is what
  showed the two ends were in different buffers.
* `GCM_DRAINDBG=1` now also prints `[DRAINEND] <reason>` — why each pass
  stopped and how far it got. Every break site is tagged. A pass that ends far
  short of `put` every tick is the signature of a FIFO that can never catch up,
  and the reason is the whole diagnosis.

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
