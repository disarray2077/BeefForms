using BeefForms.Backends;

using internal BeefForms.Backends;

namespace System.Windows.Forms;

extension Form
{
	// Borrowed from SDLBackend's owning session collection; valid during handle teardown.
	internal SDLWindowSession SDLSession;
}
