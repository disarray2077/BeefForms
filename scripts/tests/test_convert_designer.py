import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
from convert_designer import ConversionError, convert, main, tokenize


def designer(body, fields='', namespace='Example'):
    return f'namespace {namespace} {{ partial class Demo {{ private void InitializeComponent() {{ {body} }} {fields} }} }}'


class DesignerConversionTests(unittest.TestCase):
    def test_settings_form_matches_expected_beef(self):
        source = (SCRIPTS / 'tests/fixtures/SettingsForm.Designer.cs').read_text(encoding='utf-8-sig')
        expected = (SCRIPTS / 'tests/fixtures/SettingsForm.Designer.bf').read_text(encoding='utf-8-sig')
        result = convert(source, namespace='BeefForms.Sample')
        # Ignore formatting/comments, but compare every code and literal token.
        self.assertEqual([t.text for t in tokenize(result.code)], [t.text for t in tokenize(expected)])
        self.assertTrue(any('custom cleanup' in warning for warning in result.warnings))

    def test_strings_and_comments_are_not_treated_as_code(self):
        source = designer(r'this.Text = "new System.Drawing.Size(1, 2); Click += OnClick; }"; // new Point(0, 0)\n')
        # The line comment must end before the generated closing braces.
        source = source.replace(r'\n', '\n')
        output = convert(source).code
        self.assertIn('"new System.Drawing.Size(1, 2); Click += OnClick; }"', output)
        self.assertIn('// new Point(0, 0)', output)

    def test_event_constructors_and_method_groups(self):
        output = convert(designer('this.Load += new System.EventHandler(this.OnLoad); button.Click += OnClick; button.Click -= this.OnClick;')).code
        self.assertIn('this.Load += new => this.OnLoad;', output)
        self.assertIn('button.Click += new => OnClick;', output)
        self.assertIn('button.Click -= new => this.OnClick;', output)

    def test_value_types_and_heap_objects(self):
        output = convert(designer('button = new System.Windows.Forms.Button(); button.Font = new System.Drawing.Font("Segoe UI", 9F); button.Size = new System.Drawing.Size(30, 20); Location = new Point(1, 2);')).code
        self.assertIn('new System.Windows.Forms.Button()', output)
        self.assertIn('new System.Drawing.Font("Segoe UI", 9F)', output)
        self.assertIn('button.Size = System.Drawing.Size(30, 20)', output)
        self.assertIn('Location = Point(1, 2)', output)

    def test_modern_namespace_global_alias_and_target_typed_new(self):
        source = 'using System.Windows.Forms;\nnamespace Example;\npartial class Demo { void InitializeComponent() { button = new(); this.Size = new(10, 20); point = new global::System.Drawing.Point(1, 2); } }'
        output = convert(source, namespace='Target.Forms').code
        self.assertIn('using System.Windows.Forms;', output)
        self.assertIn('namespace Target.Forms;', output)
        self.assertIn('extension Demo', output)
        self.assertIn('button = new .();', output)
        self.assertIn('this.Size = .(10, 20);', output)
        self.assertIn('point = System.Drawing.Point(1, 2);', output)

    def test_components_and_dispose_are_removed_with_warning(self):
        source = designer('this.components = new System.ComponentModel.Container(); this.Text = "components";', 'private System.ComponentModel.IContainer components = null; protected override void Dispose(bool disposing) { if (disposing) { components.Dispose(); timer.Dispose(); } base.Dispose(disposing); }')
        result = convert(source)
        self.assertNotIn('IContainer', result.code)
        self.assertNotIn('Dispose(', result.code)
        self.assertNotIn('new System.ComponentModel.Container', result.code)
        self.assertIn('"components"', result.code)
        self.assertEqual(len(result.warnings), 1)

    def test_controls_add_range_preserves_order_and_parent(self):
        output = convert(designer('this.panel.Controls.AddRange(new System.Windows.Forms.Control[] { this.second, this.first });')).code
        self.assertIn('this.panel.Controls.Add(this.second);', output)
        self.assertIn('this.panel.Controls.Add(this.first);', output)
        self.assertLess(output.index('Add(this.second)'), output.index('Add(this.first)'))
        self.assertNotIn('AddRange', output)

    def test_verbatim_and_unicode_strings(self):
        output = convert(designer(r'this.Text = @"C:\new\folder ""quoted"""; this.Name = "\u00e9\x41\U0001F600";')).code
        self.assertIn(r'"C:\\new\\folder \"quoted\""', output)
        self.assertIn(r'"\u{00e9}\u{41}\u{0001F600}"', output)

    def test_resource_code_is_reported_and_retained(self):
        result = convert(designer('var resources = new System.ComponentModel.ComponentResourceManager(typeof(Demo)); this.Icon = (System.Drawing.Icon)resources.GetObject("$this.Icon");'))
        self.assertTrue(any('Resource loading' in warning for warning in result.warnings))
        self.assertIn('resources.GetObject("$this.Icon")', result.code)

    def test_utf16_surrogate_pairs_become_one_unicode_escape(self):
        output = convert(designer(r'this.Text = "\uD83D\uDE00";')).code
        self.assertIn(r'"\u{1F600}"', output)
        with self.assertRaisesRegex(ConversionError, 'Unpaired UTF-16'):
            convert(designer(r'this.Text = "\uD83D";'))

    def test_rejects_unsupported_event_expression(self):
        with self.assertRaisesRegex(ConversionError, 'named handler'):
            convert(designer('this.Load += (sender, args) => { this.Text = "x"; };'))

    def test_rejects_ambiguous_or_malformed_class(self):
        for source in ('class Demo {}', 'partial class A {} partial class B {}', 'partial class A {} class B {}', 'partial class Demo { void InitializeComponent() {'):
            with self.subTest(source=source), self.assertRaises(ConversionError):
                convert(source)

    def test_comment_cannot_inject_using_directives(self):
        output = convert('/*\nusing Fake.Type;\n*/\n' + designer('')).code
        self.assertNotIn('using Fake.Type;', output)

    def test_cli_never_overwrites_without_force(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'Demo.Designer.cs'
            output = source.with_suffix('.bf')
            source.write_text(designer('this.Text = "first";'), encoding='utf-8')
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(main([str(source)]), 0)
                original = output.read_text(encoding='utf-8')
                source.write_text(designer('this.Text = "second";'), encoding='utf-8')
                self.assertEqual(main([str(source)]), 1)
                self.assertEqual(output.read_text(encoding='utf-8'), original)
                self.assertEqual(main([str(source), '--force']), 0)
                self.assertIn('"second"', output.read_text(encoding='utf-8'))
                self.assertEqual(main([str(source), '-o', str(source), '--force']), 1)


if __name__ == '__main__':
    unittest.main()
