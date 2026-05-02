import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      // TopAppBar
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.65),
          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.4))),
        ),
        child: Row(
          children: [
            Text('Syncra Editor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: c.textPrimary)),
            Container(height: 16, width: 1, color: c.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
            Text(_isSaving ? 'Saving...' : 'Saved recently', style: AppTypography.label.copyWith(color: c.textSecondary)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.share, size: 20),
              onPressed: () {},
              color: c.textSecondary,
              hoverColor: c.primarySoft.withValues(alpha: 0.2),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: () {},
              color: c.textSecondary,
              hoverColor: c.primarySoft.withValues(alpha: 0.2),
            ),
            Container(
              margin: const EdgeInsets.only(left: 16),
              padding: const EdgeInsets.only(left: 16),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.5)))),
              child: const CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuAonzEXbQV6obIA0q8ui03N9u6QWh1cdJMBWsG09l7bAI0SaPIK6u1CbuLZvfsU7QeG72Vorb40o7k4ywIxA2BUwEESC1RVEi9WIi60ELZSx4iUQKcoU8Is5ixdMCarDHajeoz1IVXoIl8ZQOWIKvM8uCKv7d7efWHtzm0vHnIT_nRAFjplW--ksZRhK8WrY60qX7bmnOUpy56INC4lphoa_09VWFKC6r7uO4vvknsc65C3ZbYTztpnRQZaXsvDyjSuPWgKTepUWO9G'),
              ),
            ),
          ],
        ),
      ),
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
            constraints: const BoxConstraints(maxWidth: 860),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 48, 48, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.1),
                      border: Border.all(color: c.primary.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility, size: 16, color: c.primary),
                        const SizedBox(width: 8),
                        Text('Vision Document', style: AppTypography.label.copyWith(color: c.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: QuillEditor.basic(
                      controller: controller,
                      focusNode: focusNode,
                      config: QuillEditorConfig(
                        minHeight: 400,
                        placeholder: 'Start writing...',
                        padding: EdgeInsets.zero,
                        embedBuilders: [
                          _ImageEmbedBuilder(),
                          _VideoEmbedBuilder(),
                        ],
                        customStyles: DefaultStyles(
                          h1: DefaultTextBlockStyle(
                            AppTypography.h1.copyWith(fontSize: 32, height: 1.25, color: c.textPrimary, fontWeight: FontWeight.w600),
                            const HorizontalSpacing(0, 0), const VerticalSpacing(0, 24), const VerticalSpacing(0, 0), null),
                          h2: DefaultTextBlockStyle(
                            AppTypography.h2.copyWith(height: 1.35, color: c.textPrimary, fontWeight: FontWeight.w600),
                            const HorizontalSpacing(0, 0), const VerticalSpacing(48, 16), const VerticalSpacing(0, 0), null),
                          h3: DefaultTextBlockStyle(
                            AppTypography.h3.copyWith(height: 1.35, color: c.textPrimary),
                            const HorizontalSpacing(0, 0), const VerticalSpacing(24, 12), const VerticalSpacing(0, 0), null),
                          paragraph: DefaultTextBlockStyle(
                            AppTypography.bodyLarge.copyWith(color: c.textSecondary, height: 1.7),
                            const HorizontalSpacing(0, 0), const VerticalSpacing(12, 12), const VerticalSpacing(0, 0), null),
                          lists: DefaultListBlockStyle(
                            AppTypography.bodyLarge.copyWith(color: c.textSecondary, height: 1.7),
                            const HorizontalSpacing(0, 0), const VerticalSpacing(12, 12), const VerticalSpacing(0, 0), null, null),
                          quote: DefaultTextBlockStyle(
                            AppTypography.bodyLarge.copyWith(color: c.textPrimary.withValues(alpha: 0.8), fontStyle: FontStyle.italic),
                            const HorizontalSpacing(24, 0), const VerticalSpacing(24, 24), const VerticalSpacing(0, 0),
                            BoxDecoration(
                              border: Border(left: BorderSide(width: 4, color: c.primary)),
                              color: c.surface.withValues(alpha: 0.4),
                              borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      Positioned(
        right: 24, bottom: 12,
        child: Text('$wordCount words · $charCount chars', style: AppTypography.label.copyWith(color: c.textMuted, fontSize: 10)),
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
      padding: const EdgeInsets.only(bottom: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (expanded)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _Pill(
                  isRoundedRectangle: true,
                  child: Wrap(
                    spacing: 4,
                    children: [
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
                      _Div(), _Fmt(Icons.format_quote_rounded, 'Quote', Attribute.blockQuote, controller),
                      _Fmt(Icons.code_rounded, 'Code', Attribute.codeBlock, controller),
                      _Div(),
                      _Fmt(Icons.format_align_left_rounded, 'Align Left', Attribute.leftAlignment, controller),
                      _Fmt(Icons.format_align_center_rounded, 'Align Center', Attribute.centerAlignment, controller),
                      _Fmt(Icons.format_align_right_rounded, 'Align Right', Attribute.rightAlignment, controller),
                      _Fmt(Icons.format_align_justify_rounded, 'Justify', Attribute.justifyAlignment, controller),
                      _Div(),
                      _Act(Icons.format_indent_increase_rounded, 'Indent', () => controller.formatSelection(Attribute.indentL1)),
                      _Act(Icons.format_clear_rounded, 'Clear', () => controller.formatSelection(Attribute.clone(Attribute.header, null))),
                    ],
                  ),
                ),
              ),
            _Pill(
              isRoundedRectangle: false,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Toggle(Icons.palette_rounded, 'Format', expanded, onToggle),
                  const SizedBox(width: 8),
                  _Act(Icons.undo_rounded, 'Undo', () => controller.undo()),
                  _Act(Icons.redo_rounded, 'Redo', () => controller.redo()),
                  const SizedBox(width: 8),
                  _Act(Icons.image_rounded, 'Add Image', () => _mediaDialog(context, controller, 'image')),
                  _Act(Icons.video_library_rounded, 'Add Video', () => _mediaDialog(context, controller, 'video')),
                  _Act(Icons.picture_as_pdf_rounded, 'Attach File', () => _mediaDialog(context, controller, 'file')),
                  const SizedBox(width: 8),
                  _Act(Icons.link_rounded, 'Link', () => _linkDialog(context, controller)),
                  const SizedBox(width: 4),
                  _Act(Icons.add_rounded, 'Paragraph', () {
                    final o = controller.selection.baseOffset;
                    controller.document.insert(o, '\n');
                    controller.updateSelection(TextSelection.collapsed(offset: o + 1), ChangeSource.local);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
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

  Future<void> _mediaDialog(BuildContext ctx, QuillController c, String type) async {
    final tc = TextEditingController();
    final title = type == 'image' ? 'Add Image URL' : (type == 'video' ? 'Add Video URL' : 'Attach File URL');
    final icon = type == 'image' ? Icons.image : (type == 'video' ? Icons.video_library : Icons.attach_file);
    final url = await showDialog<String>(context: ctx, builder: (d) => AlertDialog(
      title: Row(children: [Icon(icon), const SizedBox(width: 8), Text(title, style: Theme.of(d).textTheme.headlineSmall)]),
      content: TextField(controller: tc, autofocus: true,
        decoration: InputDecoration(hintText: 'https://example.com/asset.$type'),
        onSubmitted: (v) => Navigator.of(d).pop(v.trim())),
      actions: [
        TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.of(d).pop(tc.text.trim()), child: const Text('Insert')),
      ],
    ));
    tc.dispose();
    if (url != null && url.isNotEmpty) {
      final index = c.selection.baseOffset;
      final length = c.selection.extentOffset - index;
      
      if (type == 'image') {
        c.replaceText(index, length, BlockEmbed.image(url), null);
      } else if (type == 'video') {
        c.replaceText(index, length, BlockEmbed.video(url), null);
      } else {
        final text = '📎 Attachment ($url)';
        c.replaceText(index, length, text, null);
        c.formatText(index, text.length, LinkAttribute(url));
      }
    }
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
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        fixedSize: const Size.square(40),
        shadowColor: c.primary.withValues(alpha: 0.25),
        elevation: 8,
      ),
      icon: Icon(icon, size: 20)));
  }
}

class _Pill extends StatelessWidget {
  final Widget child; 
  final bool isRoundedRectangle;
  const _Pill({required this.child, this.isRoundedRectangle = false});
  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    final radius = BorderRadius.circular(isRoundedRectangle ? 16 : 999);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isRoundedRectangle ? 16 : 12, vertical: isRoundedRectangle ? 8 : 8),
          decoration: BoxDecoration(
            color: isRoundedRectangle ? c.surface.withValues(alpha: 0.8) : c.surface.withValues(alpha: 0.9),
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: isRoundedRectangle ? 0.4 : 0.5)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 30, offset: const Offset(0, 15))],
          ),
          child: child,
        ),
      ),
    );
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

class _ImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType;
  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(url, fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(
            color: Colors.grey.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(32),
            child: const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
          ),
        ),
      ),
    );
  }
}

class _VideoEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.videoType;
  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.play_circle_fill, size: 48, color: Colors.white),
          const SizedBox(height: 8),
          Text(url, style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
