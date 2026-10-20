namespace System.ComponentModel;

public interface ISite
{
    IComponent Component { get; }
    IContainer Container { get; }
    bool DesignMode { get; }
    String Name { get; set; }
}