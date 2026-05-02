import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/note_model.dart';
import '../../../ui_kit/theme/app_colors.dart';
import '../../../ui_kit/theme/typography.dart';
import '../application/notes_controller.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;
  const NoteEditorScreen({super.key, this.noteId});
  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  QuillController? _controller;
  FocusNode? _focusNode;
  Timer? _autoSaveTimer;
  StreamSubscription? _changesSubscription;
  String? _noteId;
  String? _lastSavedJson;
  String? _error;
  bool _isSaving = false;
  bool _toolbarExpanded = true;
  int _wordCount = 0;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      NoteModel? note;
      if (widget.noteId != null) {
        note = await ref.read(localNoteRepositoryProvider).getNote(widget.noteId!);
      }
      note ??= await ref.read(notesControllerProvider.notifier).createDraft();
      if (!mounted) return;
      _noteId = note.id;
      _lastSavedJson = note.documentJson;
      _controller = QuillController(
        document: _docFromJson(note.documentJson),
        selection: const TextSelection.collapsed(offset: 0),
      );
      _changesSubscription = _controller!.document.changes.listen((_) {
        _scheduleAutoSave();
        _updateCounts();
      });
      _updateCounts();
      setState(() {});
    } catch (e, st) {
      debugPrint('NoteEditor error: $e\n$st');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Document _docFromJson(String json) {
    try { return Document.fromJson(jsonDecode(json) as List<dynamic>); }
    catch (_) { return Document()..insert(0, '\n'); }
  }

  void _updateCounts() {
    if (_controller == null) return;
    final text = _controller!.document.toPlainText().trimRight();
    setState(() {
      _charCount = text.length;
      _wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    });
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 900), _save);
    if (mounted) setState(() => _isSaving = true);
  }

  Future<void> _save() async {
    final ctrl = _controller; final nid = _noteId;
    if (ctrl == null || nid == null) return;
    final json = jsonEncode(ctrl.document.toDelta().toJson());
    if (json == _lastSavedJson) { if (mounted) setState(() => _isSaving = false); return; }
    await ref.read(notesControllerProvider.notifier).saveNote(id: nid, documentJson: json);
    _lastSavedJson = json;
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel(); _changesSubscription?.cancel();
    _controller?.dispose(); _focusNode?.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    final ctrl = _controller;

    if (_error != null) return Center(child: Text('Error: $_error', style: TextStyle(color: c.error)));
    if (ctrl == null) return Center(child: CircularProgressIndicator(color: c.primary));

    return Column(children: [
      Expanded(child: _EditorCanvas(
        controller: ctrl, focusNode: _focusNode!,
        wordCount: _wordCount, charCount: _charCount,
        isSaving: _isSaving,
      )),
      _BottomToolbar(
        controller: ctrl, expanded: _toolbarExpanded,
        onToggle: () => setState(() => _toolbarExpanded = !_toolbarExpanded),
      ),
    ]);
  }
}

// ── Full-screen Editor Canvas ────────────────────────────────────────────────
class _EditorCanvas extends StatelessWidget {
  final QuillController controller;
  final FocusNode focusNode;
  final int wordCount;
  final int charCount;
  final bool isSaving;

  const _EditorCanvas({required this.controller, required this.focusNode,
    required this.wordCount, required this.charCount, required this.isSaving});

  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    return Stack(children: [
      Positioned.fill(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 80),
              child: QuillEditor.basic(
                controller: controller,
                focusNode: focusNode,
                config: QuillEditorConfig(
                  minHeight: 400,
                  placeholder: 'Start writing...',
                  padding: EdgeInsets.zero,
                  customStyles: DefaultStyles(
                    h1: DefaultTextBlockStyle(
                      AppTypography.h1.copyWith(fontSize: 36, height: 1.25, color: c.textPrimary),
                      const HorizontalSpacing(0, 0), const VerticalSpacing(0, 18), const VerticalSpacing(0, 0), null),
                    h2: DefaultTextBlockStyle(
                      AppTypography.h2.copyWith(height: 1.35, color: c.textPrimary),
                      const HorizontalSpacing(0, 0), const VerticalSpacing(20, 10), const VerticalSpacing(0, 0), null),
                    h3: DefaultTextBlockStyle(
                      AppTypography.h3.copyWith(height: 1.35, color: c.textPrimary),
                      const HorizontalSpacing(0, 0), const VerticalSpacing(16, 8), const VerticalSpacing(0, 0), null),
                    paragraph: DefaultTextBlockStyle(
                      AppTypography.bodyLarge.copyWith(color: c.textSecondary),
                      const HorizontalSpacing(0, 0), const VerticalSpacing(8, 8), const VerticalSpacing(0, 0), null),
                    lists: DefaultListBlockStyle(
                      AppTypography.bodyLarge.copyWith(color: c.textSecondary),
                      const HorizontalSpacing(0, 0), const VerticalSpacing(8, 8), const VerticalSpacing(0, 0), null, null),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        right: 24, bottom: 12,
        child: Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(
            color: isSaving ? c.warning : c.success, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(isSaving ? 'Saving...' : 'Saved', style: AppTypography.label.copyWith(color: c.textMuted, fontSize: 10)),
          const SizedBox(width: 16),
          Text('$wordCount words · $charCount chars', style: AppTypography.label.copyWith(color: c.textMuted, fontSize: 10)),
        ]),
      ),
    ]);
  }
}

