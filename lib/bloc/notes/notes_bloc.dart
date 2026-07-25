// lib/bloc/notes/notes_bloc.dart
// BLoC untuk Notes: list, create, update, delete, decrypt

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/models.dart';
import '../../data/repositories/notes_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────

abstract class NotesEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class NotesLoadRequested extends NotesEvent {}

class NoteCreateRequested extends NotesEvent {
  final String content;
  final String? title;
  NoteCreateRequested({
    required this.content,
    this.title,
  });
  @override
  List<Object?> get props => [content, title];
}

class NoteUpdateRequested extends NotesEvent {
  final String noteId;
  final String content;
  final String? title;
  NoteUpdateRequested({
    required this.noteId,
    required this.content,
    this.title,
  });
  @override
  List<Object?> get props => [noteId, content, title];
}

class NoteDeleteRequested extends NotesEvent {
  final String noteId;
  NoteDeleteRequested(this.noteId);
  @override
  List<Object?> get props => [noteId];
}

class NoteDecryptRequested extends NotesEvent {
  final Note note;
  final String pin;
  NoteDecryptRequested({required this.note, required this.pin});
  @override
  List<Object?> get props => [note.id, pin];
}

class ReEncryptAllNotesRequested extends NotesEvent {
  final String oldPin;
  final String newPin;
  ReEncryptAllNotesRequested({required this.oldPin, required this.newPin});
  @override
  List<Object?> get props => [oldPin, newPin];
}

// ─── States ──────────────────────────────────────────────────────────────────

abstract class NotesState extends Equatable {
  @override
  List<Object?> get props => [];
}

class NotesInitial extends NotesState {}

class NotesLoading extends NotesState {}

class NotesLoaded extends NotesState {
  final List<Note> notes;
  NotesLoaded(this.notes);
  @override
  List<Object?> get props => [notes];
}

class NotesError extends NotesState {
  final String message;
  NotesError(this.message);
  @override
  List<Object?> get props => [message];
}

class NoteOperationSuccess extends NotesState {
  final String message;
  NoteOperationSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class NoteDecrypted extends NotesState {
  final Note note;
  final String decryptedContent;
  final String? decryptedTitle;
  NoteDecrypted({
    required this.note,
    required this.decryptedContent,
    this.decryptedTitle,
  });
  @override
  List<Object?> get props => [note.id, decryptedContent];
}

class ReEncryptInProgress extends NotesState {
  final String message;
  ReEncryptInProgress([this.message = 'Mengubah PIN...']);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────

class NotesBloc extends Bloc<NotesEvent, NotesState> {
  final NotesRepository _notesRepository;

  NotesBloc({required NotesRepository notesRepository})
      : _notesRepository = notesRepository,
        super(NotesInitial()) {
    on<NotesLoadRequested>(_onLoadRequested);
    on<NoteCreateRequested>(_onCreateRequested);
    on<NoteUpdateRequested>(_onUpdateRequested);
    on<NoteDeleteRequested>(_onDeleteRequested);
    on<NoteDecryptRequested>(_onDecryptRequested);
    on<ReEncryptAllNotesRequested>(_onReEncryptRequested);
  }

  NotesRepository get notesRepository => _notesRepository;

  Future<void> _onLoadRequested(
    NotesLoadRequested event,
    Emitter<NotesState> emit,
  ) async {
    emit(NotesLoading());
    try {
      final notes = await _notesRepository.getNotes();
      emit(NotesLoaded(notes));
    } on NotesException catch (e) {
      emit(NotesError(e.message));
    } catch (e) {
      emit(NotesError('Gagal memuat catatan.'));
    }
  }

  Future<void> _onCreateRequested(
    NoteCreateRequested event,
    Emitter<NotesState> emit,
  ) async {
    emit(NotesLoading());
    try {
      await _notesRepository.createNote(
        content: event.content,
        title: event.title,
      );
      emit(NoteOperationSuccess('Catatan berhasil dibuat.'));
      // Reload notes
      final notes = await _notesRepository.getNotes();
      emit(NotesLoaded(notes));
    } on NotesException catch (e) {
      emit(NotesError(e.message));
    } catch (e) {
      emit(NotesError('Gagal membuat catatan.'));
    }
  }

  Future<void> _onUpdateRequested(
    NoteUpdateRequested event,
    Emitter<NotesState> emit,
  ) async {
    emit(NotesLoading());
    try {
      await _notesRepository.updateNote(
        noteId: event.noteId,
        content: event.content,
        title: event.title,
      );
      emit(NoteOperationSuccess('Catatan berhasil diperbarui.'));
      final notes = await _notesRepository.getNotes();
      emit(NotesLoaded(notes));
    } on NotesException catch (e) {
      emit(NotesError(e.message));
    } catch (e) {
      emit(NotesError('Gagal memperbarui catatan.'));
    }
  }

  Future<void> _onDeleteRequested(
    NoteDeleteRequested event,
    Emitter<NotesState> emit,
  ) async {
    emit(NotesLoading());
    try {
      await _notesRepository.deleteNote(event.noteId);
      emit(NoteOperationSuccess('Catatan berhasil dihapus.'));
      final notes = await _notesRepository.getNotes();
      emit(NotesLoaded(notes));
    } on NotesException catch (e) {
      emit(NotesError(e.message));
    } catch (e) {
      emit(NotesError('Gagal menghapus catatan.'));
    }
  }

  Future<void> _onDecryptRequested(
    NoteDecryptRequested event,
    Emitter<NotesState> emit,
  ) async {
    try {
      final decryptedContent = _notesRepository.decryptContent(
        event.note,
        event.pin,
      );
      String? decryptedTitle;
      if (event.note.titleEncrypted != null) {
        decryptedTitle = _notesRepository.decryptContent(
          event.note.copyWith(
            ciphertext: event.note.titleEncrypted,
          ),
          event.pin,
        );
      }
      emit(NoteDecrypted(
        note: event.note,
        decryptedContent: decryptedContent,
        decryptedTitle: decryptedTitle,
      ));
    } catch (e) {
      emit(NotesError('Gagal mendekripsi. PIN mungkin salah.'));
    }
  }

  Future<void> _onReEncryptRequested(
    ReEncryptAllNotesRequested event,
    Emitter<NotesState> emit,
  ) async {
    emit(ReEncryptInProgress('Mengubah PIN...'));
    try {
      await _notesRepository.reEncryptAllNotes(
        oldPin: event.oldPin,
        newPin: event.newPin,
      );
      emit(NoteOperationSuccess('PIN berhasil diubah.'));
      final notes = await _notesRepository.getNotes();
      emit(NotesLoaded(notes));
    } on NotesException catch (e) {
      emit(NotesError(e.message));
    } catch (e) {
      emit(NotesError('Gagal mengubah PIN. Pastikan PIN lama benar.'));
    }
  }
}
