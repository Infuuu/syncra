import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncra_frontend/ui_kit/components/buttons/app_buttons.dart';
import 'package:syncra_frontend/ui_kit/theme/app_colors.dart';
import 'package:syncra_frontend/ui_kit/theme/typography.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<String> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('notes') ?? [];
    setState(() {
      _notes = saved;
      _isLoading = false;
    });
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('notes', _notes);
  }

  Future<void> _createNote() async {
    final result = await context.push<String>('/notes/new');
    if (result != null && result.isNotEmpty) {
      setState(() => _notes.add(result));
      _saveNotes();
    }
  }

  /// Extract the heading (first line) from a note's JSON delta
  String _extractTitle(String noteJson) {
    try {
      final doc = quill.Document.fromJson(jsonDecode(noteJson));
      final text = doc.toPlainText().trim();
      final firstLine = text
          .split('\n')
          .firstWhere(
            (l) => l.trim().isNotEmpty,
            orElse: () => 'Untitled Note',
          );
      return firstLine.isEmpty ? 'Untitled Note' : firstLine;
    } catch (_) {
      return 'Untitled Note';
    }
  }

  /// Extract the body preview (all lines after heading) from a note's JSON delta
  String _extractPreview(String noteJson) {
    try {
      final doc = quill.Document.fromJson(jsonDecode(noteJson));
      final lines = doc.toPlainText().trim().split('\n');
      final bodyLines =
          lines.skip(1).where((l) => l.trim().isNotEmpty).toList();
      return bodyLines.isEmpty ? '' : bodyLines.join(' ');
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlack,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundBlack,
        title: const Text('Notes', style: AppTypography.h3),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                GhostButton(
                  onPressed: () => context.go('/'),
                  label: 'Go to Boards',
                  icon: const Icon(Icons.dashboard, size: 16),
                ),
                const SizedBox(width: 8),
                GhostButton(
                  onPressed: () => context.go('/login'),
                  label: 'Logout',
                  icon: const Icon(Icons.logout, size: 16),
                ),
              ],
            ),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _notes.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No notes yet.', style: AppTypography.h2),
                    const SizedBox(height: 16),
                    const Text(
                      'Create your first note below.',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    PrimaryButton(
                      onPressed: _createNote,
                      label: 'Create Note',
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrimaryButton(
                      onPressed: _createNote,
                      label: 'Create Note',
                      icon: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 300,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.2,
                            ),
                        itemCount: _notes.length,
                        itemBuilder: (context, index) {
                          final title = _extractTitle(_notes[index]);
                          final preview = _extractPreview(_notes[index]);
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final result = await context.push<String>(
                                '/notes/new',
                                extra: _notes[index],
                              );
                              if (result != null && result.isNotEmpty) {
                                setState(() => _notes[index] = result);
                                _saveNotes();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.borderSubtle,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: AppTypography.h3.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (preview.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Text(
                                        preview,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
