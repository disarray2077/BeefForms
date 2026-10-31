mergeInto(LibraryManager.library, {
  $BeefFormsTextEditor: {
    binding: null,
    panel: null,
    close: function() {
      var panel = BeefFormsTextEditor.panel;
      if (!panel) return;
      BeefFormsTextEditor.panel = null;
      if (window.visualViewport) {
        window.visualViewport.removeEventListener('resize', panel.resize);
        window.visualViewport.removeEventListener('scroll', panel.resize);
      }
      panel.root.remove();
    }
  },
  BeefForms_InstallTextEditor__deps: ['$BeefFormsTextEditor'],
  BeefForms_InstallTextEditor: function(context, open, done, cancel) {
    var canvas = Module['canvas'];
    if (BeefFormsTextEditor.binding) {
      canvas.removeEventListener('pointerdown', BeefFormsTextEditor.binding.down, true);
      canvas.removeEventListener('pointerup', BeefFormsTextEditor.binding.up, true);
      canvas.removeEventListener('pointercancel', BeefFormsTextEditor.binding.cancelPointer, true);
      BeefFormsTextEditor.close();
    }
    var binding = { context: context, done: done, cancel: cancel, pointer: null };
    binding.down = function(event) {
      if (!event.isPrimary || event.pointerType !== 'touch') return;
      binding.pointer = { id: event.pointerId, x: event.clientX, y: event.clientY };
    };
    binding.cancelPointer = function() {
      binding.pointer = null;
    };
    binding.up = function(event) {
      var pointer = binding.pointer;
      binding.pointer = null;
      if (!pointer || pointer.id !== event.pointerId || !event.isTrusted ||
          Math.hypot(event.clientX - pointer.x, event.clientY - pointer.y) > 12) return;
      var rect = canvas.getBoundingClientRect();
      if (!rect.width || !rect.height) return;
      // Focus must stay in the trusted tap callback, before the next Wasm frame.
      {{{ makeDynCall('viff', 'open') }}}(context,
        (event.clientX - rect.left) / rect.width, (event.clientY - rect.top) / rect.height);
    };
    BeefFormsTextEditor.binding = binding;
    canvas.addEventListener('pointerdown', binding.down, true);
    canvas.addEventListener('pointerup', binding.up, true);
    canvas.addEventListener('pointercancel', binding.cancelPointer, true);
  },
  BeefForms_UninstallTextEditor__deps: ['$BeefFormsTextEditor'],
  BeefForms_UninstallTextEditor: function(context) {
    var binding = BeefFormsTextEditor.binding;
    if (!binding || binding.context !== context) return;
    var canvas = Module['canvas'];
    canvas.removeEventListener('pointerdown', binding.down, true);
    canvas.removeEventListener('pointerup', binding.up, true);
    canvas.removeEventListener('pointercancel', binding.cancelPointer, true);
    BeefFormsTextEditor.close();
    BeefFormsTextEditor.binding = null;
  },
  BeefForms_CloseTextEditor__deps: ['$BeefFormsTextEditor'],
  BeefForms_CloseTextEditor: function() {
    BeefFormsTextEditor.close();
  },
  BeefForms_OpenTextEditor__deps: ['$BeefFormsTextEditor', '$UTF8ToString', '$lengthBytesUTF8', '$stringToUTF8', 'malloc', 'free'],
  BeefForms_OpenTextEditor: function(text, multiline, start, length) {
    BeefFormsTextEditor.close();
    var binding = BeefFormsTextEditor.binding;
    if (!binding) return;
    var root = document.createElement('dialog');
    root.style.cssText = 'position:fixed;inset:0;margin:0;border:0;width:100%;max-width:none;height:100%;max-height:none;box-sizing:border-box;padding:16px;background:#0009;display:flex;align-items:flex-start;justify-content:center;overflow:auto;';
    var dialog = document.createElement('section');
    dialog.setAttribute('role', 'dialog');
    dialog.setAttribute('aria-modal', 'true');
    dialog.setAttribute('aria-label', 'Edit text');
    dialog.style.cssText = 'box-sizing:border-box;width:100%;max-width:40rem;padding:16px;border-radius:8px;background:white;color:#111;font:16px system-ui;';
    var label = document.createElement('label');
    label.textContent = 'Edit text';
    label.style.cssText = 'display:block;';
    var input = document.createElement(multiline ? 'textarea' : 'input');
    if (!multiline) input.type = 'text';
    var original = UTF8ToString(text);
    input.value = original;
    input.style.cssText = 'box-sizing:border-box;display:block;width:100%;margin:12px 0;padding:8px;font:16px system-ui;';
    if (multiline) input.rows = 5;
    label.appendChild(input);
    dialog.appendChild(label);
    var doneButton = document.createElement('button');
    doneButton.type = 'button';
    doneButton.textContent = 'Done';
    var cancelButton = document.createElement('button');
    cancelButton.type = 'button';
    cancelButton.textContent = 'Cancel';
    [doneButton, cancelButton].forEach(function(button) {
      button.style.cssText = 'min-height:44px;min-width:80px;margin-right:8px;font:16px system-ui;';
      dialog.appendChild(button);
    });
    root.appendChild(dialog);
    var panel = { root: root, composing: false };
    panel.resize = function() {
      var viewport = window.visualViewport;
      if (!viewport) return;
      root.style.top = viewport.offsetTop + 'px';
      root.style.height = viewport.height + 'px';
      root.style.bottom = 'auto';
    };
    function finish(commit) {
      if (BeefFormsTextEditor.panel !== panel || (commit && panel.composing)) return;
      var value = input.value;
      BeefFormsTextEditor.close();
      if (commit) {
        var size = lengthBytesUTF8(value) + 1;
        var buffer = _malloc(size);
        try {
          stringToUTF8(value, buffer, size);
          {{{ makeDynCall('vii', 'binding.done') }}}(binding.context, buffer);
        } finally {
          _free(buffer);
        }
      } else {
        {{{ makeDynCall('vi', 'binding.cancel') }}}(binding.context);
      }
      if (!BeefFormsTextEditor.panel && BeefFormsTextEditor.binding === binding) {
        Module['canvas'].focus({ preventScroll: true });
      }
    }
    doneButton.addEventListener('click', function() { finish(true); });
    cancelButton.addEventListener('click', function() { finish(false); });
    root.addEventListener('cancel', function(event) {
      event.preventDefault();
      finish(false);
    });
    input.addEventListener('compositionstart', function() { panel.composing = true; });
    input.addEventListener('compositionend', function() { panel.composing = false; });
    root.addEventListener('keydown', function(event) {
      if (event.key === 'Escape' && !event.isComposing) {
        event.preventDefault();
        finish(false);
      }
    });
    // Keep browser editing events out of SDL's window-level keyboard listeners.
    ['keydown', 'keyup', 'keypress', 'input', 'beforeinput', 'compositionstart', 'compositionend',
      'pointerdown', 'pointerup', 'touchstart', 'touchend', 'mousedown', 'mouseup', 'click'].forEach(function(type) {
      root.addEventListener(type, function(event) { event.stopPropagation(); });
    });
    BeefFormsTextEditor.panel = panel;
    document.body.appendChild(root);
    root.showModal();
    if (window.visualViewport) {
      window.visualViewport.addEventListener('resize', panel.resize);
      window.visualViewport.addEventListener('scroll', panel.resize);
      panel.resize();
    }
    input.focus({ preventScroll: true });
    var selectionStart = original.slice(0, start).replace(/\r\n/g, '\n').length;
    var selectionEnd = original.slice(0, start + length).replace(/\r\n/g, '\n').length;
    input.setSelectionRange(selectionStart, selectionEnd);
  }
});
