import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:syncra_frontend/ui_kit/components/buttons/app_buttons.dart';
import 'package:syncra_frontend/ui_kit/theme/typography.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final List<String> _notes = [];

  Future<void> _createNote() async {
    final result = await context.push<String>('/notes/new');
    if (result != null && result.isNotEmpty) {
      setState(() {
        _notes.add(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes', style: AppTypography.h3),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                GhostButton(
                  onPressed: () {
                    context.go('/');
                  },
                  label: 'Go to Boards',
                  icon: const Icon(Icons.dashboard, size: 16),
                ),
                const SizedBox(width: 8),
                GhostButton(
                  onPressed: () {
                    context.go('/login');
                  },
                  label: 'Logout',
                  icon: const Icon(Icons.logout, size: 16),
                ),
              ],
            ),
          ),
        ],
      ),
      body:
          _notes.isEmpty
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
                              childAspectRatio: 1.5,
                            ),
                        itemCount: _notes.length,
                        itemBuilder: (context, index) {
                          return InkWell(
                            onTap: () async {
                              final result = await context.push<String>(
                                '/notes/new',
                                extra: _notes[index],
                              );
                              if (result != null && result.isNotEmpty) {
                                setState(() {
                                  _notes[index] = result;
                                });
                              }
                            },
                            child: Card(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                alignment: Alignment.center,
                                child: Builder(
                                  builder: (context) {
                                    String previewText = '';
                                    try {
                                      final doc = quill.Document.fromJson(
                                        jsonDecode(_notes[index]),
                                      );
                                      previewText = doc.toPlainText().trim();
                                    } catch (_) {
                                      previewText = _notes[index];
                                    }
                                    if (previewText.isEmpty)
                                      previewText = 'Empty Note';
                                    return Text(
                                      previewText,
                                      style: AppTypography.bodyLarge,
                                      textAlign: TextAlign.center,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  },
                                ),
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
