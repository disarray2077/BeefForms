using System;
using System.Collections;
using System.Threading;
using System.Windows.Forms;

using internal System.Windows.Forms;

namespace BeefForms.Tests;

class DeferredDeletionTests
{
	private class Record
	{
		public int Deletes, Disposals, Calls, DeleteThread;
	}

	private class TrackedButton : Button
	{
		private Record mRecord;
		public delegate void() OnDelete ~ delete _;

		public this(Record record)
		{
			mRecord = record;
		}

		public ~this()
		{
			mRecord.Deletes++;
			mRecord.DeleteThread = Thread.CurrentThreadId;
			OnDelete?.Invoke();
		}
	}

	private class TrackedPanel : Panel
	{
		private Record mRecord;

		public this(Record record)
		{
			mRecord = record;
		}

		public ~this()
		{
			mRecord.Deletes++;
		}
	}

	private class TrackedForm : Form
	{
		private Record mRecord;
		public delegate void() OnDelete ~ delete _;

		public this(Record record)
		{
			mRecord = record;
		}

		public ~this()
		{
			mRecord.Deletes++;
			OnDelete?.Invoke();
		}
	}

	private static void RunCase(delegate void(Form) action)
	{
		let form = new Form();
		form.Load.Add(new (sender, args) => form.BeginInvoke(new () =>
		{
			action(form);
			form.Close();
		}).ReturnValueDiscarded());
		Application.Run(form);
	}

	private static void VerifyNestedPumpsAndRepeatedRequests()
	{
		let record = scope Record();
		RunCase(scope (form) =>
		{
			let button = new TrackedButton(record);
			form.Controls.Add(button);
			button.Disposed.Add(new (sender, args) => record.Disposals++);
			button.Click.Add(new (sender, args) =>
			{
				button.DeleteLater();
				button.DeleteLater();
				Test.Assert(!button.IsDisposed && button.Parent == form);
				Test.Assert(form.Invoke(scope () =>
				{
					Application.DoEvents();
					Test.Assert(record.Deletes == 0 && !button.IsDisposed);
				}) case .Ok);
				Application.DoEvents();
				Test.Assert(record.Deletes == 0);
			});
			button.Click.Add(new (sender, args) =>
			{
				record.Calls++;
				Test.Assert(record.Deletes == 0);
			});
			button.PerformClick();
			Test.Assert(record.Calls == 1 && record.Deletes == 0);
		});
		Test.Assert(record.Deletes == 1 && record.Disposals == 1);
	}

	private static void VerifyCancellationDuringShutdown()
	{
		let record = scope Record();
		let cancelled = scope Record();
		let formRecord = scope Record();
		let disposalRequest = scope Record();
		let form = new TrackedForm(formRecord);
		let duringDisposal = new TrackedButton(disposalRequest);
		let other = new TrackedButton(cancelled);
		defer delete other;
		form.Disposed.Add(new (sender, args) =>
		{
			let worker = scope Thread(new () => duringDisposal.DeleteLater());
			worker.Start(false);
			Test.Assert(worker.Join(3000));
		});
		form.OnDelete = new () =>
		{
			let worker = scope Thread(new () => other.DeleteLater());
			worker.Start(false);
			Test.Assert(worker.Join(3000));
			Application.Dispatcher.Post(new () => cancelled.Calls++
			~
			{
				cancelled.Disposals++;
				other.DeleteLater();
				Application.DoEvents();
				Test.Assert(cancelled.Deletes == 0);
			});
		};
		form.Load.Add(new (sender, args) => form.BeginInvoke(new () =>
		{
			let button = new TrackedButton(record);
			button.DeleteLater();
			form.Close();
			Test.Assert(record.Deletes == 0 && cancelled.Deletes == 0);
		}).ReturnValueDiscarded());
		Application.Run(form);
		Test.Assert(formRecord.Deletes == 1 && record.Deletes == 1);
		Test.Assert(disposalRequest.Deletes == 1);
		Test.Assert(record.Calls == 0 && cancelled.Calls == 0);
		Test.Assert(cancelled.Disposals == 1);
		RunCase(scope (nextForm) => Test.Assert(cancelled.Deletes == 0));
		Test.Assert(cancelled.Deletes == 0);
	}

