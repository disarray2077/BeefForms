using System;
using System.Drawing;

namespace BeefForms.Tests;

class FontTests
{
	[Test]
	public static void FamilyNameKeepsItsOwnCopyOfTheInput()
	{
		let family = scope String("Segoe UI");
		let font = scope Font(family, 12);
		StringView name = font.FamilyName;
		family.Set("A different font family with a longer name");
		Test.Assert(name == "Segoe UI");
		Test.Assert(font.FamilyName == "Segoe UI");
	}
}
