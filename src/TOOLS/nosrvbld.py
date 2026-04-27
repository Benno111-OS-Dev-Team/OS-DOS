#!/usr/bin/env python3
"""
nosrvbld.py - Replacement for the 16-bit NOSRVBLD.EXE tool.

Reads a .skl skeleton file and a .msg message file, and generates one .clN
assembly include file for each :class N section found in the skeleton.

Usage: python nosrvbld.py <basename>.skl <messages>.msg
"""

import sys
import os
import re


def parse_msg_file(msg_path):
    """Parse a .msg file and return dict: SECTION_NAME -> {msg_num -> [text_lines]}."""
    sections = {}
    current_section = None
    current_msgs = {}
    current_num = None
    current_lines = []

    # Use errors='replace' to handle vintage DOS source files that may contain
    # non-ASCII characters (e.g. extended ASCII in comments or message text).
    with open(msg_path, 'r', errors='replace') as f:
        lines = f.readlines()

    for raw in lines:
        line = raw.rstrip('\r\n')

        # Section header: starts with an uppercase letter followed by more word chars,
        # then whitespace and two hex-like fields, e.g. "MSBIO    548a 0019"
        if re.match(r'^[A-Z][A-Z0-9]*\s', line):
            # Save any pending message and section
            if current_num is not None:
                current_msgs[current_num] = current_lines
                current_num = None
                current_lines = []
            if current_section is not None:
                sections[current_section] = current_msgs
            current_section = line.split()[0].upper()
            current_msgs = {}
            continue

        # Message line: 4-digit decimal number, then " U ", then class, then text
        # e.g. "0020 U 0000 13,10,\"Insert diskette for drive \""
        m = re.match(r'^(\d{4})\s+U\s+\S+\s+(.*)', line)
        if m and current_section is not None:
            if current_num is not None:
                current_msgs[current_num] = current_lines
            current_num = int(m.group(1))
            current_lines = [m.group(2)]
            continue

        # Continuation line: starts with a TAB
        if line.startswith('\t') and current_num is not None:
            current_lines.append(line.lstrip('\t'))
            continue

    # Flush last message and section
    if current_num is not None:
        current_msgs[current_num] = current_lines
    if current_section is not None:
        sections[current_section] = current_msgs

    return sections


def parse_skl_file(skl_path):
    """Parse a .skl file and return list of (class_id, [(kind, args)]) tuples.

    kind is 'def' or 'use', args is a dict with the relevant fields.
    class_id is an integer or hex digit string (e.g. '1', 'A', 'B').
    """
    classes = []       # list of (class_id_str, entries)
    current_class = None
    current_entries = []

    # Use errors='replace' to handle vintage DOS source files that may contain
    # non-ASCII characters (e.g. extended ASCII in comments).
    with open(skl_path, 'r', errors='replace') as f:
        lines = f.readlines()

    for raw in lines:
        # Strip trailing whitespace and inline comments
        line = raw.rstrip('\r\n')
        # Remove inline ;... comments (but keep ; at start as a full comment)
        # Strip leading/trailing whitespace for directive detection
        stripped = line.strip()

        if not stripped or stripped.startswith(';'):
            continue

        # Remove trailing comment for directives: split on first ';' that isn't
        # inside a string literal.  A simple approach: strip everything after the
        # first bare semicolon.
        directive = re.split(r'\s*;', stripped, maxsplit=1)[0].rstrip()

        upper = directive.upper()

        if upper.startswith(':CLASS'):
            # Save previous class
            if current_class is not None:
                classes.append((current_class, current_entries))
            # :class N  or  :class A  (hex letter)
            parts = directive.split()
            current_class = parts[1] if len(parts) > 1 else '1'
            current_entries = []
            continue

        if upper.startswith(':END'):
            break

        if upper.startswith(':DEF'):
            # :def NUM LABEL DB text...
            # or :def NUM LABEL db text...
            # (type keyword DB may be absent in some forms, but in practice
            #  it is always present in nosrvbld-style skeletons)
            # Split carefully: ":def NUM LABEL DB rest..."
            # Use the original `directive` to preserve case of label
            parts = directive.split(None, 4)
            if len(parts) >= 4:
                num = int(parts[1])
                label = parts[2]
                # parts[3] is 'DB' / 'db', parts[4] (if any) is the fallback text
                current_entries.append(('def', {'num': num, 'label': label}))
            continue

        if upper.startswith(':USE'):
            # :use NUM SECTION LABEL
            parts = directive.split(None, 3)
            if len(parts) >= 4:
                num = int(parts[1])
                section = parts[2].upper()
                label = parts[3]
                current_entries.append(('use', {'num': num,
                                                'section': section,
                                                'label': label}))
            continue

    # Flush last class
    if current_class is not None:
        classes.append((current_class, current_entries))

    return classes


def class_id_to_suffix(class_id):
    """Convert class id to file suffix: '1'->'1', 'A'->'a', etc."""
    return str(class_id).lower()


def build_cl_file(name, suffix, entries, sections, skl_section):
    """Build the content of a single .clN file as a string."""
    lines_out = []
    header = f"; {name}.cl{suffix} "
    lines_out.append(header)
    lines_out.append("")
    lines_out.append("")

    for i, (kind, args) in enumerate(entries):
        num = args['num']
        label = args['label']

        if kind == 'def':
            section_msgs = sections.get(skl_section, {})
        else:  # 'use'
            section_msgs = sections.get(args['section'], {})

        msg_lines = section_msgs.get(num)
        if msg_lines is None:
            # Message not found; emit a warning and skip this entry
            sys.stderr.write(
                f"Warning: message {num} not found in section "
                f"'{skl_section if kind == 'def' else args['section']}'\n"
            )
            continue

        lines_out.append(";_______________________")
        lines_out.append("")
        # First line: LABEL DB    text
        lines_out.append(f"{label} DB    {msg_lines[0]}")
        # Continuation lines
        for cont in msg_lines[1:]:
            lines_out.append(f"\tDB   \t{cont}")
        # Blank line between entries (not after the last one)
        if i < len(entries) - 1:
            lines_out.append("")

    return "\n".join(lines_out) + "\n"


def main():
    if len(sys.argv) != 3:
        sys.stderr.write(
            f"Usage: {sys.argv[0]} <basename>.skl <messages>.msg\n"
        )
        sys.exit(1)

    skl_path = sys.argv[1]
    msg_path = sys.argv[2]

    basename = os.path.splitext(os.path.basename(skl_path))[0].lower()
    skl_section = basename.upper()
    out_dir = os.path.dirname(os.path.abspath(skl_path))

    sections = parse_msg_file(msg_path)
    classes = parse_skl_file(skl_path)

    for class_id, entries in classes:
        suffix = class_id_to_suffix(class_id)
        content = build_cl_file(basename, suffix, entries, sections, skl_section)
        out_path = os.path.join(out_dir, f"{basename}.cl{suffix}")
        # Write with Unix line endings (LF only) to match the original tool's
        # output format, which the existing checked-in .cl files use.
        with open(out_path, 'w', newline='\n') as f:
            f.write(content)


if __name__ == '__main__':
    main()
