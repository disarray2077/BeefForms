using System;
using System.Windows.Forms;

namespace BeefForms.Tests;

class ApplicationTests
{
	[Test]
	public static void BackendCanChangeAfterCreatedControlsAreDisposed()
	{
		Application.UseBackend(.SDL2OpenGL);
		{
			let form = scope Form();
			form.ClientSize = .(200, 100);
			let button = new Button();
			button.Size = .(80, 25);
			form.Controls.Add(button);
			form.Show();
			form.Close();
		}
		Application.UseBackend(.SDL2OpenGL);
	}
}
