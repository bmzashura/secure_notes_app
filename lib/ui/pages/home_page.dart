// lib/ui/pages/home_page.dart
// Screen 05 — Home / Notes List

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  @override
  void initState() {
    super.initState();
    context.read<NotesBloc>().add(NotesLoadRequested());
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
      body: BlocConsumer<NotesBloc, NotesState>(
        listener: (context, state) {
          if (state is NotesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.danger,
              ),
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
            if (state.notes.isEmpty) {
              return _buildEmptyState();
            }
            return RefreshIndicator(
              onRefresh: () async {
                context.read<NotesBloc>().add(NotesLoadRequested());
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.notes.length,
                itemBuilder: (context, index) {
                  return _NoteCard(
                    note: state.notes[index],
                    onTap: () => _openNote(state.notes[index]),
                    onDelete: () => _deleteNote(state.notes[index]),
                  );
                },
              ),
            );
          }
          return _buildEmptyState();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNote(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 64,
            color: AppTheme.textMuted,
          ),
          SizedBox(height: 16),
          Text(
            'Belum ada catatan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
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
    // Step 1: konfirmasi hapus
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
              _showDeletePinDialog(note);
            },
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
  }

  void _showDeletePinDialog(Note note) {
    final pinCtrl = TextEditingController();
    bool obscure = true;
    bool isLoading = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: AppTheme.danger),
              SizedBox(width: 8),
              Text('Konfirmasi PIN'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan PIN master untuk menghapus catatan:',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                obscureText: obscure,
                keyboardType: TextInputType.number,
                maxLength: 6,
                enabled: !isLoading,
                decoration: InputDecoration(
                  labelText: 'PIN',
                  counterText: '',
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (pinCtrl.text.length < 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('PIN minimal 4 digit'),
                            backgroundColor: AppTheme.warning,
                          ),
                        );
                        return;
                      }
                      setState(() => isLoading = true);
                      try {
                        // Verify PIN by trying to decrypt the note
                        final notesBloc = context.read<NotesBloc>();
                        final fullNote = await notesBloc.notesRepository.getNote(note.id);
                        notesBloc.notesRepository.decryptContent(fullNote, pinCtrl.text);
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          context.read<NotesBloc>().add(NoteDeleteRequested(note.id));
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('PIN salah'),
                              backgroundColor: AppTheme.danger,
                            ),
                          );
                        }
                      } finally {
                        if (ctx.mounted) {
                          setState(() => isLoading = false);
                        }
                      }
                    },
              child: const Text('Hapus'),
            ),
          ],
        ),
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
    // Tampilkan title encrypted (jika ada) atau placeholder terenkripsi
    // Jangan tampilkan decryptedTitle (bisa null) atau tanggal edit (leak metadata)
    final displayTitle = note.titleEncrypted ?? '🔒 Catatan Terenkripsi';

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
                child: Text(
                  displayTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
