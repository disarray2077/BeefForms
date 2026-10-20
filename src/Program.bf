using System;
using System.Windows.Forms;

namespace BeefForms
{
	class Program
	{
		public static int Main(String[] args)
		{
			Application.EnableVisualStyles();
			Application.SetCompatibleTextRenderingDefault(defaultValue: false);
			Application.Run(new Form());
			return 0;
		}
	}
}