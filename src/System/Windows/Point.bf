#if !BF_PLATFORM_WINDOWS

namespace System.Windows;

[CRepr]
public struct Point : this(int32 x, int32 y)
{
}

#endif
