"""merge_split_loops.py -- drop function starts that a loop branches across.

find_functions can plant a boundary in the middle of a function. The lifted
result is two C functions where the second continues the first's loop: it reads
loop-carried registers that were never set and frame slots from a frame that was
never allocated. Virtua Fighter 5 loses an OPD table that way -- func_00050DB4
is split at 0x51600, and the half after the split runs a `bdnz 0x515C4` back
into the half before it, with `ld r20, 0x1F8(r1)` reading a stranger's stack.

A boundary is provably wrong when a CONDITIONAL branch or `bdnz` inside the
candidate targets an address strictly inside the body of the immediately
preceding, adjacent function: a loop cannot span a real function boundary.
Unconditional `b` is excluded (a backward `b` is an ordinary tail call), as is
a branch to the previous function's entry (also a tail call) -- allowing either
cascades, absorbing every tail-calling sibling into one giant function.

    python tools/merge_split_loops.py analysis/functions.json
"""
import json, struct, sys

def load_text(path):
    d = open(path, 'rb').read()
    phoff = struct.unpack('>Q', d[0x20:0x28])[0]
    phnum = struct.unpack('>H', d[0x38:0x3A])[0]
    for i in range(phnum):
        o = phoff + i * 0x38
        t, fl = struct.unpack('>II', d[o:o+8])
        off, va = struct.unpack('>QQ', d[o+8:o+24])
        fsz = struct.unpack('>Q', d[o+32:o+40])[0]
        if t == 1 and (fl & 1):
            return d[off:off+fsz], va
    raise SystemExit('no executable PT_LOAD')

def main():
    fj = sys.argv[1] if len(sys.argv) > 1 else 'analysis/functions.json'
    elf = sys.argv[2] if len(sys.argv) > 2 else 'game/EBOOT.elf'
    text, base = load_text(elf)
    ents = sorted((int(x['start'], 16), int(x['end'], 16)) for x in json.load(open(fj)))

    total = 0
    while True:
        drop = set()
        for i in range(1, len(ents)):
            p0, p1 = ents[i-1]
            st, en = ents[i]
            if p1 != st:
                continue
            for va in range(st, min(en, base + len(text)), 4):
                w = struct.unpack('>I', text[va-base:va-base+4])[0]
                op = w >> 26
                # Conditional branches and bdnz only. An unconditional `b`
                # backwards is an ordinary tail call, and one to the previous
                # function's ENTRY is a tail call too -- neither says the two
                # halves are one function. Only a loop back INTO the previous
                # function's body does.
                if (w & 2) or op != 16:
                    continue
                li = w & 0xFFFC
                if li & 0x8000: li -= 0x10000
                if p0 < va + li < st:
                    print('merge %08X + %08X..%08X  (%08X -> %08X)' % (p0, st, en, va, va + li))
                    drop.add(st)
                    break
        if not drop:
            break
        total += len(drop)
        out = []
        for st, en in ents:
            if st in drop and out:
                out[-1] = (out[-1][0], en)       # absorb into the previous function
            else:
                out.append((st, en))
        ents = out

    json.dump([{'start': '0x%08X' % s, 'end': '0x%08X' % e} for s, e in ents], open(fj, 'w'))
    print('merged %d bogus start(s); %d functions remain' % (total, len(ents)))

if __name__ == '__main__':
    main()
