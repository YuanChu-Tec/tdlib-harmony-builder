#!/usr/bin/env python3
"""Apply Windows/MSYS2 compatibility fixes to tl-parser wgetopt.c."""

import sys


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else None
    if not path:
        print("Usage: fix_wgetopt_c_windows.py <path-to-wgetopt.c>", file=sys.stderr)
        sys.exit(1)

    with open(path, "r", encoding="utf-8", errors="replace") as f:
        text = f.read()

    changed = False

    # 1) Add #include <stdlib.h> when !__GNU_LIBRARY__ (after #endif /* GNU C library */)
    marker1 = "#endif\t/* GNU C library.  */\n\n#ifdef VMS"
    insert1 = "#endif\t/* GNU C library.  */\n\n#if !defined(__GNU_LIBRARY__)\n# include <stdlib.h>\n#endif\n\n#ifdef VMS"
    if insert1 not in text and marker1 in text:
        text = text.replace(marker1, insert1)
        changed = True

    # 2) Remove getenv declaration block
    block = """/* Avoid depending on library functions or files
whose names are inconsistent.  */

#ifndef getenv
extern char *getenv();
#endif

"""
    if block in text:
        text = text.replace(block, "")
        changed = True

    # 3) Wrap getenv call: Windows use NULL, else getenv("POSIXLY_CORRECT")
    old_call = "\tposixly_correct = getenv(\"POSIXLY_CORRECT\");"
    new_call = """#if defined(_WIN32) || defined(__MINGW32__) || defined(__MSYS__) || defined(WIN32)
\tposixly_correct = NULL;
#else
\tposixly_correct = getenv("POSIXLY_CORRECT");
#endif"""
    if new_call not in text and old_call in text:
        text = text.replace(old_call, new_call)
        changed = True

    if changed:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("Applied wgetopt.c Windows fixes.")


if __name__ == "__main__":
    main()
