using System.Collections;

using internal System.Windows.Forms;

namespace System.Windows.Forms;

/// A live, read-only view of the application's loaded forms.
public class FormCollection : IEnumerable<Form>
{
	private append List<Form> mForms = .();

	public this()
	{
	}

	internal bool IsEmpty => mForms.IsEmpty;
	internal Form Back => mForms.Back;

	internal void Add(Form form)
	{
		if (!mForms.Contains(form))
			mForms.Add(form);
	}

	internal void Remove(Form form)
	{
		mForms.Remove(form);
	}

	public int Count => mForms.Count;
	public Form this[int index] => mForms[index];
	public Form this[StringView name]
	{
		get
		{
			if (name.IsNull)
				return null;
			for (let form in mForms)
			{
				if (form.Name.Equals(name, true))
					return form;
			}
			return null;
		}
	}

	public Enumerator GetEnumerator()
		=> .(mForms);

	public struct Enumerator : IEnumerator<Form>
	{
		private List<Form>.Enumerator mEnumerator;

		internal this(List<Form> forms)
		{
			mEnumerator = forms.GetEnumerator();
		}

		public Result<Form> GetNext() mut
			=> mEnumerator.GetNext();
	}
}