	private static void VerifyParentOwnershipAndExplicitDeletion()
	{
		let parentRecord = scope Record();
		let childRecord = scope Record();
		RunCase(scope (form) =>
		{
			let parent = new TrackedPanel(parentRecord);
			let child = new TrackedButton(childRecord);
			parent.Controls.Add(child);
			parent.DeleteLater();
			child.DeleteLater();
		});
		Test.Assert(parentRecord.Deletes == 1 && childRecord.Deletes == 1);
		RunCase(scope (form) =>
		{
			let parent = new TrackedPanel(parentRecord);
			let child = new TrackedButton(childRecord);
			parent.Controls.Add(child);
			child.DeleteLater();
			delete parent;
			Test.Assert(parentRecord.Deletes == 2 && childRecord.Deletes == 2);
		});
		RunCase(scope (form) =>
		{
			let first = scope Panel();
			let second = scope Panel();
			let child = new TrackedButton(childRecord);
			first.Controls.Add(child);
			child.DeleteLater();
			second.Controls.Add(child);
			delete child;
		});
		Test.Assert(childRecord.Deletes == 3);
	}

	private static void VerifyQueueRemovalAndOrder()
	{
		let record = scope Record();
		let order = scope List<int>();
		RunCase(scope (form) =>
		{
			TrackedButton[5] buttons = default;
			for (int i < buttons.Count)
			{
				let ordinal = i;
				let button = new TrackedButton(record);
				button.OnDelete = new () => order.Add(ordinal);
				buttons[i] = button;
				button.DeleteLater();
				button.DeleteLater();
			}
			delete buttons[0];
			delete buttons[2];
			delete buttons[4];
		});
		Test.Assert(record.Deletes == 5 && order.Count == 5);
		int[5] expected = .(0, 2, 4, 1, 3);
		for (int i < expected.Count)
			Test.Assert(order[i] == expected[i]);
		RunCase(scope (form) =>
		{
			let only = new TrackedButton(record);
			only.DeleteLater();
			delete only;
			let next = new TrackedButton(record);
			next.DeleteLater();
		});
		Test.Assert(record.Deletes == 7);
		RunCase(scope (form) =>
		{
			for (int i < 1024)
			{
				let ordinal = i;
				let button = new TrackedButton(record);
				button.OnDelete = new () =>
				{
					Test.Assert(record.Calls == ordinal);
					record.Calls++;
				};
				button.DeleteLater();
			}
		});
		Test.Assert(record.Calls == 1024 && record.Deletes == 1031);
	}

	private static void VerifyReentrantDeletion()
	{
		let record = scope Record();
		let form = new Form();
		form.Load.Add(new (sender, args) => form.BeginInvoke(new () =>
		{
			let first = new TrackedButton(record);
			let second = new TrackedButton(record);
			second.OnDelete = new () => form.Close();
			first.OnDelete = new () =>
			{
				let worker = scope Thread(new () => second.DeleteLater());
				worker.Start(false);
				Test.Assert(worker.Join(3000));
				Application.DoEvents();
				Test.Assert(record.Deletes == 1);
			};
			first.DeleteLater();
		}).ReturnValueDiscarded());
		Application.Run(form);
		Test.Assert(record.Deletes == 2);
	}

	private static void VerifyMainFormAndStoppedLoop()
	{
		let record = scope Record();
		let form = new TrackedForm(record);
		form.Load.Add(new (sender, args) =>
		{
			form.DeleteLater();
			Application.DoEvents();
			Test.Assert(record.Deletes == 0 && !form.IsDisposed);
		});
		Application.Run(form);
		Test.Assert(record.Deletes == 1 && Application.OpenForms.Count == 0);
		let button = new TrackedButton(record);
		let worker = scope Thread(new () => button.DeleteLater());
		worker.Start(false);
		worker.Join();
		button.DeleteLater();
		Application.DoEvents();
		Test.Assert(record.Deletes == 1 && !button.IsDisposed);
		delete button;
		Test.Assert(record.Deletes == 2);
	}

