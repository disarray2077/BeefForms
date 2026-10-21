using System;
using System.Windows.Forms;
using System.Drawing;

namespace BeefForms.Sample;

class DownloaderMockForm : Form
{
	private TextBox mUrl;
	private CheckBox mSaveToFile;
	private Button mDownload, mClearFinished;
	private Label mSummary;
	private Panel mDownloads;
	private int mNextId;

	public this()
	{
		Text = "Beef Async Downloader";
		ClientSize = .(800, 520);
		MinimumSize = .(640, 360);

		let urlLabel = new Label();
		urlLabel.Text = "URL:";
		urlLabel.Location = .(14, 16);
		urlLabel.Size = .(36, 20);
		Controls.Add(urlLabel);

		mUrl = new TextBox();
		mUrl.Text = "https://www.beeflang.org/img/Beef384.png";
		mUrl.Location = .(54, 12);
		mUrl.Size = .(590, 26);
		mUrl.Anchor = .Top | .Left | .Right;
		Controls.Add(mUrl);

		mDownload = new Button();
		mDownload.Text = "Download";
		mDownload.Location = .(654, 11);
		mDownload.Size = .(132, 28);
		mDownload.Anchor = .Top | .Right;
		mDownload.Click.Add(new => OnDownload);
		Controls.Add(mDownload);

		mSaveToFile = new CheckBox();
		mSaveToFile.Text = "Save to file (for inspection)";
		mSaveToFile.Location = .(14, 48);
		mSaveToFile.Size = .(180, 24);
		Controls.Add(mSaveToFile);

		mClearFinished = new Button();
		mClearFinished.Text = "Clear finished";
		mClearFinished.Location = .(660, 47);
		mClearFinished.Size = .(126, 26);
		mClearFinished.Anchor = .Top | .Right;
		mClearFinished.Click.Add(new => OnClearFinished);
		Controls.Add(mClearFinished);

		mSummary = new Label();
		mSummary.Text = "";
		mSummary.Location = .(14, 80);
		mSummary.Size = .(772, 20);
		mSummary.Anchor = .Top | .Left | .Right;
		Controls.Add(mSummary);

		mDownloads = new Panel();
		mDownloads.Location = .(14, 106);
		mDownloads.Size = .(772, 398);
		mDownloads.Anchor = .Top | .Bottom | .Left | .Right;
		mDownloads.AutoScroll = true;
		mDownloads.BorderStyle = .FixedSingle;
		Controls.Add(mDownloads);

		AddDownload("https://www.beeflang.org/img/Beef384.png", "Downloading 256 KB / 1.2 MB", "File: C:\\Downloads\\Beef384.png", 21, true);
		AddDownload("https://example.com/archive.zip", "Completed  4.8 MB", "Memory only (no file)", 100, false);
		AddDownload("https://example.com/missing.dat", "Failed: server returned 404", "Memory only (no file)", 0, false);
		UpdateSummary();
	}

	private void OnDownload(Object sender, EventArgs args)
	{
		if (mUrl.Text.IsEmpty)
			return;

		let path = scope String();
		if (mSaveToFile.Checked)
			path.AppendF("File: C:\\Downloads\\download-{}.bin", mNextId + 1);
		else
			path.Append("Memory only (no file)");

		AddDownload(mUrl.Text, "Connecting...", path, 0, true);
		UpdateSummary();
	}

	private void OnClearFinished(Object sender, EventArgs args)
	{
		for (int i = mDownloads.Controls.Count - 1; i >= 0; i--)
			if (let row = mDownloads.Controls[i] as MockDownloadRow)
				if (row.IsFinished)
				{
					mDownloads.Controls.RemoveAt(i);
					delete row;
				}
		LayoutRows();
		UpdateSummary();
	}

