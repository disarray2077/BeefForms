#!/usr/bin/env python3
"""Convert a WinForms C# designer to a Beef extension (Python 3.10+, no packages)."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import re
import sys
import textwrap


class ConversionError(ValueError):
    """The source cannot be converted safely by this syntax converter."""


@dataclass(frozen=True)
class Token:
    text: str
    start: int
    end: int


@dataclass
class Conversion:
    code: str
    warnings: list[str]


TOKEN = re.compile(
    r'\s+|//[^\n]*|/\*[\s\S]*?\*/|@"(?:[^"]|"")*"'
    r'|"(?:[^"\\\r\n]|\\.)*"|\'(?:[^\'\\\r\n]|\\.)*\''
    r'|@?[A-Za-z_][A-Za-z_0-9]*|\+=|-=|=>|::|[^\s]'
)
NAME = re.compile(r'[A-Za-z_][A-Za-z_0-9]*(?:\.[A-Za-z_][A-Za-z_0-9]*)*\Z')
VALUE_TYPES = {f"System.Drawing.{name}" for name in ("Point", "PointF", "Size", "SizeF", "Rectangle", "RectangleF")}
VALUE_TYPES |= {name.rsplit(".", 1)[-1] for name in VALUE_TYPES}
VALUE_PROPERTIES = {"Location", "Size", "ClientSize", "MinimumSize", "MaximumSize", "AutoScaleDimensions", "Bounds"}
PRIMITIVES = {"byte": "uint8", "sbyte": "int8", "short": "int16", "ushort": "uint16", "long": "int64", "ulong": "uint64", "object": "Object", "string": "String"}


def tokenize(source: str) -> list[Token]:
    """Keep source offsets; never rewrite text inside comments or string literals."""
    result = []
    for match in TOKEN.finditer(source):
        value = match.group()
        if value.isspace() or value.startswith(("//", "/*")):
            continue
        if value == '$' and source[match.end():].startswith(('"', '@"')):
            raise ConversionError("Interpolated C# strings need a manual port")
        if source.startswith('"""', match.start()):
            raise ConversionError("C# raw strings need a manual port")
        if value in ('"', "'") or (value == '/' and source.startswith('/*', match.start())):
            raise ConversionError(f"Unterminated string or comment at offset {match.start()}")
        result.append(Token(value, match.start(), match.end()))
    return result


def matching(tokens: list[Token], start: int) -> int:
    pairs = {'(': ')', '{': '}', '[': ']'}
    stack = []
    for index in range(start, len(tokens)):
        value = tokens[index].text
        if value in pairs:
            stack.append(pairs[value])
        elif value in pairs.values():
            if not stack or value != stack.pop():
                raise ConversionError(f"Unbalanced delimiter near {tokens[index].start}")
            if not stack:
                return index
    raise ConversionError("Unclosed delimiter")


def edit(source: str, changes: list[tuple[int, int, str]]) -> str:
    end = 0
    output = []
    for start, stop, replacement in sorted(changes):
        if start < end:
            raise ConversionError("Overlapping source transformations")
        output.extend((source[end:start], replacement))
        end = stop
    output.append(source[end:])
    return ''.join(output)


def remove_scaffolding(body: str, warnings: list[str]) -> str:
    tokens = tokenize(body)
    changes = []
    index = 0
    while index < len(tokens):
        # Designer Dispose(bool) is replaced by Beef's ownership/destructor model.
        if [t.text for t in tokens[index:index + 5]] == ['protected', 'override', 'void', 'Dispose', '(']:
            close = matching(tokens, index + 4)
            if [t.text for t in tokens[index + 5:close]] != ['bool', 'disposing'] or tokens[close + 1].text != '{':
                raise ConversionError("Unrecognized Dispose signature")
            last = matching(tokens, close + 1)
            changes.append((tokens[index].start, tokens[last].end, ''))
            warnings.append("Removed Dispose(bool); port any custom cleanup to ~this() in the companion class.")
            index = last + 1
            continue
        # Remove only the conventional components field and its initialization.
        if tokens[index].text == 'private':
            stop = index
            while stop < len(tokens) and tokens[stop].text not in (';', '{', '('):
                stop += 1
            declaration = ''.join(t.text for t in tokens[index:stop])
            if declaration in ('privateSystem.ComponentModel.IContainercomponents=null', 'privateIContainercomponents=null'):
                changes.append((tokens[index].start, tokens[stop].end, ''))
                index = stop + 1
                continue
        offset = index + 2 if [t.text for t in tokens[index:index + 2]] == ['this', '.'] else index
        if [t.text for t in tokens[offset:offset + 3]] == ['components', '=', 'new']:
            stop = next((j for j in range(offset + 3, len(tokens)) if tokens[j].text == ';'), None)
            if stop is not None:
                statement = ''.join(t.text for t in tokens[offset:stop])
                if statement in ('components=newSystem.ComponentModel.Container()', 'components=newContainer()'):
                    changes.append((tokens[index].start, tokens[stop].end, ''))
                    index = stop + 1
                    continue
        index += 1
    return edit(body, changes)