	private static void VerifyConcurrentWorkerRequests()
	{
		let record = scope Record();
		let uiThread = Thread.CurrentThreadId;
		RunCase(scope (form) =>
		{
			let button = new TrackedButton(record);
			form.Controls.Add(button);
			button.Disposed.Add(new (sender, args) =>
			{
				record.Disposals++;
				Test.Assert(Thread.CurrentThreadId == uiThread);
			});
			Thread[4] workers = default;
			for (int i < workers.Count)
			{
				workers[i] = new Thread(new () =>
				{
					for (int request < 128)
						button.DeleteLater();
					Test.Assert(!Application.DispatcherCore.CheckAccess);
				});
				workers[i].Start(false);
			}
			for (let worker in workers)
			{
				worker.Join();
				delete worker;
			}
			Application.DoEvents();
			Test.Assert(record.Deletes == 0 && !button.IsDisposed);
		});
		Test.Assert(record.Deletes == 1 && record.Disposals == 1 && record.DeleteThread == uiThread);
	}

	private static void VerifyWorkerWakesHostLoop()
	{
		let record = scope Record();
		let ready = scope WaitEvent();
		let form = new Form();
		let button = new TrackedButton(record);
		form.Controls.Add(button);
		button.OnDelete = new () => form.Close();
		let worker = scope Thread(new () =>
		{
			Test.Assert(ready.WaitFor(3000));
			Thread.Sleep(25);
			button.DeleteLater();
		});
		bool timedOut = false;
		let watchdog = scope System.Windows.Forms.Timer();
		watchdog.Interval = 3000;
		watchdog.Tick.Add(new [&] (sender, args) =>
		{
			timedOut = true;
			form.Close();
		});
		form.Load.Add(new (sender, args) =>
		{
			watchdog.Start();
			worker.Start(false);
			form.BeginInvoke(new () => ready.Set(true));
		});
		Application.Run(form);
		watchdog.Stop();
		worker.Join();
		Test.Assert(!timedOut && record.Deletes == 1 && record.DeleteThread == Thread.CurrentThreadId);
	}

	private static void VerifyWorkersRacingLoopShutdown()
	{
		Record[64] records = default;
		TrackedButton[64] buttons = default;
		int[64] deletedAtStop = default;
		for (int i < records.Count)
		{
			records[i] = new Record();
			buttons[i] = new TrackedButton(records[i]);
		}
		let started = scope WaitEvent();
		let worker = scope Thread(new [&] () =>
		{
			for (int i < buttons.Count)
			{
				buttons[i].DeleteLater();
				if (i == 0)
					started.Set(true);
				Thread.Sleep(0);
			}
		});
		let form = new Form();
		form.Load.Add(new (sender, args) =>
		{
			worker.Start(false);
			Test.Assert(started.WaitFor(3000));
			form.Close();
		});
		Application.Run(form);
		worker.Join();
		for (int i < records.Count)
		{
			deletedAtStop[i] = records[i].Deletes;
			Test.Assert(deletedAtStop[i] <= 1);
			if (deletedAtStop[i] == 1)
				Test.Assert(records[i].DeleteThread == Thread.CurrentThreadId);
		}
		RunCase(scope (next) => next.Close());
		for (int i < records.Count)
		{
			Test.Assert(records[i].Deletes == deletedAtStop[i]);
			if (deletedAtStop[i] == 0)
				delete buttons[i];
			delete records[i];
		}
	}

	private static void Verify(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		VerifyNestedPumpsAndRepeatedRequests();
		VerifyCancellationDuringShutdown();
		VerifyParentOwnershipAndExplicitDeletion();
		VerifyQueueRemovalAndOrder();
		VerifyReentrantDeletion();
		VerifyConcurrentWorkerRequests();
		VerifyWorkerWakesHostLoop();
		VerifyWorkersRacingLoopShutdown();
		VerifyMainFormAndStoppedLoop();
	}

#if BF_PLATFORM_WINDOWS
	[Test]
	public static void Win32DeferredDeletion()
	{
		Verify(.Win32);
	}
#endif

#if BF_DEPENDS_BEEFFORMS_SDL
	[Test]
	public static void SDLDeferredDeletion()
	{
		Verify(.SDL2OpenGL);
	}
#endif
}
