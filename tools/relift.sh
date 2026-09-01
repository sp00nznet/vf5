#!/bin/sh
# Regenerate everything git-ignored: the lifted PPU tree, the HLE NID table,
# and the lifted SPU images. Run from the repo root.
set -e
PS3RECOMP="${PS3RECOMP:-../ps3recomp}"

mkdir -p analysis

# ---- PPU -------------------------------------------------------------------
python "$PS3RECOMP/tools/find_functions.py" game/EBOOT.elf \
    --output analysis/functions.json

# --code-end 0x5CC830 is the end of the last SHF_EXECINSTR section, which is
# also the section holding the .lib.stub import trampolines (0x5CBAD0..0x5CC810
# -- they must stay INSIDE the bound or --hle-stubs has nothing to rewrite).
# Past it is .rodata; without the bound the branch-target pass explodes data
# into bogus functions (this is what cost flOw and YDKJ multi-GB lifts).
#
# --hle-stubs rewrites each import trampoline as ps3_hle_call(nid) so a direct
# `bl` to an import dispatches to the HLE handler instead of running the literal
# stub, whose pointer table the recomp never fills.
rm -rf src/recomp && mkdir -p src/recomp src/gen
python "$PS3RECOMP/tools/ppu_lifter.py" game/EBOOT.elf \
    --functions analysis/functions.json \
    --hle-stubs imports.json \
    --code-end 0x5CC830 \
    -o src/recomp

python "$PS3RECOMP/tools/gen_hle_nids.py" --all --out src/gen/ppu_hle_nids.cpp

# ---- SPU -------------------------------------------------------------------
# Unlike Simpsons Arcade, VF5's SPU programs are proper SPU ELFs embedded in the
# EBOOT's data, so the static extractor finds all four -- no SPU_DUMP_MISS
# capture needed. build_spu_workloads.py lifts each under its own symbol prefix
# and emits the FNV-1a-64 fingerprint registry cellSpurs/raw-SPU dispatch looks
# titles up in.
python "$PS3RECOMP/tools/extract_spu_images.py" game/EBOOT.elf \
    --output analysis/spu_images
python "$PS3RECOMP/tools/build_spu_workloads.py" \
    --images analysis/spu_images \
    --lifted src/spu_gen \
    --out src/spu_workloads.c \
    --register-fn vf5_spu_register_all --constructor --title vf5
