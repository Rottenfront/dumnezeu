# RISC-V RV64 integer and floating-point reference

A practical, human-readable summary for learning the architecture or implementing
an initial compiler backend. Checked against the official specifications and
opcode definitions on 2026-10-31; links are in [Sources](#sources).

## 1. Scope: 64-bit data does not mean 64-bit instructions

**RV64 means that the integer register width, XLEN, is 64 bits. The instructions
covered here are encoded in 32 bits, not 64 bits.** Inventing a 64-bit instruction
layout for these operations would produce incorrect machine code.

This document includes both the real 32-bit instruction layouts and the 64-bit
integer/floating-point data layouts.

| Component | What it provides |
| --- | --- |
| RV64I | Base integer arithmetic, bit operations, loads/stores, branches, calls, and environment instructions. |
| F | IEEE 754 binary32, usually called `float` or `f32`. Adds 32 floating-point registers. Requires Zicsr. |
| D | IEEE 754 binary64, usually called `double` or `f64`. Requires F and widens the floating-point registers to 64 bits. |
| Zicsr | Instructions for accessing control/status registers, including floating-point rounding and exception state. |
| M, optional appendix | Integer multiplication, division, and remainder. These are **not** part of RV64I. |

A corresponding ISA string is `rv64ifd_zicsr`, or `rv64imfd_zicsr` when using M.
The common `rv64gc` target includes additional extensions: `G` abbreviates
I, M, A, F, D, Zicsr, and Zifencei; `C` adds compressed instructions.
This reference does not cover atomics, compressed encodings, vectors, bit-manipulation
extensions, half/quad precision, privileged instructions, or extension-specific
HINT catalogs. `FENCE.I` belongs to Zifencei, not the current RV64I base.

## 2. Machine model and 64-bit layouts

### Integer registers

There are 32 integer registers, `x0` through `x31`, each 64 bits wide.
`x0` always reads as zero; writes to it are discarded. `pc` is a separate
64-bit program counter. General-purpose registers are untyped bit patterns:
the instruction determines whether to interpret them as signed or unsigned.

```text
64-bit integer / register / ordinary LP64 pointer
 63                                                            0
+---------------------------------------------------------------+
|                         value[63:0]                           |
+---------------------------------------------------------------+

Signed interpretation: two's complement, range -2^63 .. 2^63-1.
Unsigned interpretation:                    0 .. 2^64-1.
Pointers: 64 bits in the LP64 ABI; not every bit pattern is a valid address.
```

Sign extension copies the source sign bit; zero extension fills with zeros:

```text
                          bits 63:32                 bits 31:0
LW / ADDW / other *W:      32 copies of bit 31         32-bit result
LWU:                      00000000...00000000         32-bit memory value

Example source 0x80000001:
  sign-extended:           0xffffffff80000001
  zero-extended:           0x0000000080000001
```

Integer addition/subtraction wrap modulo `2^64`; they do not trap on overflow
or update condition flags. The `*W` operations instead keep a 32-bit result
and **sign-extend it to 64 bits**, even when the operation is logically unsigned.

### Floating-point registers and IEEE 754

F adds `f0` through `f31`; unlike `x0`, **`f0` is an ordinary writable register**.
F alone has FLEN=32 even on RV64. With D, FLEN=64 and each `f` register can
contain a binary64 value or a NaN-boxed binary32 value.

```text
IEEE 754 binary64 in a 64-bit f register (D)
 63 62                  52 51                                  0
+--+----------------------+-------------------------------------+
| s| exponent: 11 bits    | fraction: 52 bits                   |
+--+----------------------+-------------------------------------+

Normal value = (-1)^s * (1 + fraction / 2^52) * 2^(exponent - 1023).

NaN-boxed IEEE 754 binary32 in a 64-bit f register (F + D)
 63                    32 31 30           23 22                 0
+------------------------+--+---------------+-------------------+
| all ones: 0xffffffff   | s| exponent: 8   | fraction: 23      |
+------------------------+--+---------------+-------------------+

Normal binary32 value = (-1)^s * (1 + fraction / 2^23)
                       * 2^(exponent - 127).
```

For either format:

- Exponent zero and fraction zero: signed zero.
- Exponent zero and nonzero fraction: subnormal; use exponent `1 - bias`
  and no implicit leading `1`.
- All-one exponent and zero fraction: signed infinity.
- All-one exponent and nonzero fraction: NaN (not a number).
- The top fraction bit distinguishes quiet NaNs (`1`) from signaling NaNs (`0`).
- Canonical NaNs are `0x7fc00000` for binary32 and
  `0x7ff8000000000000` for binary64.

Example: binary64 `1.0` is `0x3ff0000000000000`; binary32 `1.0` is
`0x3f800000`, held as `0xffffffff3f800000` in a D-capable register.
NaN-boxing is **not a numeric conversion to double**. Use `FCVT.D.S` for that.
Narrow arithmetic operands with invalid boxing are treated as canonical NaNs;
narrow transfers out (`FSW`, `FMV.X.W`) simply take the low 32 bits.

### Register names and calls: ABI, not instruction-set rules

These are the standard LP64/LP64D application binary interface (ABI) conventions.
`rd`, `rs1`, and `rs2` in encodings are 5-bit register numbers; an integer `x10`
and floating-point `f10` use the same number but refer to different register files.

| Integer registers | ABI name | Typical role |
| --- | --- | --- |
| `x0` | `zero` | Constant zero. |
| `x1` | `ra` | Return address; caller-saved. |
| `x2` | `sp` | Stack pointer; preserved by callee. |
| `x3`, `x4` | `gp`, `tp` | Global/thread pointer; do not allocate as ordinary temporaries. |
| `x5`–`x7`, `x28`–`x31` | `t0`–`t6` | Caller-saved temporaries. |
| `x8`, `x9`, `x18`–`x27` | `s0`–`s11` | Callee-saved; `s0` can also be `fp`. |
| `x10`–`x17` | `a0`–`a7` | Integer arguments; `a0`/`a1` also carry results. |

| Floating-point registers | ABI name | LP64D role |
| --- | --- | --- |
| `f0`–`f7`, `f28`–`f31` | `ft0`–`ft11` | Caller-saved temporaries. |
| `f8`, `f9`, `f18`–`f27` | `fs0`–`fs11` | Callee-saved for values up to the ABI floating-point width. |
| `f10`–`f17` | `fa0`–`fa7` | Floating-point arguments; `fa0`/`fa1` also carry results. |

The standard stack grows downward and `sp` stays aligned to 16 bytes. A function
that calls another function must preserve its own return address if still needed.
LP64D passes eligible floating-point arguments/results in `fa` registers;
soft-float LP64 uses the integer calling convention even on F/D hardware.
ISA extensions and calling convention are separate choices.

## 3. Actual instruction bit layouts: 32 bits

Bit 31 is the most significant bit of an instruction word. `rd` is the destination;
`rs1`, `rs2`, `rs3` are sources. `funct3`/`funct7` further select the operation.
Field widths are shown explicitly below. All binary constants in the tables
are literal bit fields; hexadecimal constants start with `0x`.

```text
R-type: register/register arithmetic
 31:25       24:20    19:15    14:12      11:7     6:0
+-----------+--------+--------+----------+--------+---------+
| funct7(7) | rs2(5) | rs1(5) | funct3(3)| rd(5)  |opcode(7)|
+-----------+--------+--------+----------+--------+---------+

I-type: immediates, loads, JALR
 31:20               19:15    14:12      11:7     6:0
+-------------------+--------+----------+--------+---------+
| imm[11:0](12)     | rs1(5) | funct3(3)| rd(5)  |opcode(7)|
+-------------------+--------+----------+--------+---------+

S-type: stores
 31:25       24:20    19:15    14:12      11:7       6:0
+-----------+--------+--------+----------+----------+---------+
|imm[11:5]  | rs2(5) | rs1(5) | funct3(3)|imm[4:0]  |opcode(7)|
+-----------+--------+--------+----------+----------+---------+
     7                                      5

B-type: conditional branches
 31      30:25     24:20  19:15  14:12    11:8     7       6:0
+-------+---------+------+------+--------+--------+-------+---------+
|imm[12]|imm[10:5]|rs2(5)|rs1(5)|funct3  |imm[4:1]|imm[11]|opcode(7)|
+-------+---------+------+------+--------+--------+-------+---------+
    1       6                      3        4       1

U-type: upper immediate
 31:12                                  11:7     6:0
+--------------------------------------+--------+---------+
| imm[31:12](20)                       | rd(5)  |opcode(7)|
+--------------------------------------+--------+---------+

J-type: JAL
 31      30:21       20      19:12       11:7     6:0
+-------+-----------+-------+-----------+--------+---------+
|imm[20]|imm[10:1]  |imm[11]|imm[19:12] | rd(5)  |opcode(7)|
+-------+-----------+-------+-----------+--------+---------+
    1       10          1        8

R4-type: floating-point fused multiply-add
 31:27    26:25   24:20   19:15   14:12   11:7    6:0
+--------+-------+-------+-------+-------+-------+---------+
| rs3(5) |fmt(2) |rs2(5) |rs1(5) | rm(3) | rd(5)|opcode(7)|
+--------+-------+-------+-------+-------+-------+---------+
```

Ordinary OP-FP instructions use the R-type layout, with rounding mode `rm` in
bits `14:12` **only when the instruction calls for rounding**. For comparisons,
sign injection, classification, etc., those bits are an operation selector.

### Reconstructing immediates

`inst[h:l]` means the inclusive bit slice; `||` means concatenation;
`sext64` sign-extends to 64 bits. These are bit operations, not assembler syntax.

```text
I = sext64(inst[31:20])
S = sext64(inst[31:25] || inst[11:7])
B = sext64(inst[31] || inst[7] || inst[30:25] || inst[11:8] || 0)
U = sext64(inst[31:12] || 000000000000)
J = sext64(inst[31] || inst[19:12] || inst[20] || inst[30:21] || 0)
```

- I/S byte offsets: `-2048 .. 2047`.
- B byte offsets: `-4096 .. 4094`, multiples of 2, relative to the branch's `pc`.
- J byte offsets: `-1048576 .. 1048574`, multiples of 2, relative to the jump's `pc`.
- U creates a **32-bit signed** quantity with 12 trailing zeros, then sign-extends.
- Shift immediates and CSR addresses/immediates have special interpretations;
  do not apply ordinary I-type signed-immediate arithmetic to them.

Without C or another extension relaxing alignment, instruction addresses must
be multiples of 4. A taken branch/jump to a merely 2-byte-aligned address traps,
even though B/J offsets can encode it. These instructions have low bits `11`;
their major opcodes below identify the 32-bit encodings in this subset.

For the usual little-endian target, word `0x00c58533` is stored as bytes
`33 85 c5 00`, at increasing addresses. Instruction parcels are little-endian;
data-memory endianness is an execution-environment choice. The examples assume
little-endian data as well. Neither bit numbering nor register width changes
with byte order.

## 4. RV64I integer instruction reference

Notation: `x[rs1]` is an integer register's value, `M8/16/32/64[address]` a
memory access of that width, `lo32` the low 32 bits, and `sext32` sign-extension
of a 32-bit value to 64 bits. Arithmetic results are truncated to the stated width.
Operands appear in assembly order: destination, source(s).

### Register/register arithmetic

R-type, opcode `0110011` (`0x33`); syntax `instruction rd, rs1, rs2`.
`u64` and `s64` below mean unsigned and signed interpretations.

| Instruction | funct3 | funct7 | Meaning |
| --- | --- | --- | --- |
| `add` | `000` | `0000000` | `rd = rs1 + rs2`. |
| `sub` | `000` | `0100000` | `rd = rs1 - rs2`. |
| `sll` | `001` | `0000000` | Shift left by `rs2[5:0]`; shift in zeros. |
| `slt` | `010` | `0000000` | `rd = 1` if `s64(rs1) < s64(rs2)`, otherwise `0`. |
| `sltu` | `011` | `0000000` | Same, comparing unsigned values. |
| `xor` | `100` | `0000000` | Bitwise XOR. |
| `srl` | `101` | `0000000` | Shift right by `rs2[5:0]`; shift in zeros. |
| `sra` | `101` | `0100000` | Shift right by `rs2[5:0]`; copy sign bit into high bits. |
| `or` | `110` | `0000000` | Bitwise OR. |
| `and` | `111` | `0000000` | Bitwise AND. |

There is no separate signed/unsigned addition instruction: the low 64 result
bits are identical. Signedness matters for comparisons and right shifts.
Register shifts mask their counts to six bits; they do not reject counts >=64.

### Register/immediate arithmetic

I-type, opcode `0010011` (`0x13`); syntax `instruction rd, rs1, imm`.
Here `imm` is a **sign-extended 12-bit immediate**, including for `SLTIU`
and the logical operations.

| Instruction | funct3 | Meaning |
| --- | --- | --- |
| `addi` | `000` | Add signed immediate. |
| `slti` | `010` | Set `rd` to `1` if signed `rs1 < imm`, else `0`. |
| `sltiu` | `011` | Compare unsigned `rs1` with the **sign-extended** immediate interpreted as unsigned. |
| `xori` | `100` | Bitwise XOR with sign-extended immediate. |
| `ori` | `110` | Bitwise OR with sign-extended immediate. |
| `andi` | `111` | Bitwise AND with sign-extended immediate. |

The shift-immediate variants use the same opcode but split bits `31:20`:

```text
bits 31:26   bits 25:20   bits 19:15   bits 14:12   bits 11:7   bits 6:0
fixed(6)     shamt(6)     rs1(5)       funct3(3)    rd(5)       0010011
```

| Instruction | funct3 | Fixed bits 31:26 | Meaning |
| --- | --- | --- | --- |
| `slli` | `001` | `000000` | Logical left shift by `0 .. 63`. |
| `srli` | `101` | `000000` | Logical right shift by `0 .. 63`. |
| `srai` | `101` | `010000` | Arithmetic right shift by `0 .. 63`. |

### Operations on 32-bit words in 64-bit registers

All these operations write `sext32(result)`, not a zero-extended result.
For register shifts the count is `rs2[4:0]`.

R-type, opcode `0111011` (`0x3b`); syntax `instruction rd, rs1, rs2`:

| Instruction | funct3 | funct7 | Meaning |
| --- | --- | --- | --- |
| `addw` | `000` | `0000000` | Add low 32 bits, then sign-extend low 32 result bits. |
| `subw` | `000` | `0100000` | Subtract low 32 bits, then sign-extend. |
| `sllw` | `001` | `0000000` | Shift low 32-bit value left, then sign-extend. |
| `srlw` | `101` | `0000000` | Logical right shift of low 32 bits, then sign-extend. |
| `sraw` | `101` | `0100000` | Arithmetic right shift of low 32 bits, then sign-extend. |

I-type, opcode `0011011` (`0x1b`):

| Instruction | funct3 | Bits 31:25 | Meaning |
| --- | --- | --- | --- |
| `addiw` | `000` | Part of signed `imm[11:0]` | `rd = sext32(lo32(rs1 + imm))`. |
| `slliw` | `001` | `0000000` | Low-word left shift by `shamt[4:0]`, then sign-extend. |
| `srliw` | `101` | `0000000` | Low-word logical right shift, then sign-extend. |
| `sraiw` | `101` | `0100000` | Low-word arithmetic right shift, then sign-extend. |

For the word-immediate shifts, bits `24:20` encode a count `0 .. 31`.
Encodings with bit 25 set are reserved. `ADDIW rd, rs1, 0` sign-extends
`rs1[31:0]`, often spelled `sext.w rd, rs1`.

### Constants and PC-relative addresses

U-type; syntax `instruction rd, imm20`. Assembly supplies the 20-bit field,
not an already-shifted 32-bit number.

| Instruction | Opcode | Meaning |
| --- | --- | --- |
| `lui` | `0110111` (`0x37`) | `rd = sext32(imm20 << 12)`. |
| `auipc` | `0010111` (`0x17`) | `rd = pc + sext32(imm20 << 12)`. |

`LUI` is not an arbitrary unsigned 32-bit constant load on RV64:
`lui t0, 0x80000` produces `0xffffffff80000000`.
Use the assembler's `li` for arbitrary 64-bit constants; it may expand to
several instructions. Address-producing `la`/`lla` and `call` also require
assembler/linker relocations rather than merely concatenating fields.

### Loads and stores: integers, pointers, arrays, and structures

The address is always `x[rs1] + sign_extend(offset12)`, measured in **bytes**.
There is no automatic indexing, scaling, bounds checking, or pointer type.

Loads use I-type, opcode `0000011` (`0x03`), syntax `instruction rd, offset(rs1)`:

| Instruction | funct3 | Meaning |
| --- | --- | --- |
| `lb` | `000` | Load 8 bits and sign-extend to 64. |
| `lh` | `001` | Load 16 bits and sign-extend to 64. |
| `lw` | `010` | Load 32 bits and sign-extend to 64. |
| `ld` | `011` | Load all 64 bits. Also used to load an LP64 pointer. |
| `lbu` | `100` | Load 8 bits and zero-extend. |
| `lhu` | `101` | Load 16 bits and zero-extend. |
| `lwu` | `110` | Load 32 bits and zero-extend. |

Stores use S-type, opcode `0100011` (`0x23`), syntax `instruction rs2, offset(rs1)`:

| Instruction | funct3 | Meaning |
| --- | --- | --- |
| `sb` | `000` | Store low 8 bits of `rs2`. |
| `sh` | `001` | Store low 16 bits. |
| `sw` | `010` | Store low 32 bits. |
| `sd` | `011` | Store all 64 bits; also used for LP64 pointers. |

Use naturally aligned addresses: multiples of 2/4/8 for 16/32/64-bit accesses.
Misaligned accesses may trap or be emulated and are not generally guaranteed
atomic. Even a load into `x0` can fault and has normal memory side effects.
An array address or struct-field address is calculated explicitly; type size,
field offsets, padding, and bounds checks are the compiler's responsibility.

### Branches, jumps, calls, and returns

Branches use B-type, opcode `1100011` (`0x63`), syntax
`instruction rs1, rs2, label`. If true, `pc = old_pc + B`; otherwise `pc += 4`.
No condition-code register or separate comparison instruction is needed.

| Instruction | funct3 | Branch when |
| --- | --- | --- |
| `beq` | `000` | Values are equal. |
| `bne` | `001` | Values are not equal. |
| `blt` | `100` | Signed `rs1 < rs2`. |
| `bge` | `101` | Signed `rs1 >= rs2`. |
| `bltu` | `110` | Unsigned `rs1 < rs2`. |
| `bgeu` | `111` | Unsigned `rs1 >= rs2`. |

| Instruction | Format / opcode | Meaning |
| --- | --- | --- |
| `jal rd, label` | J / `1101111` (`0x6f`) | `rd = old_pc + 4`; jump to `old_pc + J`. |
| `jalr rd, offset(rs1)` | I / `1100111` (`0x67`), funct3=`000` | Calculate target from old `rs1 + I`, clear target bit 0, save `old_pc + 4` in `rd`, then jump. |

`jal ra, function` calls a nearby function. `jal x0, label` is an unconditional
jump. `jalr x0, 0(ra)` returns. There are no branch delay slots.
The JALR offset is an ordinary byte offset, **not** scaled by two; clearing bit 0
does not guarantee 4-byte alignment.

### Memory ordering and environment instructions

`fence pred, succ` orders selected preceding memory/I/O accesses before selected
following accesses. It is not a lock, atomic read-modify-write, or instruction-cache
flush. `pred` and `succ` are four-bit masks in order `I O R W`:
input=`1000`, output=`0100`, memory read=`0010`, memory write=`0001`.

```text
FENCE, opcode 0001111 (0x0f), funct3=000
31:28    27:24    23:20    19:15   14:12   11:7    6:0
fm(4)    pred(4)  succ(4)  00000   000     00000   0001111
```

Normal FENCE uses `fm=0000`; `fence rw, rw` uses `pred=succ=0011`.
`fence.tso` uses `fm=1000`, `pred=succ=0011`; it omits store-to-load ordering
and may conservatively be implemented as `fence rw, rw`.
Software must zero `rs1`/`rd`. `FENCE.I` is a separate Zifencei instruction.

| Instruction | Full 32-bit word | Meaning |
| --- | --- | --- |
| `ecall` | `0x00000073` | Trap to request an execution-environment service. Service numbers/arguments are an OS/runtime ABI, not specified by RV64I. |
| `ebreak` | `0x00100073` | Breakpoint trap for debugging. |

## 5. F and D floating-point instructions

In this section, `p` means precision `s` (binary32, F) or `d` (binary64, D).
Floating-point arithmetic reads/writes `f` registers. Integer addresses,
comparison results, and integer conversions use `x` registers instead.
There are no immediate floating-point arithmetic operands or floating-point
conditional branches in F/D.

### Loads and stores

These have the same I/S layouts and signed 12-bit byte offsets as integer loads
and stores; the base `rs1` is an **integer** register.

| Instruction | Format | Opcode | funct3 | Meaning |
| --- | --- | --- | --- | --- |
| `flw fd, offset(rs1)` | I | `0000111` (`0x07`) | `010` | Load 32 bits into `fd`; NaN-box when FLEN=64. |
| `fld fd, offset(rs1)` | I | `0000111` (`0x07`) | `011` | Load 64 bits into `fd`. |
| `fsw fs2, offset(rs1)` | S | `0100111` (`0x27`) | `010` | Store low 32 bits from `fs2`. |
| `fsd fs2, offset(rs1)` | S | `0100111` (`0x27`) | `011` | Store 64 bits from `fs2`. |

Transfers preserve the payload bits, including noncanonical NaNs.
`FLW/FSW` are guaranteed atomic when naturally aligned; `FLD/FSD` when naturally
aligned and XLEN >=64. Do not rely on misaligned access support.

### Arithmetic and square root

R-type OP-FP, opcode `1010011` (`0x53`). Bits `14:12` hold `rm`.
Syntax: `instruction fd, fs1, fs2, rm`, or `fsqrt.p fd, fs1, rm`.
Here and below, `fd`/`fs1`/`fs2` specify the usual `rd`/`rs1`/`rs2` bit fields.

| Instruction, F / D | funct7, F / D | Meaning |
| --- | --- | --- |
| `fadd.s` / `fadd.d` | `0000000` / `0000001` | Add two floating-point values. |
| `fsub.s` / `fsub.d` | `0000100` / `0000101` | Subtract `fs2` from `fs1`. |
| `fmul.s` / `fmul.d` | `0001000` / `0001001` | Multiply. |
| `fdiv.s` / `fdiv.d` | `0001100` / `0001101` | Divide `fs1` by `fs2`. |
| `fsqrt.s` / `fsqrt.d` | `0101100` / `0101101` | Square root; bits `24:20` must be `00000`. |

For these instructions `funct7 = funct5 || fmt`, where `fmt=00` for S,
`fmt=01` for D. Do not apply that interpretation to an arbitrary non-FP opcode.

### Fused multiply-add

R4-type; all four named registers are floating-point. Syntax:
`instruction fd, fs1, fs2, fs3, rm`. `fmt=00` for `.s`, `fmt=01` for `.d`.
There is **one final rounding**, rather than rounding the product separately.

| Instruction, F / D | Opcode | Mathematical operation |
| --- | --- | --- |
| `fmadd.s` / `fmadd.d` | `1000011` (`0x43`) | `(fs1 * fs2) + fs3`. |
| `fmsub.s` / `fmsub.d` | `1000111` (`0x47`) | `(fs1 * fs2) - fs3`. |
| `fnmsub.s` / `fnmsub.d` | `1001011` (`0x4b`) | `-(fs1 * fs2) + fs3`. |
| `fnmadd.s` / `fnmadd.d` | `1001111` (`0x4f`) | `-(fs1 * fs2) - fs3`. |

The names of the last two operations are easy to confuse; use the formulas.

### Sign injection, minimum, and maximum

R-type OP-FP (`0x53`); syntax `instruction fd, fs1, fs2`.
Bits `14:12` are a **fixed funct3**, not a rounding mode.

| Instruction, F / D | funct7, F / D | funct3 | Meaning |
| --- | --- | --- | --- |
| `fsgnj.s` / `fsgnj.d` | `0010000` / `0010001` | `000` | Magnitude/payload from `fs1`, sign from `fs2`. |
| `fsgnjn.s` / `fsgnjn.d` | `0010000` / `0010001` | `001` | Magnitude/payload from `fs1`, inverted sign of `fs2`. |
| `fsgnjx.s` / `fsgnjx.d` | `0010000` / `0010001` | `010` | Magnitude/payload from `fs1`, XOR of both sign bits. |
| `fmin.s` / `fmin.d` | `0010100` / `0010101` | `000` | Smaller number; `-0.0` is less than `+0.0`. |
| `fmax.s` / `fmax.d` | `0010100` / `0010101` | `001` | Larger number; `+0.0` is greater than `-0.0`. |

Sign injection does not set exception flags or canonicalize a valid NaN payload.
For MIN/MAX, one NaN gives the numeric operand, two NaNs give a canonical NaN;
a signaling NaN sets the invalid-operation flag.

### Comparisons and classification

R-type OP-FP (`0x53`); comparisons use `instruction rd, fs1, fs2`.
The destination `rd` is an **integer** register containing `0` or `1`.

| Instruction, F / D | funct7, F / D | funct3 | Meaning |
| --- | --- | --- | --- |
| `feq.s` / `feq.d` | `1010000` / `1010001` | `010` | Equal. |
| `flt.s` / `flt.d` | `1010000` / `1010001` | `001` | Less than. |
| `fle.s` / `fle.d` | `1010000` / `1010001` | `000` | Less than or equal. |
| `fclass.s` / `fclass.d` | `1110000` / `1110001` | `001` | Classify `fs1`; bits `24:20` must be `00000`. |

All comparisons return false when either operand is NaN. FEQ sets the invalid
flag only for signaling NaNs; FLT/FLE set it for any NaN. To branch on a float
comparison, compare into an `x` register, then use `BEQ/BNE`.

`fclass.p rd, fs1` sets exactly one of integer result bits `0 .. 9`;
bits `63:10` are zero. It does not set floating-point exception flags.

| Result bit | Class |
| --- | --- |
| 0 | Negative infinity. |
| 1 | Negative normal number. |
| 2 | Negative subnormal number. |
| 3 | Negative zero. |
| 4 | Positive zero. |
| 5 | Positive subnormal number. |
| 6 | Positive normal number. |
| 7 | Positive infinity. |
| 8 | Signaling NaN. |
| 9 | Quiet NaN. |

### Numeric conversions

All use R-type OP-FP (`0x53`) with `rm` in bits `14:12`.
The mnemonic is **destination type, then source type**. In the first two tables,
bits `24:20` are a fixed type selector, **not an actual second source register**.
`w`/`wu` mean signed/unsigned 32-bit integer; `l`/`lu` mean signed/unsigned
64-bit integer, not C's platform-dependent spelling of `long`.

Float to integer, syntax `instruction rd, fs1, rm` (`x` destination):

| Instruction, F / D | funct7, F / D | rs2/type selector | Result |
| --- | --- | --- | --- |
| `fcvt.w.s` / `fcvt.w.d` | `1100000` / `1100001` | `00000` | Signed 32-bit integer, sign-extended to 64. |
| `fcvt.wu.s` / `fcvt.wu.d` | `1100000` / `1100001` | `00001` | Unsigned 32-bit integer, **also sign-extended** to 64. |
| `fcvt.l.s` / `fcvt.l.d` | `1100000` / `1100001` | `00010` | Signed 64-bit integer. |
| `fcvt.lu.s` / `fcvt.lu.d` | `1100000` / `1100001` | `00011` | Unsigned 64-bit integer. |

Integer to float, syntax `instruction fd, rs1, rm` (`x` source):

| Instruction, F / D | funct7, F / D | rs2/type selector | Input |
| --- | --- | --- | --- |
| `fcvt.s.w` / `fcvt.d.w` | `1101000` / `1101001` | `00000` | Low 32 bits as signed integer. |
| `fcvt.s.wu` / `fcvt.d.wu` | `1101000` / `1101001` | `00001` | Low 32 bits as unsigned integer. |
| `fcvt.s.l` / `fcvt.d.l` | `1101000` / `1101001` | `00010` | Signed 64-bit integer. |
| `fcvt.s.lu` / `fcvt.d.lu` | `1101000` / `1101001` | `00011` | Unsigned 64-bit integer. |

Precision changes, both operands in `f` registers (D required):

| Instruction | funct7 | rs2/type selector | Meaning |
| --- | --- | --- | --- |
| `fcvt.s.d fd, fs1, rm` | `0100000` | `00001` | Convert binary64 to binary32; may round. |
| `fcvt.d.s fd, fs1, rm` | `0100001` | `00000` | Convert binary32 to binary64; widening does not round. |

Use `rtz` explicitly when the source language requires truncation toward zero
for float-to-integer casts; omitting the assembly rounding operand normally
selects the dynamic rounding mode. `FCVT.D.W` and `FCVT.D.WU` are exact;
not every 64-bit integer is exactly representable in binary64.

If the rounded float-to-integer result is out of range, conversion sets NV and
clips to the destination minimum/maximum; NaN yields the maximum integer value
(signed maximum for signed types). Negative out-of-range values clip to zero
for unsigned destinations. Inexact conversions set NX when NV is not set.
These hardware semantics may differ from the source language's cast rules.

### Raw bit moves: not numeric conversions

R-type OP-FP (`0x53`); bits `24:20=00000`, bits `14:12=000`.

| Instruction | funct7 | Meaning |
| --- | --- | --- |
| `fmv.x.w rd, fs1` | `1110000` | Copy low 32 float bits into an integer register, **sign-extend** to 64. |
| `fmv.w.x fd, rs1` | `1111000` | Copy low 32 integer bits into float register; NaN-box when FLEN=64. |
| `fmv.x.d rd, fs1` | `1110001` | Copy all 64 float bits into integer register; RV64 + D. |
| `fmv.d.x fd, rs1` | `1111001` | Copy all 64 integer bits into float register; RV64 + D. |

For example, moving the integer bit pattern `1` into a float register does **not**
create floating-point `1.0`; `FCVT.S.L` / `FCVT.D.L` does a numeric conversion.

## 6. Floating-point rounding and exception state (Zicsr)

### Rounding-mode encoding

| rm | Assembly spelling | Meaning |
| --- | --- | --- |
| `000` | `rne` | Nearest, ties to even. |
| `001` | `rtz` | Toward zero. |
| `010` | `rdn` | Toward negative infinity. |
| `011` | `rup` | Toward positive infinity. |
| `100` | `rmm` | Nearest, ties to maximum magnitude. |
| `101`, `110` | — | Reserved. |
| `111` | `dyn` | Use the mode in `frm`; this value is reserved inside `frm` itself. |

For mathematically exact widening conversions, software should encode `rne`;
the rounding field is still decoded. Reserved rounding encodings have reserved
behavior; do not rely on a particular trap. Explicit static rounding also avoids
unintentionally depending on mutable `frm` state.

### fcsr layout, including its view in a 64-bit integer register

`fcsr` is architecturally a **32-bit** control/status register, not a binary64
value. Reading it into a 64-bit `x` register zero-extends that CSR value.

```text
 63:32             31:8          7:5     4    3    2    1    0
+-----------------+-------------+-------+----+----+----+----+----+
| zero on RV64    | reserved*   | frm   | NV | DZ | OF | UF | NX |
+-----------------+-------------+-------+----+----+----+----+----+
                        24         3      1    1    1    1    1
```

`*` Bits `31:8` are reserved for other standard extensions; when absent, reads
return zero and writes are ignored. Software should preserve these bits.
Flags accrue (sticky until cleared): NV=invalid operation, DZ=divide by zero,
OF=overflow, UF=underflow, NX=inexact. Ordinary F/D arithmetic does **not** trap
just because a floating-point exception flag is set. Subnormal values are
supported; tininess is detected after rounding.

The same state is accessible as three CSRs:

| CSR number | Name | Contents |
| --- | --- | --- |
| `0x001` | `fflags` | Low five exception bits, zero-extended. |
| `0x002` | `frm` | Three-bit rounding mode, zero-extended. |
| `0x003` | `fcsr` | Combined register. |

### CSR instruction encodings

I-shaped encoding, opcode `1110011` (`0x73`):

```text
31:20       19:15              14:12       11:7      6:0
csr(12)     rs1 or zimm5(5)    funct3(3)   rd(5)     1110011
```

Syntax: `instruction rd, csr, rs1` or `instruction rd, csr, zimm5`.
The 5-bit immediate is **zero-extended**, unlike an ordinary I-type immediate.
The CSR address is a number, not a memory address or signed offset.

| Instruction | funct3 | Effect, with old CSR value returned in `rd` when read |
| --- | --- | --- |
| `csrrw` | `001` | Replace CSR with `x[rs1]`. `rd=x0` suppresses the CSR read. |
| `csrrs` | `010` | Set bits selected by `x[rs1]`; `rs1=x0` suppresses the write. |
| `csrrc` | `011` | Clear bits selected by `x[rs1]`; `rs1=x0` suppresses the write. |
| `csrrwi` | `101` | Replace CSR with `zimm5`; `rd=x0` suppresses the read. |
| `csrrsi` | `110` | Set bits selected by `zimm5`; zero immediate suppresses the write. |
| `csrrci` | `111` | Clear bits selected by `zimm5`; zero immediate suppresses the write. |

For CSRRS/CSRRC, a nonzero register **number** containing zero is not equivalent
to specifying `x0` for write-side-effect suppression. Other CSR availability
and privilege checks are platform-dependent; Zicsr does not grant access to
arbitrary privileged state.

Common aliases: `frcsr rd` = `csrrs rd, fcsr, x0`;
`fscsr rd, rs1` = `csrrw rd, fcsr, rs1`;
`frflags rd` reads `fflags`; `fsflags rd, rs1` writes it;
`frrm rd` reads `frm`; `fsrm rd, rs1` writes it.

## 7. Optional M: integer multiplication and division

These are useful for normal compiler arithmetic, but require M in addition to I.
All use R-type with `funct7=0000001`, syntax `instruction rd, rs1, rs2`.

| Instruction | Opcode | funct3 | Meaning |
| --- | --- | --- | --- |
| `mul` | `0110011` (`0x33`) | `000` | Low 64 bits of the product. |
| `mulh` | `0110011` (`0x33`) | `001` | High 64 bits of signed × signed 128-bit product. |
| `mulhsu` | `0110011` (`0x33`) | `010` | High 64 bits of signed `rs1` × unsigned `rs2`. |
| `mulhu` | `0110011` (`0x33`) | `011` | High 64 bits of unsigned × unsigned product. |
| `div` | `0110011` (`0x33`) | `100` | Signed quotient, rounded toward zero. |
| `divu` | `0110011` (`0x33`) | `101` | Unsigned quotient. |
| `rem` | `0110011` (`0x33`) | `110` | Signed remainder; nonzero result has dividend's sign. |
| `remu` | `0110011` (`0x33`) | `111` | Unsigned remainder. |
| `mulw` | `0111011` (`0x3b`) | `000` | Low 32-bit product, sign-extended to 64. |
| `divw` | `0111011` (`0x3b`) | `100` | Signed 32-bit quotient, sign-extended to 64. |
| `divuw` | `0111011` (`0x3b`) | `101` | Unsigned 32-bit quotient, **sign-extended** to 64. |
| `remw` | `0111011` (`0x3b`) | `110` | Signed 32-bit remainder, sign-extended to 64. |
| `remuw` | `0111011` (`0x3b`) | `111` | Unsigned 32-bit remainder, **sign-extended** to 64. |

Integer division by zero does **not** trap: quotient bits are all ones and the
remainder is the dividend. Signed minimum divided by `-1` returns the minimum
value and remainder zero. Word variants apply the 32-bit rule then sign-extend.
Insert explicit checks if the source language requires different behavior.

## 8. Useful assembler pseudoinstructions

Aliases are not additional machine instructions. Their encodings are the real
instructions below, or instruction sequences chosen by the assembler.

| Assembly | Expansion / purpose |
| --- | --- |
| `nop` | `addi x0, x0, 0`. |
| `mv rd, rs` | `addi rd, rs, 0`. |
| `neg rd, rs` | `sub rd, x0, rs`. |
| `not rd, rs` | `xori rd, rs, -1`. |
| `sext.w rd, rs` | `addiw rd, rs, 0`. |
| `seqz rd, rs` | `sltiu rd, rs, 1`. |
| `snez rd, rs` | `sltu rd, x0, rs`. |
| `beqz rs, label` | `beq rs, x0, label`. |
| `bnez rs, label` | `bne rs, x0, label`. |
| `bgt rs1, rs2, label` | `blt rs2, rs1, label`; swap operands. |
| `ble rs1, rs2, label` | `bge rs2, rs1, label`; swap operands. |
| `j label` | `jal x0, label`. |
| `jr rs` | `jalr x0, 0(rs)`. |
| `ret` | `jalr x0, 0(ra)`. |
| `li rd, constant` | Load an integer constant; may require several instructions. |
| `la rd, symbol` | Materialize symbol address; depends on position-independent mode and relocations. |
| `call symbol` | Typically AUIPC + JALR with relocations; linker may relax it. |
| `fmv.p fd, fs` | `fsgnj.p fd, fs, fs`; float-register copy, not integer transfer. |
| `fneg.p fd, fs` | `fsgnjn.p fd, fs, fs`. |
| `fabs.p fd, fs` | `fsgnjx.p fd, fs, fs`. |

For this table only, replace `.p` with `.s` or `.d`.

## 9. Small compiler-oriented examples

These are assembly function fragments, not standalone OS executables.
Assume LP64D, valid pointers, correctly sized buffers, and an ABI-compatible
caller. They contain no bounds, overflow, or null-pointer checks.

### Integer addition and an iterative Fibonacci function

```asm
    .text
    .option norvc

# int64 add_i64(int64 a, int64 b): arguments a0/a1, result a0
add_i64:
    add     a0, a0, a1
    ret

# uint64 fib(uint64 n): returns F(n), F(0)=0, F(1)=1
# Large results wrap modulo 2^64.
fib:
    addi    t0, zero, 0
    addi    t1, zero, 1
.Lfib_loop:
    beq     a0, zero, .Lfib_done
    add     t2, t0, t1
    addi    t0, t1, 0
    addi    t1, t2, 0
    addi    a0, a0, -1
    jal     zero, .Lfib_loop
.Lfib_done:
    addi    a0, t0, 0
    ret
```

### Arrays, structure fields, and pointer dereference

```asm
# int64 sum_i64(int64 *data, uint64 count)
# a0=data, a1=count; return sum in a0
sum_i64:
    addi    t0, zero, 0
.Lsum_loop:
    beq     a1, zero, .Lsum_done
    ld      t1, 0(a0)
    add     t0, t0, t1
    addi    a0, a0, 8
    addi    a1, a1, -1
    jal     zero, .Lsum_loop
.Lsum_done:
    addi    a0, t0, 0
    ret

# void increment_at(int64 *data, uint64 index)
# a0=data, a1=index; scale by element size (8 bytes).
increment_at:
    slli    t0, a1, 3
    add     t0, a0, t0
    ld      t1, 0(t0)
    addi    t1, t1, 1
    sd      t1, 0(t0)
    ret

# Explicit layout: struct Node { int64 value @0; Node *next @8; }
# int64 next_value(Node *node): caller guarantees node and node->next valid.
next_value:
    ld      t0, 8(a0)
    ld      a0, 0(t0)
    ret
```

The Node offsets above are an explicitly assumed layout, not a universal rule
for all languages, packed records, or Odin structures.

### Floating-point computation, comparison, and conversion

```asm
# double affine(double x, double scale, double bias)
# fa0=x, fa1=scale, fa2=bias; return fa0.
affine:
    fmadd.d fa0, fa0, fa1, fa2, rne
    ret

# int64 truncate_f64(double value): fa0 -> a0
# Out-of-range/NaN behavior is FCVT's clipping behavior.
truncate_f64:
    fcvt.l.d a0, fa0, rtz
    ret

# int is_less(double x, double y): comparison result is in integer a0.
is_less:
    flt.d   a0, fa0, fa1
    ret

# void add_f32(float *out, float *left, float *right)
# a0=out, a1=left, a2=right. FLW produces NaN-boxed values with D.
add_f32:
    flw     ft0, 0(a1)
    flw     ft1, 0(a2)
    fadd.s  ft0, ft0, ft1, rne
    fsw     ft0, 0(a0)
    ret
```

### A non-leaf call with a stack frame

```asm
# uint64 fib_plus_one(uint64 n): calls fib, then adds one.
fib_plus_one:
    addi    sp, sp, -16
    sd      ra, 8(sp)
    jal     ra, fib
    addi    a0, a0, 1
    ld      ra, 8(sp)
    addi    sp, sp, 16
    ret
```

All fragment functions can be assembled together, without executing them, using
an existing RISC-V-capable Clang installation:

```sh
clang --target=riscv64-unknown-elf -march=rv64imfd_zicsr -mabi=lp64d \
  -c examples.s -o examples.o
```

Assembly verification is not execution or a proof that the source-language
semantics/ABI are implemented correctly. Running needs suitable RISC-V hardware
or an emulator plus a harness/runtime.

## 10. Worked encoding examples

Each value below is one **32-bit instruction word**. `+8` means a local label
8 bytes after the instruction. Explicit `rne` prevents assembler defaults from
changing the encoded rounding field.

| Instruction | 32-bit word | Bytes at increasing addresses |
| --- | --- | --- |
| `add a0, a1, a2` | `0x00c58533` | `33 85 c5 00` |
| `addi a0, zero, -1` | `0xfff00513` | `13 05 f0 ff` |
| `ld a0, 8(a1)` | `0x0085b503` | `03 b5 85 00` |
| `sd a0, 8(a1)` | `0x00a5b423` | `23 b4 a5 00` |
| `beq a0, a1, +8` | `0x00b50463` | `63 04 b5 00` |
| `jal ra, +8` | `0x008000ef` | `ef 00 80 00` |
| `fadd.s fa0, fa1, fa2, rne` | `0x00c58553` | `53 85 c5 00` |
| `fadd.d fa0, fa1, fa2, rne` | `0x02c58553` | `53 85 c5 02` |
| `ret` (`jalr zero, 0(ra)`) | `0x00008067` | `67 80 00 00` |

For `add a0, a1, a2`, the R-type fields are:

```text
funct7   rs2    rs1    funct3  rd     opcode
0000000  01100  01011  000     01010  0110011
   7       5      5      3      5       7       = 32 bits
```

If a tool stores that instruction in a 64-bit container, it might show
`0x0000000000c58533`; the upper 32 bits are **container padding**, not part of
the RISC-V instruction.

## Sources

The linked upstream branches can evolve; this is a teaching summary, not a
replacement for the ratified specification or a complete ISA decoder contract.

- [Official unprivileged ISA manual, readable edition](https://docs.riscv.org/reference/isa/unpriv/unpriv-index.html).
- [RV32I source chapter](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/rv32.adoc)
  for shared instruction semantics and formats, together with the
  [RV64I chapter](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/rv64.adoc).
- [F chapter](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/f-st-ext.adoc),
  [D chapter](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/d-st-ext.adoc),
  [Zicsr chapter](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/zicsr.adoc),
  and [M chapter](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/m-st-ext.adoc).
- [Official machine-readable opcode definitions](https://github.com/riscv/riscv-opcodes/tree/master/extensions):
  `rv_i`, `rv64_i`, `rv_f`, `rv64_f`, `rv_d`, `rv64_d`, `rv_zicsr`, `rv_m`, `rv64_m`.
- [RISC-V ELF psABI: register and procedure calling conventions](https://github.com/riscv-non-isa/riscv-elf-psabi-doc/blob/master/riscv-cc.adoc).
- [RISC-V assembly programmer's manual](https://github.com/riscv-non-isa/riscv-asm-manual).
