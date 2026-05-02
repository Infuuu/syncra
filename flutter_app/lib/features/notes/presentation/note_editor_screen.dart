import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/note_model.dart';
import '../../../ui_kit/components/layout/ambient_background.dart';
import '../../../ui_kit/components/surfaces/glass_panel.dart';
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
  bool _formatDockExpanded = true;

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
        note = await ref
            .read(localNoteRepositoryProvider)
            .getNote(widget.noteId!);
      }
      note ??= await ref.read(notesControllerProvider.notifier).createDraft();

      if (!mounted) return;
      _noteId = note.id;
      _lastSavedJson = note.documentJson;
      _controller = QuillController(
        document: _documentFromJson(note.documentJson),
        selection: const TextSelection.collapsed(offset: 0),
      );
      _changesSubscription =
          _controller!.document.changes.listen((_) => _scheduleAutoSave());
      setState(() {});
    } catch (e, st) {
      debugPrint('Error in NoteEditor _bootstrap: $e\n$st');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Document _documentFromJson(String documentJson) {
    try {
      return Document.fromJson(jsonDecode(documentJson) as List<dynamic>);
    } catch (_) {
      return Document()..insert(0, '\n');
    }
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 900), _save);
    if (mounted) setState(() => _isSaving = true);
  }

  Future<void> _save() async {
    final controller = _controller;
    final noteId = _noteId;
    if (controller == null || noteId == null) return;

    final documentJson = jsonEncode(controller.document.toDelta().toJson());
    if (documentJson == _lastSavedJson) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    await ref
        .read(notesControllerProvider.notifier)
        .saveNote(id: noteId, documentJson: documentJson);
    _lastSavedJson = documentJson;
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _closeEditor() async {
    _autoSaveTimer?.cancel();
    await _save();
    if (mounted) context.go('/notes');
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _changesSubscription?.cancel();
    _controller?.dispose();
    _focusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: _error != null
              ? Center(
                  child: Text('Failed to load note:\n$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)))
              : controller == null
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 170),
                        child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: _EditorTopBar(
                                isSaving: _isSaving,
                                onBack: _closeEditor,
                                onUndo: controller.undo,
                                onRedo: controller.redo,
                              ),
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 42),
                            ),
                            SliverToBoxAdapter(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 840,
                                  ),
                                  child: _EditorCanvas(
                                    controller: controller,
                                    focusNode: _focusNode!,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 28,
                        child: _FluidCommandDock(
                          controller: controller,
                          expanded: _formatDockExpanded,
                          onToggleExpanded:
                              () => setState(
                                () =>
                                    _formatDockExpanded = !_formatDockExpanded,
                              ),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _EditorTopBar extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  const _EditorTopBar({
    required this.isSaving,
    required this.onBack,
    required this.onUndo,
    required this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      backgroundColor: Colors.white.withValues(alpha: 0.72),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back to notes',
          ),
          Text('Notes', style: Theme.of(context).textTheme.headlineSmall),
          const Spacer(),
          _ToolbarIcon(
            icon: Icons.undo_rounded,
            tooltip: 'Undo',
            onPressed: onUndo,
          ),
          _ToolbarIcon(
            icon: Icons.redo_rounded,
            tooltip: 'Redo',
            onPressed: onRedo,
          ),
          const SizedBox(width: 14),
          _SavingIndicator(isSaving: isSaving),
        ],
      ),
    );
  }
}

class _SavingIndicator extends StatelessWidget {
  final bool isSaving;

