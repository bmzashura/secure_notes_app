// lib/ui/pages/note_editor_page.dart
// Screen 06/07 — Note Detail / Create Note

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/notes/notes_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../core/secure_storage/secure_storage_service.dart';
import '../../data/models/models.dart';
import '../../app.dart';

class NoteEditorPage extends StatefulWidget {
  final Note? note;

  const NoteEditorPage({super.key, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _pinController = TextEditingController();
  bool _hasChanges = false;
  bool _obscurePin = true;
  bool _isLoading = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOpenPinDialog();
      });
    }
  }

  void _showOpenPinDialog() {
    _pinController.clear();
    _obscurePin = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppTheme.accentCyan),
            SizedBox(width: 8),
            Text('Buka Catatan'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan PIN untuk membuka catatan ini:',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              obscureText: _obscurePin,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'PIN',
                counterText: '',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePin
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscurePin = !_obscurePin);
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_pinController.text.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN minimal 4 digit'),
                    backgroundColor: AppTheme.warning,
                  ),
                );
                return;
              }
              Navigator.of(ctx).pop();
              _decryptAndOpen(_pinController.text);
            },
            child: const Text('Buka'),
          ),
        ],
      ),
    );
  }

  Future<void> _decryptAndOpen(String pin) async {
    setState(() => _isLoading = true);
    try {
      final notesBloc = context.read<NotesBloc>();
      final note = await notesBloc.notesRepository.getNote(widget.note!.id);
      final decryptedContent = notesBloc.notesRepository.decryptContent(note, pin);

      String? decryptedTitle;
      if (note.titleEncrypted != null) {
        decryptedTitle = notesBloc.notesRepository.decryptContent(
          note.copyWith(ciphertext: note.titleEncrypted),
          pin,
        );
      }

      if (mounted) {
        setState(() {
          _titleController.text = decryptedTitle ?? '';
          _contentController.text = decryptedContent;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mendekripsi. PIN mungkin salah.'),
            backgroundColor: AppTheme.danger,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  void _onSave() {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konten catatan tidak boleh kosong'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    _showSavePinDialog();
  }

  void _showSavePinDialog() {
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
              Icon(Icons.lock_outline, color: AppTheme.accentCyan),
              SizedBox(width: 8),
              Text('Konfirmasi PIN'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan PIN master untuk menyimpan catatan:',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                obscureText: obscure,
                keyboardType: TextInputType.number,
                maxLength: 6,
                enabled: !isLoading,
                autofocus: true,
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
                        // Verify PIN against master PIN
                        final masterPin = await getIt<SecureStorageService>().getMasterPin();
                        if (pinCtrl.text != masterPin) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('PIN salah'),
                                backgroundColor: AppTheme.danger,
                              ),
                            );
                          }
                          return;
                        }
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          _saveNote();
                        }
                      } finally {
                        if (ctx.mounted) {
                          setState(() => isLoading = false);
                        }
                      }
                    },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveNote() {
    if (_isEditing) {
      context.read<NotesBloc>().add(NoteUpdateRequested(
            noteId: widget.note!.id,
            content: _contentController.text.trim(),
            title: _titleController.text.trim().isEmpty
                ? null
                : _titleController.text.trim(),
          ));
    } else {
      context.read<NotesBloc>().add(NoteCreateRequested(
            content: _contentController.text.trim(),
            title: _titleController.text.trim().isEmpty
                ? null
                : _titleController.text.trim(),
          ));
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Batalkan perubahan?'),
        content: const Text('Perubahan yang belum disimpan akan hilang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Tetap Edit'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: BlocListener<NotesBloc, NotesState>(
        listener: (context, state) {
          if (state is NoteOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.success,
              ),
            );
            Navigator.of(context).pop();
          } else if (state is NotesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.danger,
              ),
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(
            leading: _isLoading
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () async {
                      if (_hasChanges) {
                        final shouldPop = await _onWillPop();
                        if (shouldPop && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
            actions: [
              TextButton.icon(
                onPressed: _onSave,
                icon: const Icon(Icons.check, color: AppTheme.success),
                label: const Text(
                  'Save',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _titleController,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Judul (opsional)',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                        ),
                        onChanged: (_) => _onContentChanged(),
                      ),
                      const Divider(),
                      TextField(
                        controller: _contentController,
                        maxLines: null,
                        minLines: 15,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppTheme.textPrimary,
                          height: 1.6,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ketik catatanmu di sini...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                        ),
                        onChanged: (_) => _onContentChanged(),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.accentCyan.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock,
                              size: 16,
                              color: AppTheme.accentCyan,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Terenkripsi AES-256-GCM',
                              style: TextStyle(
                                color: AppTheme.accentCyan,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
