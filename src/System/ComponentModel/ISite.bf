namespace System.ComponentModel;

public interface ISite
{
    IComponent Component { get; }
    IContainer Container { get; }
    bool DesignMode { get; }
    StringView Name { get; set; }
}
