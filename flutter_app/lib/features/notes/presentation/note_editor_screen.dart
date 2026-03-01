import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncra_frontend/ui_kit/theme/app_colors.dart';
import 'package:syncra_frontend/ui_kit/theme/typography.dart';

class NoteEditorScreen extends StatefulWidget {
  final String? initialJson;

  const NoteEditorScreen({super.key, this.initialJson});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late QuillController _controller;
  Timer? _autoSaveTimer;
  String? _lastSavedJson;

  @override
  void initState() {
    super.initState();
    if (widget.initialJson != null) {
      try {
        final doc = Document.fromJson(jsonDecode(widget.initialJson!));
        _controller = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        _controller = _freshH1Controller();
      }
    } else {
      _controller = _freshH1Controller();
    }

    // Enforce H1 on the first line always
    _controller.document.changes.listen((_) {
      final firstLine = _controller.document.queryChild(0).node;
      if (firstLine != null && !firstLine.style.containsKey(Attribute.h1.key)) {
        _controller.document.format(0, 1, Attribute.h1);
      }
      // Start auto-save debounce
      _scheduleAutoSave();
    });
  }

  QuillController _freshH1Controller() {
    final doc =
        Document()
          ..insert(0, '\n')
          ..format(0, 1, Attribute.h1);
    return QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _autoSave);
  }

  Future<void> _autoSave() async {
    final plainText = _controller.document.toPlainText().trim();
    if (plainText.isEmpty) return;

    final jsonStr = jsonEncode(_controller.document.toDelta().toJson());
    if (jsonStr == _lastSavedJson) return;
    _lastSavedJson = jsonStr;

    // Save back to shared prefs by updating the list
    final prefs = await SharedPreferences.getInstance();
    final notes = prefs.getStringList('notes') ?? [];

    if (widget.initialJson != null) {
      final idx = notes.indexOf(widget.initialJson!);
      if (idx != -1) {
        notes[idx] = jsonStr;
      } else {
        notes.add(jsonStr);
      }
    } else {
      // New note — we add it, but also pass the key back so NotesScreen can
      // use it next time. We track the key in _lastSavedJson.
      notes.add(jsonStr);
    }
    await prefs.setStringList('notes', notes);
  }

  String _getCurrentJson() {
    return jsonEncode(_controller.document.toDelta().toJson());
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlack,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _autoSaveTimer?.cancel();
            final plainText = _controller.document.toPlainText().trim();
            if (plainText.isEmpty) {
              context.pop();
            } else {
              context.pop(_getCurrentJson());
            }
          },
        ),
      ),
      body: Stack(
        children: [
          // ── Editor ────────────────────────────────────────────────────────
          Positioned.fill(
            child: QuillEditor.basic(
              controller: _controller,
              config: QuillEditorConfig(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 160),
                placeholder: 'Start writing...',
                expands: true,
                onKeyPressed: (event, node) {
                  if (event.logicalKey == LogicalKeyboardKey.backspace &&
                      _controller.selection.baseOffset == 0 &&
                      _controller.selection.extentOffset == 0) {
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                customStyles: DefaultStyles(
                  h1: DefaultTextBlockStyle(
                    AppTypography.h1.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                    const HorizontalSpacing(0, 0),
                    const VerticalSpacing(8, 0),
                    const VerticalSpacing(0, 0),
                    null,
                  ),
                  h2: DefaultTextBlockStyle(
                    AppTypography.h2.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                    const HorizontalSpacing(0, 0),
                    const VerticalSpacing(8, 0),
                    const VerticalSpacing(0, 0),
                    null,
                  ),
                  h3: DefaultTextBlockStyle(
                    AppTypography.h3.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                    const HorizontalSpacing(0, 0),
                    const VerticalSpacing(8, 0),
                    const VerticalSpacing(0, 0),
                    null,
                  ),
                  paragraph: DefaultTextBlockStyle(
                    AppTypography.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.7,
                    ),
                    const HorizontalSpacing(0, 0),
                    const VerticalSpacing(6, 0),
                    const VerticalSpacing(0, 0),
                    null,
                  ),
                ),
              ),
            ),
          ),

          // ── Floating glass dock ───────────────────────────────────────────
          Positioned(
            bottom: 28,
            left: 16,
            right: 16,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      // Visible glass tint — like Apple's dark glass
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.07),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.20),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 30,
                          spreadRadius: -2,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.04),
                          blurRadius: 1,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                    child: QuillSimpleToolbar(
                      controller: _controller,
                      config: QuillSimpleToolbarConfig(
                        multiRowsDisplay: false,
                        color:
                            Colors
                                .transparent, // Remove toolbar's own background
                        showDividers: true,
                        showUndo: true,
                        showRedo: true,
                        showFontFamily: true,
                        showFontSize: false,
                        showHeaderStyle: true,
                        showBoldButton: true,
                        showItalicButton: true,
                        showUnderLineButton: true,
                        showStrikeThrough: true,
                        showListNumbers: true,
                        showListBullets: true,
                        showListCheck: true,
                        showColorButton: true,
                        showBackgroundColorButton: true,
                        showClearFormat: true,
                        showCodeBlock: true,
                        showInlineCode: true,
                        showLink: true,
                        showSearchButton: false,
                        showSubscript: true,
                        showSuperscript: true,
                        showIndent: true,
                        showQuote: true,
                        showAlignmentButtons: true,
                        iconTheme: const QuillIconTheme(
                          iconButtonSelectedData: IconButtonData(
                            style: ButtonStyle(
                              backgroundColor: WidgetStatePropertyAll(
                                Color(0x44FFFFFF),
                              ),
                            ),
                          ),
                          iconButtonUnselectedData: IconButtonData(
                            style: ButtonStyle(
                              backgroundColor: WidgetStatePropertyAll(
                                Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                        buttonOptions: QuillSimpleToolbarButtonOptions(
                          fontFamily: QuillToolbarFontFamilyButtonOptions(
                            items: {
                              'Inter': GoogleFonts.inter().fontFamily!,
                              'Roboto': GoogleFonts.roboto().fontFamily!,
                              'Outfit': GoogleFonts.outfit().fontFamily!,
                              'Merriweather':
                                  GoogleFonts.merriweather().fontFamily!,
                              'Space Mono': GoogleFonts.spaceMono().fontFamily!,
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
