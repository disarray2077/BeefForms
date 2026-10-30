using System.Collections;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

extension Form
{
	private Form mOwner;
	private append List<Form> mOwnedForms = .();
	private bool mDisposingOwnership;

	public ~this()
	{
		if (!IsDisposed)
			Dispose();
		if (IsHandleCreated)
			DestroyHandle();
		DetachOwnership();
	}

	// Window ownership does not transfer ownership of the Beef allocations.
	public Form Owner
	{
		get => mOwner;
		set
		{
			if (mOwner == value)
				return;
			if (value != null && Parent != null)
				Runtime.FatalError("A child form cannot have an owner");
			for (var owner = value; owner != null; owner = owner.mOwner)
			{
				if (owner == this || Control.IsAncestorOf(this, owner))
					Runtime.FatalError("Form ownership cannot contain a cycle");
			}
			VerifyThreadAccess();
			value?.VerifyThreadAccess();
			mOwner?.mOwnedForms.Remove(this);
			mOwner = value;
			value?.mOwnedForms.Add(this);
			if (IsHandleCreated)
				Application.Backend.SetOwner(this, value);
		}
	}

	public void Show(Control owner)
	{
		if (owner == this)
			Runtime.FatalError("A form cannot own itself");
		if (Visible || !Enabled || Parent != null || mClosed || IsDisposingOrDisposed)
			Runtime.FatalError("Show(owner) requires a hidden, enabled top-level form that has not been closed or disposed");
		if (owner != null)
		{
			var root = owner;
			while (root.Parent != null)
				root = root.Parent;
			let form = root as Form;
			if (form == null)
				Runtime.FatalError("An owner control must belong to a form");
			Owner = form;
		}
		Show();
	}

	protected internal override void CreateHandle()
	{
		if (IsDisposed || IsHandleCreated)
		{
			base.CreateHandle();
			return;
		}
		mOwner?.CreateHandle();
		base.CreateHandle();
		if (!IsHandleCreated || IsDisposingOrDisposed)
			return;
		Application.Backend.SetOwner(this, mOwner);
		UpdateOwnedWindowOwners(this);
	}

	protected internal override void DestroyHandle()
	{
		if (IsHandleCreated)
		{
			// Keep owned windows alive while this form's handle is destroyed or recreated.
			UpdateOwnedWindowOwners(null);
		}
		base.DestroyHandle();
	}

	private void UpdateOwnedWindowOwners(Form owner)
	{
		let owned = ToScopedArray!(mOwnedForms);
		for (let form in owned)
		{
			if (mOwnedForms.Contains(form) && form.mOwner == this && form.IsHandleCreated)
				Application.Backend.SetOwner(form, owner);
		}
	}

	protected override void Dispose(bool disposing)
	{
		if (!disposing)
		{
			base.Dispose(disposing);
			return;
		}
		if (mDisposingOwnership)
			return;
		mDisposingOwnership = true;
		defer { mDisposingOwnership = false; }
		Owner = null;
		while (!mOwnedForms.IsEmpty)
		{
			let form = mOwnedForms.PopBack();
			form.mOwner = null;
			if (!form.Disposing)
				form.Dispose();
		}
		base.Dispose(disposing);
	}

	private void DetachOwnership()
	{
		Owner = null;
		while (!mOwnedForms.IsEmpty)
			mOwnedForms.Back.Owner = null;
	}

	private void NotifyOwnedClosing(FormClosingEventArgs args, bool onlyUnregistered = false)
	{
		let owned = ToScopedArray!(mOwnedForms);
		for (int i = owned.Count - 1; i >= 0; i--)
		{
			let form = owned[i];
			if (!mOwnedForms.Contains(form) || form.mOwner != this || form.mClosed || form.IsDisposingOrDisposed)
				continue;
			if (onlyUnregistered && Application.OpenForms.Contains(form))
				continue;
			let closing = scope FormClosingEventArgs(.FormOwnerClosing, args.Cancel);
			form.OnFormClosing(closing);
			if (closing.Cancel)
			{
				args.Cancel = true;
				break;
			}
		}
	}

	private void NotifyOwnedClosed(bool onlyUnregistered = false)
	{
		let owned = ToScopedArray!(mOwnedForms);
		for (int i = owned.Count - 1; i >= 0; i--)
		{
			let form = owned[i];
			if (!mOwnedForms.Contains(form) || form.mOwner != this || form.mClosed || form.IsDisposingOrDisposed)
				continue;
			if (onlyUnregistered && Application.OpenForms.Contains(form))
				continue;
			form.CompleteClose(.FormOwnerClosing);
		}
	}
}