	private void AddDownload(StringView url, StringView status, StringView destination, int progress, bool active)
	{
		mNextId++;
		let row = new MockDownloadRow(this);
		row.SetDownload(mNextId, url, status, destination, progress, active);
		mDownloads.Controls.Add(row);
		LayoutRows();
	}

	private void LayoutRows()
	{
		for (int i = 0; i < mDownloads.Controls.Count; i++)
		{
			let row = mDownloads.Controls[i];
			row.Location = .(8, 8 + (int32)i * 96);
			row.Size = .(mDownloads.ClientSize.width - 16, 90);
			row.Anchor = .Top | .Left | .Right;
		}
	}

	public void UpdateSummary()
	{
		int active = 0, completed = 0, failed = 0, cancelled = 0;
		for (let control in mDownloads.Controls)
			if (let row = control as MockDownloadRow)
				switch (row.State)
				{
				case .Downloading: active++;
				case .Completed: completed++;
				case .Failed: failed++;
				case .Cancelled: cancelled++;
				}
		let summary = scope String();
		summary.AppendF("{} active   |   {} completed   |   {} failed   |   {} cancelled", active, completed, failed, cancelled);
		mSummary.Text = summary;
		mClearFinished.Enabled = completed + failed + cancelled > 0;
	}
}

enum MockDownloadState { Downloading, Completed, Failed, Cancelled }

class MockDownloadRow : Panel
{
	private DownloaderMockForm mOwner;
	private Label mTitle, mStatus, mDestination;
	private ProgressBar mProgress;
	private Button mCancel;
	public MockDownloadState State { get; private set; }
	public bool IsFinished => State != .Downloading;

	public this(DownloaderMockForm owner)
	{
		mOwner = owner;
		BorderStyle = .FixedSingle;
		Size = .(744, 90);

		mTitle = new Label();
		mTitle.AutoEllipsis = true;
		mTitle.Location = .(10, 6);
		mTitle.Size = .(ClientSize.width - 20, 18);
		mTitle.Anchor = .Top | .Left | .Right;
		Controls.Add(mTitle);

		mProgress = new ProgressBar();
		mProgress.Location = .(10, 29);
		mProgress.Size = .(ClientSize.width - 112, 18);
		mProgress.Anchor = .Top | .Left | .Right;
		Controls.Add(mProgress);

		mCancel = new Button();
		mCancel.Text = "Cancel";
		mCancel.Location = .(ClientSize.width - 92, 26);
		mCancel.Size = .(82, 25);
		mCancel.Anchor = .Top | .Right;
		mCancel.Click.Add(new => OnCancel);
		Controls.Add(mCancel);

		mStatus = new Label();
		mStatus.Location = .(10, 51);
		mStatus.Size = .(ClientSize.width - 20, 17);
		mStatus.Anchor = .Top | .Left | .Right;
		Controls.Add(mStatus);

		mDestination = new Label();
		mDestination.AutoEllipsis = true;
		mDestination.Location = .(10, 69);
		mDestination.Size = .(ClientSize.width - 20, 17);
		mDestination.Anchor = .Top | .Left | .Right;
		Controls.Add(mDestination);
	}

	public void SetDownload(int id, StringView url, StringView status, StringView destination, int progress, bool active)
	{
		let title = scope String();
		title.AppendF("#{}  {}", id, url);
		mTitle.Text = title;
		mStatus.Text.Set(status);
		mDestination.Text.Set(destination);
		mProgress.Value = progress;
		if (active)
		{
			mProgress.Style = .Marquee;
			State = .Downloading;
		}
		else if (progress == 100)
			State = .Completed;
		else
			State = .Failed;
		mCancel.Enabled = active;
	}

	private void OnCancel(Object sender, EventArgs args)
	{
		if (State != .Downloading)
			return;
		State = .Cancelled;
		mProgress.Style = .Blocks;
		mProgress.Value = 0;
		mStatus.Text = "Cancelled";
		mCancel.Enabled = false;
		mOwner.UpdateSummary();
	}
}
