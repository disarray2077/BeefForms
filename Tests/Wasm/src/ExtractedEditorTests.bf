using System;
using System.Windows.Forms;

namespace BeefForms.WasmTests;

class ExtractedEditorTests
{
	public static void Run()
	{
		let form = new Form();
		form.ClientSize = .(360, 300);
		let filtered = new TextBox();
		filtered.Location = .(12, 12);
		filtered.Size = .(320, 28);
		filtered.Text = "12";
		filtered.KeyPress.Add(new (sender, args) =>
		{
			if (args.KeyChar != '\b' && (args.KeyChar < '0' || args.KeyChar > '9'))
				args.Handled = true;
		});
		filtered.TextChanged.Add(new (sender, args) => Console.WriteLine(scope $"FILTERED:{filtered.Text}"));
		form.Controls.Add(filtered);
		let multiline = new TextBox();
		multiline.Multiline = true;
		multiline.Location = .(12, 60);
		multiline.Size = .(320, 80);
		multiline.Text = "one\r\ntwo";
		multiline.TextChanged.Add(new (sender, args) =>
		{
			let text = scope String(multiline.Text);
			text.Replace("\r\n", "|");
			Console.WriteLine(scope $"MULTILINE:{text}");
		});
		form.Controls.Add(multiline);
		let readOnly = new TextBox();
		readOnly.Location = .(12, 160);
		readOnly.Size = .(320, 28);
		readOnly.Text = "Read only";
		readOnly.ReadOnly = true;
		form.Controls.Add(readOnly);
		let shutdown = new TextBox();
		shutdown.Location = .(12, 210);
		shutdown.Size = .(320, 28);
		shutdown.Text = "Close from filter";
		shutdown.TextInput.Add(new (sender, args) => form.Close());
		form.Controls.Add(shutdown);
		form.Disposed.Add(new (sender, args) => Console.WriteLine("CLOSED"));
		form.Shown.Add(new (sender, args) => Console.WriteLine("READY"));
		Application.Run(form);
	}
}
