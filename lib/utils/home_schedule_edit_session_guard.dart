enum HomeScheduleEditSessionState {
  idle,
  saving,
  moved,
  deleted,
  completed,
  disposed,
}

enum HomeScheduleEditMutationAction {
  save,
  delete,
}

class HomeScheduleEditMutationAttempt {
  const HomeScheduleEditMutationAttempt({
    required this.allowed,
    required this.mutationId,
    required this.stateBefore,
    this.ignoredReason,
  });

  final bool allowed;
  final String mutationId;
  final HomeScheduleEditSessionState stateBefore;
  final String? ignoredReason;
}

class HomeScheduleEditSessionGuard {
  HomeScheduleEditSessionGuard({
    required this.editSessionId,
    required String currentActualDocId,
    required String currentDataDocId,
    required DateTime? currentStartAt,
  })  : currentActualDocId = currentActualDocId.trim(),
        currentDataDocId = currentDataDocId.trim(),
        currentStartAt = currentStartAt;

  final String editSessionId;

  HomeScheduleEditSessionState state = HomeScheduleEditSessionState.idle;
  String currentActualDocId;
  String currentDataDocId;
  DateTime? currentStartAt;

  int _mutationSequence = 0;

  HomeScheduleEditMutationAttempt begin(
    HomeScheduleEditMutationAction action,
  ) {
    final stateBefore = state;
    final mutationId =
        '$editSessionId-${action.name}-${++_mutationSequence}';

    if (state != HomeScheduleEditSessionState.idle) {
      return HomeScheduleEditMutationAttempt(
        allowed: false,
        mutationId: mutationId,
        stateBefore: stateBefore,
        ignoredReason: 'state_${state.name}',
      );
    }

    state = HomeScheduleEditSessionState.saving;
    return HomeScheduleEditMutationAttempt(
      allowed: true,
      mutationId: mutationId,
      stateBefore: stateBefore,
    );
  }

  void completeSave({
    required String targetActualDocId,
    required String targetDataDocId,
    required DateTime targetStartAt,
    required bool moved,
  }) {
    if (state != HomeScheduleEditSessionState.saving) return;

    currentActualDocId = targetActualDocId.trim();
    currentDataDocId = targetDataDocId.trim();
    currentStartAt = targetStartAt;
    state = moved
        ? HomeScheduleEditSessionState.moved
        : HomeScheduleEditSessionState.completed;
  }

  void completeDelete() {
    if (state != HomeScheduleEditSessionState.saving) return;
    state = HomeScheduleEditSessionState.deleted;
  }

  void fail() {
    if (state != HomeScheduleEditSessionState.saving) return;
    state = HomeScheduleEditSessionState.idle;
  }

  void dispose() {
    state = HomeScheduleEditSessionState.disposed;
  }
}

Set<String> initialHomeScheduleEditSelectedDays(String currentDay) {
  final cleanDay = currentDay.trim();
  return cleanDay.isEmpty ? <String>{} : <String>{cleanDay};
}

class HomeScheduleEditSaveSelection {
  const HomeScheduleEditSaveSelection({
    required this.selectedDays,
    required this.explicitMultiDaySelection,
    required this.invariantCorrected,
    required this.correctionReason,
  });

  final Set<String> selectedDays;
  final bool explicitMultiDaySelection;
  final bool invariantCorrected;
  final String correctionReason;

  bool get isMultiDay =>
      explicitMultiDaySelection && selectedDays.length > 1;
}

HomeScheduleEditSaveSelection normalizeHomeScheduleEditSelectionForSave({
  required String currentTargetDay,
  required Set<String> selectedDays,
  required bool explicitMultiDaySelection,
}) {
  final cleanTargetDay = currentTargetDay.trim();
  final cleanSelectedDays = selectedDays
      .map((day) => day.trim())
      .where((day) => day.isNotEmpty)
      .toSet();

  if (!explicitMultiDaySelection) {
    final normalizedDays = cleanTargetDay.isEmpty
        ? <String>{}
        : <String>{cleanTargetDay};
    final corrected = cleanSelectedDays.length != normalizedDays.length ||
        !cleanSelectedDays.containsAll(normalizedDays);
    return HomeScheduleEditSaveSelection(
      selectedDays: normalizedDays,
      explicitMultiDaySelection: false,
      invariantCorrected: corrected,
      correctionReason: corrected
          ? 'implicit_single_selection_state_leak'
          : '',
    );
  }

  if (cleanSelectedDays.isEmpty && cleanTargetDay.isNotEmpty) {
    return HomeScheduleEditSaveSelection(
      selectedDays: <String>{cleanTargetDay},
      explicitMultiDaySelection: true,
      invariantCorrected: true,
      correctionReason: 'empty_explicit_selection',
    );
  }

  return HomeScheduleEditSaveSelection(
    selectedDays: cleanSelectedDays,
    explicitMultiDaySelection: true,
    invariantCorrected: false,
    correctionReason: '',
  );
}

class HomeScheduleEditSelectionState {
  HomeScheduleEditSelectionState.single({required String currentDay})
      : _selectedDays = initialHomeScheduleEditSelectedDays(currentDay);

  final Set<String> _selectedDays;
  bool explicitMultiDaySelection = false;
  String lastChangedCaller = 'editSession.open';
  String lastUserAction = 'initializeSingleLesson';

  Set<String> get selectedDays => Set<String>.unmodifiable(_selectedDays);

  bool toggleDay(
    String day, {
    required String caller,
    required String userAction,
  }) {
    final cleanDay = day.trim();
    if (cleanDay.isEmpty) return false;

    var changed = false;
    if (_selectedDays.contains(cleanDay)) {
      if (_selectedDays.length > 1) {
        _selectedDays.remove(cleanDay);
        changed = true;
      }
    } else {
      _selectedDays.add(cleanDay);
      changed = true;
    }

    if (changed) {
      explicitMultiDaySelection = true;
      lastChangedCaller = caller;
      lastUserAction = userAction;
    }
    return changed;
  }

  HomeScheduleEditSaveSelection prepareForSave({
    required String currentTargetDay,
  }) {
    final selection = normalizeHomeScheduleEditSelectionForSave(
      currentTargetDay: currentTargetDay,
      selectedDays: _selectedDays,
      explicitMultiDaySelection: explicitMultiDaySelection,
    );
    if (selection.invariantCorrected) {
      _selectedDays
        ..clear()
        ..addAll(selection.selectedDays);
      lastChangedCaller = 'lessonEditor.saveInvariant';
      lastUserAction = selection.correctionReason;
    }
    return selection;
  }

  void dispose() {
    _selectedDays.clear();
    explicitMultiDaySelection = false;
    lastChangedCaller = 'editSession.dispose';
    lastUserAction = 'clearTemporarySelection';
  }
}

bool isExplicitHomeScheduleMultiDay(
  Set<String> selectedDays, {
  bool explicitMultiDaySelection = true,
}) {
  return explicitMultiDaySelection && selectedDays.length > 1;
}
