using System;
using System.Windows.Forms;
using SDL2;
using BeefGL;
using BeefForms.Backends;
using internal BeefForms.Backends;
using internal System.Windows.Forms;

namespace BeefForms.Tests;

static class SDLTestInput
{
	public static void AssertNoGLError(Form form)
	{
		let window = SDL.GL_GetCurrentWindow();
		let context = SDL.GL_GetCurrentContext();
		((SDLBackend)Application.Backend).GetSession(form).MakeCurrent();
		defer { Test.Assert(SDL.GL_MakeCurrent(window, context) == 0); }
		Test.Assert(GL.glGetError() == GL.GL_NO_ERROR);
	}

	public static void SetWindow(ref SDL.Event input, Form form)
	{
		let id = SDL.GetWindowID((SDL.Window*)form.Handle);
		switch (input.type)
		{
		case .WindowEvent: input.window.windowID = id;
		case .KeyDown, .KeyUp: input.key.windowID = id;
		case .TextInput: input.text.windowID = id;
		case .MouseMotion: input.motion.windowID = id;
		case .MouseButtonDown, .MouseButtonUp: input.button.windowID = id;
		case .MouseWheel: input.wheel.windowID = id;
		default:
		}
	}

	public static void PushEvent(ref SDL.Event input, Form form = null)
	{
		let backend = (SDLBackend)Application.Backend;
		let target = form ?? backend.[Friend]mSessions[0].mForm;
		// Preserve explicit IDs, including stale IDs used by routing tests.
		if (SDLBackend.[Friend]EventWindowID(input) == 0) SetWindow(ref input, target);
		SDL.PushEvent(ref input);
	}

	public static void Activate(SDLBackend backend)
	{
		backend.[Friend]RenderIfNeeded();
		backend.ProcessEvents();
		SetActive(backend, true);
	}

	public static void SetActive(SDLBackend backend, bool active)
	{
		SDL.Event input = .();
		input.type = .WindowEvent;
		input.window.windowEvent = active ? .FocusGained : .Focus_lost;
		PushEvent(ref input);
		backend.ProcessEvents();
	}

	public static void TypeText(SDLBackend backend, StringView text)
	{
		SDL.Event input = .();
		input.type = .TextInput;
		Internal.MemCpy(&input.text.text, text.Ptr, text.Length);
		PushEvent(ref input);
		backend.ProcessEvents();
	}
}
