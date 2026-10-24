using System;
using System.Windows.Forms;

namespace BeefForms.Tests;

class OpenFormsTests
{
	private static void VerifyCollection(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let forms = Application.OpenForms;
		Test.Assert(forms.Count == 0);
		let first = scope Form(); first.ClientSize = .(200, 100); first.Name = "Main";
		let second = scope Form(); second.ClientSize = .(200, 100); second.Name = "main";
		let unnamed = scope Form(); unnamed.ClientSize = .(200, 100);
		first.Show(); second.Show(); unnamed.Show();
		Test.Assert(Application.OpenForms == forms && forms.Count == 3);
		Test.Assert(forms[0] == first && forms[1] == second && forms[2] == unnamed);
		Test.Assert(forms["MAIN"] == first && forms[""] == unnamed);
		Test.Assert(forms["missing"] == null && forms[(StringView)default] == null);
		let name = scope String("Renamed");
		first.Name = name;
		name.Clear();
		Test.Assert(forms["renamed"] == first && forms["MAIN"] == second);
		int index = 0;
		for (let form in forms)
		{
			Test.Assert(form == forms[index]);
			index++;
		}
		Test.Assert(index == 3);
		first.Hide();
		Test.Assert(forms.Count == 3);
		first.Show();
		Test.Assert(forms.Count == 3 && forms[0] == first);
		first.Close();
		Test.Assert(forms.Count == 2 && forms[0] == second);
		second.Dispose(); unnamed.Close();
		Test.Assert(forms.Count == 0);
	}

	[Test] public static void SDLOpenFormsIsALiveReadOnlyIndexedCollection() => VerifyCollection(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeOpenFormsIsALiveReadOnlyIndexedCollection() => VerifyCollection(.Win32);
#endif
}