def convert_events(body: str) -> str:
    tokens = tokenize(body)
    changes = []
    for index, token in enumerate(tokens):
        if token.text not in ('+=', '-='):
            continue
        start = index + 1
        stop = next((j for j in range(start, len(tokens)) if tokens[j].text == ';'), None)
        if stop is None:
            raise ConversionError("Unterminated event subscription")
        expression = tokens[start:stop]
        if expression and expression[0].text == 'new':
            opening = next((j for j in range(start + 1, stop) if tokens[j].text == '('), None)
            if opening is None or matching(tokens, opening) != stop - 1:
                raise ConversionError("Event subscriptions must use a named handler")
            expression = tokens[opening + 1:stop - 1]
        handler = ''.join(t.text for t in expression)
        if not NAME.fullmatch(handler):
            raise ConversionError("Event subscriptions must use a named handler; port lambdas manually")
        changes.append((tokens[start].start, tokens[stop - 1].end, f"new => {handler}"))
    return edit(body, changes)


def expand_add_range(body: str) -> str:
    tokens = tokenize(body)
    changes = []
    for index, token in enumerate(tokens):
        if token.text != 'AddRange' or [t.text for t in tokens[max(0, index - 2):index]] != ['Controls', '.']:
            continue
        start = index - 2
        while start >= 2 and tokens[start - 1].text == '.' and re.fullmatch(r'@?\w+', tokens[start - 2].text):
            start -= 2
        opening = index + 1
        if tokens[opening].text != '(':
            raise ConversionError("Unrecognized Controls.AddRange")
        close = matching(tokens, opening)
        brace = next((j for j in range(opening + 1, close) if tokens[j].text == '{'), None)
        if brace is None or matching(tokens, brace) != close - 1 or tokens[close + 1].text != ';':
            raise ConversionError("Controls.AddRange requires an inline control array")
        array_type = ''.join(t.text for t in tokens[opening + 1:brace])
        if array_type not in ('newSystem.Windows.Forms.Control[]', 'newControl[]', 'new[]'):
            raise ConversionError("Controls.AddRange requires an inline control array")
        entries = ''.join(t.text for t in tokens[brace + 1:close - 1]).split(',')
        entries = [entry for entry in entries if entry]
        if not all(NAME.fullmatch(entry) for entry in entries):
            raise ConversionError("Controls.AddRange entries must be control references")
        receiver = body[tokens[start].start:token.start]
        indent = re.search(r'[^\S\n]*$', body[:tokens[start].start]).group()
        replacement = ('\n' + indent).join(f"{receiver}Add({entry});" for entry in entries)
        changes.append((tokens[start].start, tokens[close + 1].end, replacement))
    return edit(body, changes)


def convert_literal(value: str) -> str:
    if value.startswith('@"'):
        value = json.dumps(value[2:-1].replace('""', '"'), ensure_ascii=False)

    def escape(match: re.Match) -> str:
        sequence = match.group()
        if sequence[1] in 'uUx':
            if len(sequence) == 12 and sequence[6:8] == '\\u':
                codepoint = 0x10000 + ((int(sequence[2:6], 16) - 0xD800) << 10) + int(sequence[8:], 16) - 0xDC00
                return f'\\u{{{codepoint:X}}}'
            if 0xD800 <= int(sequence[2:], 16) <= 0xDFFF:
                raise ConversionError("Unpaired UTF-16 surrogate in a C# literal needs a manual port")
            return '\\u{' + sequence[2:] + '}'
        return sequence

    return re.sub(r'\\u[dD][89aAbB][0-9a-fA-F]{2}\\u[dD][c-fC-F][0-9a-fA-F]{2}|\\(?:u[0-9a-fA-F]{4}|U[0-9a-fA-F]{8}|x[0-9a-fA-F]{1,4}|.)', escape, value)


