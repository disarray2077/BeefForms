using System;
using System.Collections;
using System.Text;

namespace BeefForms.Backends;

// UTF-8 byte boundaries and conversion to/from native UTF-16 selection offsets.
internal static class TextEncodingHelper
{
	public static int CharacterBoundary(StringView text, int position)
	{
		var result = Math.Clamp(position, 0, text.Length);
		while (result > 0 && result < text.Length && ((uint8)text[result] & 0xC0) == 0x80)
			result--;
		return result;
	}

	public static int AdjacentPosition(StringView text, int position, bool forward, bool multiline)
	{
		var result = position + (forward ? 1 : -1);
		if (multiline && result > 0 && result < text.Length && text[result - 1] == '\r' && text[result] == '\n')
			result += forward ? 1 : -1;
		while (result > 0 && result < text.Length && ((uint8)text[result] & 0xC0) == 0x80)
			result += forward ? 1 : -1;
		return Math.Clamp(result, 0, text.Length);
	}

	/// Appends complete UTF-8 prefix lengths, starting with zero.
	public static void GetCharacterBoundaries(StringView text, List<int> boundaries)
	{
		boundaries.Add(0);
		int position = 0;
		for (let character in text.DecodedChars)
		{
			position += UTF8.GetEncodedLength(character);
			boundaries.Add(position);
		}
	}

	public static int ToUtf16Offset(StringView text, int utf8Offset) =>
		UTF16.GetEncodedLen(text.Substring(0, utf8Offset));

	public static int ToUtf8Offset(StringView text, int utf16Offset)
	{
		int units = 0, bytes = 0;
		for (let character in text.DecodedChars)
		{
			let length = UTF16.GetEncodedLength(character);
			// Keep whole characters when an index falls between a surrogate pair.
			if (units + length > utf16Offset) break;
			units += length;
			bytes += UTF8.GetEncodedLength(character);
		}
		return bytes;
	}
}
