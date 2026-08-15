#!/usr/bin/env sh
#
# Fails if any source file is neither valid UTF-8 without a byte order mark, nor a BOM-marked UTF-16
# file.
#
# This is the guard that has to exist before SA1412 is switched off. SA1412 required a byte order
# mark, which was never the point - but it was, by accident, the only thing standing between the
# build and a file saved as Windows-1252. Measured: such a file compiles with no warning and no
# error, and the compiler writes U+FFFD replacement characters into the assembly. The corruption is
# silent, it reaches the binary, and no analyser reports it, because by the time an analyser runs the
# text has already been decoded.
#
# No analyser can cover this anyway - it is a property of bytes on disk, and it applies to .json and
# .resx as much as to .cs. Hence a script.
#
# A UTF-8 mark is a failure, not an acceptance. It records nothing - UTF-8 is what the compiler
# assumes when there is no mark - and it comes back on its own: an editor that opened a file with one
# writes one back on every later save. NOTA0002 says the same thing to consumers, but only about
# files the compiler sees; here it covers the .md, .json and .targets files as well.
#
# UTF-16 is accepted when it carries a BOM. Generated output - svcutil service references, EF
# migrations - is often UTF-16, the compiler reads it correctly from the BOM, and such a file must
# keep that BOM: it is the only thing recording the encoding.
#
# What this cannot catch: a wrong encoding that happens to produce valid UTF-8 - the classic "â€œ"
# mojibake - which is indistinguishable from someone deliberately writing those characters. What it
# does catch is any file containing a byte sequence that is not legal UTF-8, which is every ordinary
# case of an ANSI file with Danish, Cyrillic or CJK text in it.
#
# POSIX sh and BSD-safe, so it runs on a developer's Mac and in a Linux build container alike.
#
# The verification samples are excluded. They are wrong on purpose - one of them is Windows-1252, so
# that NOTA0001 has something to fire on - and this check exists to find files that are wrong by
# accident.
#
# Paths are passed to a child shell by find rather than through a variable and a for loop. That is
# not fussiness: word splitting on an unquoted expansion breaks every path containing a space, and
# reports each half as unreadable - which looks exactly like a corrupt file, in a whole directory of
# them at once, because "Service References" has a space in it.

set -eu

root="${1:-.}"

# Each line is a tag and a path. Two different faults are being looked for in one pass over the
# bytes, and they want different advice: one is corruption, the other is noise that comes back.
found="$(find "$root" \
    \( -name '*.cs' -o -name '*.csproj' -o -name '*.json' -o -name '*.resx' -o -name '*.md' -o -name '*.props' -o -name '*.targets' \) \
    -not -path '*/obj/*' -not -path '*/bin/*' -not -path '*/.git/*' \
    -not -path '*/Nota.CodeAnalysis.Verification/Samples/*' \
    -exec sh -c '
        for f do
            bom=$(head -c 3 "$f" | xxd -p)
            case "$bom" in
                fffe*|feff*) ;;
                efbbbf) printf "bom %s\n" "$f" ;;
                *) iconv -f UTF-8 -t UTF-8 "$f" >/dev/null 2>&1 || printf "invalid %s\n" "$f" ;;
            esac
        done
    ' sh {} +)"

invalid="$(printf '%s\n' "$found" | sed -n 's/^invalid //p')"
marked="$(printf '%s\n' "$found" | sed -n 's/^bom //p')"

status=0

if [ -n "$invalid" ]; then
    printf 'Not valid UTF-8:\n' >&2
    printf '%s\n' "$invalid" | sed 's/^/  /' >&2
    printf '\nThese compile without complaint and land in the assembly as U+FFFD.\n' >&2
    printf 'Re-save them as UTF-8; check the tool or editor that last wrote them.\n' >&2
    status=1
fi

# This repository ships NOTA0002, which fails a consumer build over exactly this. Its own tree is the
# first place that has to be clean - and unlike NOTA0002, which only ever sees @(Compile), this pass
# also covers the .md, .json and .targets files no compiler reads.
if [ -n "$marked" ]; then
    [ "$status" -eq 0 ] || printf '\n' >&2
    printf 'Carrying a UTF-8 byte order mark:\n' >&2
    printf '%s\n' "$marked" | sed 's/^/  /' >&2
    printf '\nStrip them with tools/de-bom.sh, with the editor closed - one that opened a file with a\n' >&2
    printf 'mark writes the mark back on the next save, however the file on disk now looks.\n' >&2
    status=1
fi

[ "$status" -eq 0 ] || exit "$status"

printf 'All source files are valid UTF-8 without a byte order mark, or BOM-marked UTF-16.\n'
