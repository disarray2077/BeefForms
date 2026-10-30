#if !BF_PLATFORM_WASM
using System;

namespace BeefForms.Backends;

internal static class DefaultIcon
{
	public const uint8[?] Data = Compiler.ReadBinary(scope $"{Compiler.ProjectDir}/Resources/BeefForms.png");
}
#endif
