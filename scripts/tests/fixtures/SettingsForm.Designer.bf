namespace BeefForms.Sample;

extension SettingsForm
{
    private void InitializeComponent()
    {
        this.panel = new System.Windows.Forms.Panel();
        this.caption = new System.Windows.Forms.Label();
        this.save = new System.Windows.Forms.Button();
        this.panel.SuspendLayout();
        this.SuspendLayout();
        this.caption.AutoSize = true;
        this.caption.Location = System.Drawing.Point(12, 12);
        this.caption.Text = "Preferences";
        this.save.Anchor = ((System.Windows.Forms.AnchorStyles)(System.Windows.Forms.AnchorStyles.Bottom | System.Windows.Forms.AnchorStyles.Right));
        this.save.Font = new System.Drawing.Font("Segoe UI", 9F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point);
        this.save.Location = System.Drawing.Point(200, 120);
        this.save.Size = System.Drawing.Size(80, 24);
        this.save.Text = "Save";
        this.save.Click += new => this.Save_Click;
        this.panel.Controls.Add(this.caption);
        this.panel.Controls.Add(this.save);
        this.panel.Size = System.Drawing.Size(300, 160);
        this.AutoScaleDimensions = System.Drawing.SizeF(7F, 15F);
        this.ClientSize = System.Drawing.Size(300, 160);
        this.Controls.Add(this.panel);
        this.Text = "Settings";
        this.Load += new => this.Settings_Load;
        this.panel.ResumeLayout(false);
        this.panel.PerformLayout();
        this.ResumeLayout(false);
    }

    private System.Windows.Forms.Panel panel;
    private System.Windows.Forms.Label caption;
    private System.Windows.Forms.Button save;
}
