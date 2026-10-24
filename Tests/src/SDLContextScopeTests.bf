using System;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class SDLContextScopeTests
{
	[Test]
	public static void NonRenderingOperationsPreserveTheCallersContext()
	{
		Application.UseBackend(.SDL2OpenGL);
		let caller = scope Form(); let target = scope Form();
		caller.ClientSize = target.ClientSize = .(240, 120);
		let first = new TextBox(); let second = new TextBox();
		first.Size = second.Size = .(120, 25); second.Location = .(0, 40);
		target.Controls.Add(first); target.Controls.Add(second);
		caller.Show(); target.Show(); Application.DoEvents();
		let backend = (SDLBackend)Application.Backend;
		let callerSession = backend.GetSession(caller);
		let targetSession = backend.GetSession(target);
		SDL.Event active = .(); active.type = .WindowEvent; active.window.windowEvent = .FocusGained;
		SDLTestInput.SetWindow(ref active, target); backend.[Friend]ProcessEvent(ref active);
		first.Focus();
		callerSession.MakeCurrent();
		int lost = 0, gained = 0, resized = 0;
		first.LostFocus.Add(new [&] (sender, args) =>
		{
			lost++;
			Test.Assert(SDL.GL_GetCurrentContext() == callerSession.mContext);
			Test.Assert(targetSession.RefCount > 1);
		});
		second.GotFocus.Add(new [&] (sender, args) =>
		{
			gained++;
			Test.Assert(SDL.GL_GetCurrentContext() == callerSession.mContext);
		});
		second.LostFocus.Add(new [&] (sender, args) =>
		{
			lost++;
			Test.Assert(SDL.GL_GetCurrentContext() == callerSession.mContext);
			Test.Assert(targetSession.RefCount > 1);
		});
		Test.Assert(second.Focus());
		second.Enabled = false;
		target.SizeChanged.Add(new [&] (sender, args) =>
		{
			resized++;
			Test.Assert(SDL.GL_GetCurrentContext() == callerSession.mContext);
			Test.Assert(targetSession.RefCount > 1);
		});
		target.ClientSize = .(280, 160);
		target.Hide(); target.Show();
		let added = new Control(); target.Controls.Add(added);
		first.Capture = true; first.Capture = false;
		Test.Assert(lost == 2 && gained == 1 && resized == 1);
		Test.Assert(SDL.GL_GetCurrentContext() == callerSession.mContext && SDL.GL_GetCurrentWindow() == caller.Handle);
		SDLTestInput.AssertNoGLError(caller); SDLTestInput.AssertNoGLError(target);
	}

	[Test]
	public static void UpdatingAControlRetainsItsSessionAcrossDisposalCallbacks()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let editor = new TextBox(); editor.Size = .(120, 25); form.Controls.Add(editor);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend); editor.Focus();
		let session = backend.GetSession(form);
		int callbacks = 0;
		editor.LostFocus.Add(new [&] (sender, args) =>
		{
			form.Close();
			callbacks++;
			Test.Assert(session.RefCount > 0 && session.mWindow == null);
		});
		editor.Enabled = false;
		Test.Assert(callbacks == 1 && form.IsDisposed && backend.GetSession(form) == null);
		Test.Assert(Application.CreatedControlCount == 0);
	}

	[Test]
	public static void InputDispatchRetainsItsSessionAcrossDisposalCallbacks()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let panel = new Panel(); panel.Size = .(120, 80); form.Controls.Add(panel);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		let session = backend.GetSession(form);
		int callbacks = 0;
		panel.MouseDown.Add(new [&] (sender, args) =>
		{
			args.Handled = true;
			form.Close();
			callbacks++;
			Test.Assert(session.RefCount > 0 && session.mWindow == null);
		});
		SDL.Event input = .(); input.type = .MouseButtonDown;
		input.button.button = 1; input.button.x = input.button.y = 10;
		SDLTestInput.SetWindow(ref input, form); backend.[Friend]ProcessEvent(ref input);
		Test.Assert(callbacks == 1 && form.IsDisposed && backend.GetSession(form) == null);
		Test.Assert(Application.CreatedControlCount == 0);
	}
}
