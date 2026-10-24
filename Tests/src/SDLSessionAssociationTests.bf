using System;
using System.Windows.Forms;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class SDLSessionAssociationTests
{
	private class CreationProbe : TextBox
	{
		public SDLWindowSession SessionAtCreation;
		public bool HadHandleAtLookup;

		protected internal override void CreateHandle()
		{
			HadHandleAtLookup = IsHandleCreated;
			SessionAtCreation = ((SDLBackend)Application.Backend).GetSession(this);
			base.CreateHandle();
		}
	}

	[Test]
	public static void SessionIsAvailableAcrossTheChildHandleBoundaries()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let editor = new CreationProbe(); editor.Size = .(150, 25);
		let other = new TextBox(); other.Location = .(0, 40); other.Size = editor.Size;
		form.Controls.Add(editor); form.Controls.Add(other);
		let backend = (SDLBackend)Application.Backend;
		Test.Assert(backend.GetSession(editor) == null);
		form.Show(); SDLTestInput.Activate(backend); editor.Focus();
		let session = backend.GetSession(form);
		Test.Assert(!editor.HadHandleAtLookup && editor.SessionAtCreation == session);
		bool sawTeardown = false;
		editor.LostFocus.Add(new [&] (sender, args) =>
		{
			sawTeardown = true;
			Test.Assert(!editor.IsHandleCreated && backend.GetSession(editor) == session);
		});
		editor.DestroyHandle();
		Test.Assert(sawTeardown && backend.GetSession(editor) == session);
		// An ancestry association alone does not make an unrealized editor interactive.
		other.Capture = true;
		editor.Capture = true;
		Test.Assert(!editor.Focus() && !editor.Focused && !editor.Capture && other.Capture);
		other.Capture = false;
		SDLTestInput.AssertNoGLError(form);
	}

	[Test]
	public static void MovingAndDetachingASubtreeUpdatesItsSession()
	{
		Application.UseBackend(.SDL2OpenGL);
		let first = scope Form(); let second = scope Form();
		first.ClientSize = second.ClientSize = .(240, 120);
		let subtree = new Panel(); subtree.Size = .(200, 100);
		defer delete subtree;
		let inner = new Panel(); inner.Size = subtree.Size; subtree.Controls.Add(inner);
		let editor = new TextBox(); editor.Size = .(150, 25); editor.Text = "Move cached text";
		inner.Controls.Add(editor); first.Controls.Add(subtree);
		first.Show(); second.Show(); Application.DoEvents();
		let backend = (SDLBackend)Application.Backend;
		Test.Assert(backend.GetSession(editor) == backend.GetSession(first));
		second.Controls.Add(subtree);
		Test.Assert(editor.IsHandleCreated && backend.GetSession(editor) == backend.GetSession(second));
		Application.DoEvents();
		SDLTestInput.AssertNoGLError(first); SDLTestInput.AssertNoGLError(second);
		second.Controls.Remove(subtree);
		Test.Assert(!editor.IsHandleCreated && subtree.Parent == null && backend.GetSession(editor) == null);
	}

	[Test]
	public static void SessionLookupsStayWithinTheOwningBackend()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let editor = new TextBox(); form.Controls.Add(editor); form.Show();
		let owner = (SDLBackend)Application.Backend;
		let unrelated = scope SDLBackend();
		Test.Assert(owner.GetSession(editor) == owner.GetSession(form));
		Test.Assert(unrelated.GetSession(form) == null && unrelated.GetSession(editor) == null);
	}

	[Test]
	public static void FormAssociationClearsAndCanBeRecreated()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form(); form.ClientSize = .(240, 120); form.Show();
		let backend = (SDLBackend)Application.Backend;
		Test.Assert(form.SDLSession != null && form.SDLSession == backend.GetSession(form));
		form.DestroyHandle();
		Test.Assert(form.SDLSession == null && backend.GetSession(form) == null);
		form.Hide();
		form.Show();
		Test.Assert(form.IsHandleCreated && form.SDLSession != null && form.SDLSession == backend.GetSession(form));
		Application.DoEvents(); SDLTestInput.AssertNoGLError(form);
	}
}
