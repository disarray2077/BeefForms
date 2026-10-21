using System;
using SDL2;
using BeefForms.Backends;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

static class SDLTestInput
{
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
		SDL.PushEvent(ref input);
		backend.ProcessEvents();
	}

	public static void TypeText(SDLBackend backend, StringView text)
	{
		SDL.Event input = .();
		input.type = .TextInput;
		Internal.MemCpy(&input.text.text, text.Ptr, text.Length);
		SDL.PushEvent(ref input);
		backend.ProcessEvents();
	}
}