// ── Bottom Toolbar ───────────────────────────────────────────────────────────
class _BottomToolbar extends StatelessWidget {
  final QuillController controller;
  final bool expanded;
  final VoidCallback onToggle;
  const _BottomToolbar({required this.controller, required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _Pill(child: Wrap(spacing: 2, children: [
              _Fmt(Icons.format_bold_rounded, 'Bold', Attribute.bold, controller),
              _Fmt(Icons.format_italic_rounded, 'Italic', Attribute.italic, controller),
              _Fmt(Icons.format_underlined_rounded, 'Underline', Attribute.underline, controller),
              _Fmt(Icons.format_strikethrough_rounded, 'Strikethrough', Attribute.strikeThrough, controller),
              _Div(), _Fmt(Icons.title_rounded, 'H1', Attribute.h1, controller),
              _Fmt(Icons.text_fields_rounded, 'H2', Attribute.h2, controller),
              _Fmt(Icons.format_size_rounded, 'H3', Attribute.h3, controller),
              _Div(), _Fmt(Icons.format_list_bulleted_rounded, 'Bullets', Attribute.ul, controller),
              _Fmt(Icons.format_list_numbered_rounded, 'Numbers', Attribute.ol, controller),
              _Fmt(Icons.checklist_rounded, 'Checklist', Attribute.unchecked, controller),
              _Fmt(Icons.format_quote_rounded, 'Quote', Attribute.blockQuote, controller),
              _Fmt(Icons.code_rounded, 'Code', Attribute.codeBlock, controller),
              _Div(),
              _Act(Icons.format_indent_increase_rounded, 'Indent', () => controller.formatSelection(Attribute.indentL1)),
              _Act(Icons.format_clear_rounded, 'Clear', () => controller.formatSelection(Attribute.clone(Attribute.header, null))),
            ])),
          ),
        _Pill(child: Row(mainAxisSize: MainAxisSize.min, children: [
          _Toggle(Icons.palette_rounded, 'Format', expanded, onToggle),
          _Div(),
          _Act(Icons.link_rounded, 'Link', () => _linkDialog(context, controller)),
          _Act(Icons.add_rounded, 'Paragraph', () {
            final o = controller.selection.baseOffset;
            controller.document.insert(o, '\n');
            controller.updateSelection(TextSelection.collapsed(offset: o + 1), ChangeSource.local);
          }),
        ])),
      ])),
    );
  }

  Future<void> _linkDialog(BuildContext ctx, QuillController c) async {
    final tc = TextEditingController();
    final url = await showDialog<String>(context: ctx, builder: (d) => AlertDialog(
      title: Text('Add link', style: Theme.of(d).textTheme.headlineSmall),
      content: TextField(controller: tc, autofocus: true,
        decoration: const InputDecoration(hintText: 'https://example.com'),
        onSubmitted: (v) => Navigator.of(d).pop(v.trim())),
      actions: [
        TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.of(d).pop(tc.text.trim()), child: const Text('Apply')),
      ],
    ));
    tc.dispose();
    if (url != null && url.isNotEmpty) c.formatSelection(LinkAttribute(url));
  }
}

class _Fmt extends StatelessWidget {
  final IconData icon; final String tip; final Attribute attr; final QuillController ctrl;
  const _Fmt(this.icon, this.tip, this.attr, this.ctrl);
  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    final on = ctrl.getSelectionStyle().attributes.containsKey(attr.key);
    return Tooltip(message: tip, child: IconButton(
      onPressed: () => ctrl.formatSelection(on ? Attribute.clone(attr, null) : attr),
      style: IconButton.styleFrom(
        backgroundColor: on ? c.primary.withValues(alpha: 0.12) : Colors.transparent,
        foregroundColor: on ? c.primary : c.textSecondary, fixedSize: const Size.square(36)),
      icon: Icon(icon, size: 17),
    ));
  }
}

class _Act extends StatelessWidget {
  final IconData icon; final String tip; final VoidCallback onTap;
  const _Act(this.icon, this.tip, this.onTap);
  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    return Tooltip(message: tip, child: IconButton(onPressed: onTap,
      style: IconButton.styleFrom(foregroundColor: c.textSecondary, fixedSize: const Size.square(36)),
      icon: Icon(icon, size: 17)));
  }
}

class _Toggle extends StatelessWidget {
  final IconData icon; final String tip; final bool on; final VoidCallback onTap;
  const _Toggle(this.icon, this.tip, this.on, this.onTap);
  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    return Tooltip(message: tip, child: IconButton(onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: on ? c.primary : c.surfaceLow,
        foregroundColor: on ? Colors.white : c.textSecondary, fixedSize: const Size.square(40)),
      icon: Icon(icon, size: 18)));
  }
}

class _Pill extends StatelessWidget {
  final Widget child; const _Pill({required this.child});
  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    return ClipRRect(borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(color: c.glass, borderRadius: BorderRadius.circular(999),
            border: Border.all(color: c.isDark ? c.border : Colors.white.withValues(alpha: 0.9)),
            boxShadow: [BoxShadow(color: c.shadow, blurRadius: 24, offset: const Offset(0, 10))]),
          child: child)));
  }
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    return Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 3),
      color: c.border.withValues(alpha: 0.5));
  }
}
