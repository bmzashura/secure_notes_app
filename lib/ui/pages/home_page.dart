// lib/ui/pages/home_page.dart
// Screen 05 — Home / Notes List

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/notes/notes_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import 'note_editor_page.dart';
import 'settings_page.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  List<Note> _filteredNotes = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    context.read<NotesBloc>().add(NotesLoadRequested());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterNotes(String query, List<Note> allNotes) {
    setState(() {
      if (query.isEmpty) {
        _isSearching = false;
        _filteredNotes = allNotes;
      } else {
        _isSearching = true;
        _filteredNotes = allNotes.where((note) {
          // Search by decrypted title if available
          return note.decryptedTitle
                  ?.toLowerCase()
                  .contains(query.toLowerCase()) ??
              false;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SECURE NOTES',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari catatan...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          final state = context.read<NotesBloc>().state;
                          if (state is NotesLoaded) {
                            _filterNotes('', state.notes);
                          }
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                final state = context.read<NotesBloc>().state;
                if (state is NotesLoaded) {
                  _filterNotes(v, state.notes);
                }
              },
            ),
          ),
          // Notes count
          BlocBuilder<NotesBloc, NotesState>(
            builder: (context, state) {
              if (state is NotesLoaded) {
                final count = _isSearching
                    ? _filteredNotes.length
                    : state.notes.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Semua Catatan ($count)',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 8),
          // Notes list
          Expanded(
            child: BlocConsumer<NotesBloc, NotesState>(
              listener: (context, state) {
                if (state is NotesError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppTheme.danger,
                    ),
                  );
                } else if (state is NotesLoaded) {
                  _filterNotes(
                    _searchController.text,
                    state.notes,
                  );
                }
              },
              builder: (context, state) {
                if (state is NotesLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  );
                }
                if (state is NotesLoaded) {
                  final notes = _isSearching ? _filteredNotes : state.notes;
                  if (notes.isEmpty) {
                    return _buildEmptyState();
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<NotesBloc>().add(NotesLoadRequested());
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        return _NoteCard(
                          note: notes[index],
                          onTap: () => _openNote(notes[index]),
                          onDelete: () => _deleteNote(notes[index]),
                        );
                      },
                    ),
                  );
                }
                return _buildEmptyState();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNote(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.note_add_outlined,
            size: 64,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada catatan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tekan + untuk membuat catatan baru',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  void _openNote(Note? note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorPage(note: note),
      ),
    );
  }

  void _deleteNote(Note note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Hapus Catatan?'),
        content: const Text('Operasi ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<NotesBloc>().add(NoteDeleteRequested(note.id));
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppTheme.primary, width: 3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.decryptedTitle ?? 'Catatan Tanpa Judul',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Diedit: ${dateFormat.format(note.updatedAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
