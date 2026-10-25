using System;

namespace BeefForms.Backends;

static
{
	internal static int LineStart(this StringView text, int position) => position > 0 ? text.LastIndexOf('\n', position - 1) + 1 : 0;

	internal static int LineEnd(this StringView text, int position)
	{
		var end = text.IndexOf('\n', position);
		if (end < 0) return text.Length;
		if (end > 0 && text[end - 1] == '\r') end--;
		return end;
	}
}