def convert(source: str, namespace: str | None = None) -> Conversion:
    source = source.removeprefix('\ufeff').replace('\r\n', '\n')
    tokens = tokenize(source)
    classes = [i for i in range(len(tokens) - 2) if tokens[i].text == 'partial' and tokens[i + 1].text == 'class']
    if len(classes) != 1 or sum(token.text == 'class' for token in tokens) != 1:
        raise ConversionError("Expected exactly one partial designer class")
    index = classes[0]
    class_name = tokens[index + 2].text
    opening = next((i for i in range(index + 3, len(tokens)) if tokens[i].text == '{'), None)
    if opening is None:
        raise ConversionError("Missing designer class body")
    closing = matching(tokens, opening)
    namespaces = [i for i in range(index) if tokens[i].text == 'namespace']
    if namespace is None:
        if len(namespaces) > 1:
            raise ConversionError("Nested namespace declarations require --namespace")
        if namespaces:
            start = namespaces[0] + 1
            stop = next(i for i in range(start, index) if tokens[i].text in ('{', ';'))
            namespace = ''.join(t.text for t in tokens[start:stop])
    if namespace is not None and not NAME.fullmatch(namespace):
        raise ConversionError(f"Invalid namespace: {namespace}")

    body = textwrap.dedent(source[tokens[opening].end:tokens[closing].start])
    # Remove C#'s global alias qualifier without touching literal text.
    body_tokens = tokenize(body)
    body = edit(body, [(token.start, body_tokens[i + 1].end, '') for i, token in enumerate(body_tokens[:-1]) if token.text == 'global' and body_tokens[i + 1].text == '::'])
    warnings = []
    body = remove_scaffolding(body, warnings)
    body = expand_add_range(body)
    body = convert_events(body)
    body_tokens = tokenize(body)
    changes = []
    for index, token in enumerate(body_tokens):
        value = token.text
        if value.startswith(('"', '@"', "'")):
            changes.append((token.start, token.end, convert_literal(value)))
        elif value in PRIMITIVES:
            changes.append((token.start, token.end, PRIMITIVES[value]))
        elif value == 'new':
            next_index = index + 1
            while next_index < len(body_tokens) and (re.fullmatch(r'@?\w+', body_tokens[next_index].text) or body_tokens[next_index].text == '.'):
                next_index += 1
            type_name = ''.join(t.text for t in body_tokens[index + 1:next_index])
            if next_index < len(body_tokens) and body_tokens[next_index].text == '(':
                if type_name in VALUE_TYPES:
                    changes.append((token.start, body_tokens[index + 1].start, ''))
                elif not type_name:
                    property_name = body_tokens[index - 2].text if index >= 2 and body_tokens[index - 1].text == '=' else ''
                    changes.append((token.start, token.end, '.' if property_name in VALUE_PROPERTIES else 'new .'))
    body = edit(body, changes)
    remaining = {token.text for token in tokenize(body)}
    if 'components' in remaining:
        warnings.append("Remaining references to components need a manual ownership port.")
    if remaining & {'ComponentResourceManager', 'ISupportInitialize', 'GetObject', 'ApplyResources'}:
        warnings.append("Resource loading/ISupportInitialize code is retained and needs a manual port.")
    # C# nullable annotations do not apply to Beef. Keep designer regions/comments.
    body = re.sub(r'^[ \t]*#nullable[^\n]*\n?', '', body, flags=re.MULTILINE)
    body = re.sub(r'\n[ \t]*\n(?:[ \t]*\n)+', '\n\n', body).strip()
    prefix = f"namespace {namespace};\n\n" if namespace else ''
    # Preserve ordinary using directives for unqualified designer type names.
    using_end = namespaces[0] if namespaces else classes[0]
    usings = []
    for i, token in enumerate(tokens[:using_end]):
        if token.text == 'using':
            stop = next(j for j in range(i + 1, using_end) if tokens[j].text == ';')
            usings.append(source[token.start:tokens[stop].end])
    if usings:
        prefix = '\n'.join(usings) + '\n\n' + prefix
    return Conversion(prefix + f"extension {class_name}\n{{\n" + textwrap.indent(body, '    ') + '\n}\n', warnings)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, epilog="The companion Beef class must provide the Form base, constructor, and named event handlers. Unsupported .NET APIs require manual porting.")
    parser.add_argument('input', type=Path, help='C# .Designer.cs file')
    parser.add_argument('-o', '--output', type=Path, help='output .bf path (default: beside the input)')
    parser.add_argument('--namespace', help='override the source namespace')
    parser.add_argument('--force', action='store_true', help='overwrite an existing output')
    args = parser.parse_args(argv)
    output = args.output or args.input.with_suffix('.bf')
    try:
        if args.input.resolve() == output.resolve():
            raise ConversionError("Input and output must be different files")
        result = convert(args.input.read_text(encoding='utf-8-sig'), args.namespace)
        # Exclusive creation protects existing/manual designers by default.
        with output.open('w' if args.force else 'x', encoding='utf-8', newline='\n') as handle:
            handle.write(result.code)
    except (OSError, UnicodeError, ConversionError, IndexError, StopIteration) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    for warning in result.warnings:
        print(f"warning: {warning}", file=sys.stderr)
    print(f"Wrote {output}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
