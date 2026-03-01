import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:syncra_frontend/ui_kit/theme/typography.dart';
import 'package:syncra_frontend/ui_kit/theme/app_colors.dart';

class NoteEditorScreen extends StatefulWidget {
  final String? initialJson;

  const NoteEditorScreen({super.key, this.initialJson});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final QuillController _controller;

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
      } catch (e) {
        _controller = QuillController.basic();
      }
    } else {
      _controller = QuillController.basic();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Note', style: AppTypography.h3),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final plainText = _controller.document.toPlainText().trim();
            if (plainText.isEmpty) {
              context.pop();
            } else {
              final jsonStr = jsonEncode(
                _controller.document.toDelta().toJson(),
              );
              context.pop(jsonStr);
            }
          },
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: AppColors.backgroundBlack,
              child: QuillEditor.basic(
                controller: _controller,
                config: const QuillEditorConfig(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 100,
                  ),
                  placeholder: 'Start writing...',
                  expands: true,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: AppColors.borderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: QuillSimpleToolbar(
                  controller: _controller,
                  config: QuillSimpleToolbarConfig(
                    showUndo: true,
                    showRedo: true,
                    showFontFamily: true,
                    showFontSize: false,
                    showHeaderStyle: true,
                    showListNumbers: true,
                    showListBullets: true,
                    showListCheck: true,
                    showColorButton: true,
                    showBackgroundColorButton: true,
                    multiRowsDisplay: false,
                    buttonOptions: const QuillSimpleToolbarButtonOptions(
                      base: QuillToolbarBaseButtonOptions(
                        iconTheme: QuillIconTheme(
                          iconButtonSelectedData: IconButtonData(
                            style: ButtonStyle(
                              backgroundColor: WidgetStatePropertyAll(
                                AppColors.borderSubtle,
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
