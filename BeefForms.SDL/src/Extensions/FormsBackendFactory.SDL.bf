using internal BeefForms.Backends;

namespace BeefForms.Backends;

extension FormsBackendFactory
{
	public override FormsBackend CreateSDLBackend()
		=> new SDLBackend();
}