  const _SavingIndicator({required this.isSaving});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isSaving ? AppColors.warning : AppColors.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isSaving ? 'Saving...' : 'Saved',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _EditorCanvas extends StatelessWidget {
  final QuillController controller;
  final FocusNode focusNode;

  const _EditorCanvas({required this.controller, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(40, 34, 40, 52),
      backgroundColor: Colors.white.withValues(alpha: 0.58),
      child: QuillEditor.basic(
        controller: controller,
        focusNode: focusNode,
        config: QuillEditorConfig(
          minHeight: 620,
          placeholder: 'Start writing...',
          padding: EdgeInsets.zero,
          customStyles: DefaultStyles(
            h1: DefaultTextBlockStyle(
              AppTypography.h1.copyWith(fontSize: 38, height: 1.25),
              const HorizontalSpacing(0, 0),
              const VerticalSpacing(0, 18),
              const VerticalSpacing(0, 0),
              null,
            ),
            h2: DefaultTextBlockStyle(
              AppTypography.h2.copyWith(height: 1.35),
              const HorizontalSpacing(0, 0),
              const VerticalSpacing(20, 10),
              const VerticalSpacing(0, 0),
              null,
            ),
            h3: DefaultTextBlockStyle(
              AppTypography.h3.copyWith(height: 1.35),
              const HorizontalSpacing(0, 0),
              const VerticalSpacing(16, 8),
              const VerticalSpacing(0, 0),
              null,
            ),
            paragraph: DefaultTextBlockStyle(
              AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
              const HorizontalSpacing(0, 0),
              const VerticalSpacing(8, 8),
              const VerticalSpacing(0, 0),
              null,
            ),
            lists: DefaultListBlockStyle(
              AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
              const HorizontalSpacing(0, 0),
              const VerticalSpacing(8, 8),
              const VerticalSpacing(0, 0),
              null,
              null,
            ),
          ),
        ),
      ),
    );
  }
}

class _FluidCommandDock extends StatelessWidget {
  final QuillController controller;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  const _FluidCommandDock({
    required this.controller,
    required this.expanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child:
                expanded
                    ? Padding(
                      key: const ValueKey('format-dock'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DockSurface(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _FormatButton(
                              icon: Icons.format_bold_rounded,
                              tooltip: 'Bold',
                              selected: _isSelected(controller, Attribute.bold),
                              onPressed:
                                  () => _toggle(controller, Attribute.bold),
                            ),
                            _FormatButton(
                              icon: Icons.format_italic_rounded,
                              tooltip: 'Italic',
                              selected: _isSelected(
                                controller,
                                Attribute.italic,
                              ),
                              onPressed:
                                  () => _toggle(controller, Attribute.italic),
                            ),
                            _FormatButton(
                              icon: Icons.format_underlined_rounded,
                              tooltip: 'Underline',
                              selected: _isSelected(
                                controller,
                                Attribute.underline,
                              ),
                              onPressed:
                                  () =>
                                      _toggle(controller, Attribute.underline),
                            ),
                            const _DockDivider(),
                            _FormatButton(
                              icon: Icons.title_rounded,
                              tooltip: 'Heading',
                              selected: _isSelected(controller, Attribute.h1),
                              onPressed:
                                  () => _toggle(controller, Attribute.h1),
                            ),
                            _FormatButton(
                              icon: Icons.format_list_bulleted_rounded,
                              tooltip: 'Bulleted list',
                              selected: _isSelected(controller, Attribute.ul),
                              onPressed:
                                  () => _toggle(controller, Attribute.ul),
                            ),
                            _FormatButton(
                              icon: Icons.format_quote_rounded,
                              tooltip: 'Quote',
                              selected: _isSelected(
                                controller,
                                Attribute.blockQuote,
                              ),
                              onPressed:
                                  () =>
                                      _toggle(controller, Attribute.blockQuote),
                            ),
                          ],
                        ),
                      ),
                    )
                    : const SizedBox.shrink(key: ValueKey('collapsed-dock')),
          ),
          _DockSurface(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PrimaryDockButton(
                  icon: Icons.text_fields_rounded,
                  tooltip: 'Text tools',
                  selected: expanded,
                  onPressed: onToggleExpanded,
                ),
                const _DockDivider(tall: true),
                _FormatButton(
                  icon: Icons.add_rounded,
                  tooltip: 'New paragraph',
                  onPressed: () {
                    final offset = controller.selection.baseOffset;
                    controller.document.insert(offset, '\n');
                    controller.updateSelection(
                      TextSelection.collapsed(offset: offset + 1),
                      ChangeSource.local,
                    );
                  },
                ),
                _FormatButton(
                  icon: Icons.link_rounded,
                  tooltip: 'Link',
                  onPressed: () => _showLinkDialog(context, controller),
                ),
                _FormatButton(
                  icon: Icons.more_horiz_rounded,
                  tooltip: 'Clear formatting',
                  onPressed:
                      () => controller.formatSelection(
                        Attribute.clone(Attribute.header, null),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static bool _isSelected(QuillController controller, Attribute attribute) {
    return controller.getSelectionStyle().attributes.containsKey(attribute.key);
  }

  static void _toggle(QuillController controller, Attribute attribute) {
    final selected = _isSelected(controller, attribute);
    controller.formatSelection(
      selected ? Attribute.clone(attribute, null) : attribute,
    );
  }

  Future<void> _showLinkDialog(
    BuildContext context,
    QuillController controller,
  ) async {
    final textController = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Add link',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            content: TextField(
              controller: textController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'https://example.com',
              ),
              onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed:
                    () => Navigator.of(context).pop(textController.text.trim()),
                child: const Text('Apply'),
              ),
            ],
          ),
    );
    textController.dispose();
    if (url == null || url.isEmpty) return;
    controller.formatSelection(LinkAttribute(url));
  }
}

class _DockSurface extends StatelessWidget {
  final Widget child;

  const _DockSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 34,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  const _FormatButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return _ToolbarIcon(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      selected: selected,
    );
  }
}

class _PrimaryDockButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  const _PrimaryDockButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: selected ? AppColors.primary : AppColors.surfaceLow,
          foregroundColor: selected ? Colors.white : AppColors.textSecondary,
          fixedSize: const Size.square(48),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;

  const _ToolbarIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor:
              selected ? const Color(0x1A818CF8) : Colors.transparent,
          foregroundColor:
              selected ? AppColors.primary : AppColors.textSecondary,
          fixedSize: const Size.square(42),
        ),
        icon: Icon(icon, size: 21),
      ),
    );
  }
}

class _DockDivider extends StatelessWidget {
  final bool tall;

  const _DockDivider({this.tall = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: tall ? 34 : 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: AppColors.border.withValues(alpha: 0.7),
    );
  }
}
