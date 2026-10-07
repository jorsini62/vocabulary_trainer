import 'package:flutter/material.dart';

import '../../domain/configuration.dart';
import '../../domain/study_set.dart';
import '../../domain/vocabulary_item.dart';
import '../../repository/sqlite_configuration_repository.dart';
import '../../repository/sqlite_study_set_repository.dart';
import '../../repository/sqlite_vocabulary_repository.dart';

class MobileManageMembershipScreen extends StatefulWidget {
  final int? initialStudySetId;

  const MobileManageMembershipScreen({
    super.key,
    this.initialStudySetId,
  });

  @override
  State<MobileManageMembershipScreen> createState() =>
      _MobileManageMembershipScreenState();
}

enum _MembershipAction { add, remove }

class _MobileManageMembershipScreenState
    extends State<MobileManageMembershipScreen> {
  final SQLiteVocabularyRepository _vocabularyRepository =
      SQLiteVocabularyRepository();
  final SQLiteStudySetRepository _studySetRepository =
      SQLiteStudySetRepository();
  final SQLiteConfigurationRepository _configurationRepository =
      SQLiteConfigurationRepository();

  final TextEditingController _searchController = TextEditingController();

  List<VocabularyItem> _vocabularyItems = [];
  List<StudySet> _studySets = [];
  Map<int, Set<int>> _studySetMemberships = {};

  _MembershipAction? _action;
  StudySet? _selectedStudySet;
  final Set<int> _selectedVocabularyItemIds = {};
  bool _loading = true;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final configuration = await _configurationRepository.getConfiguration();

    if (configuration == null || configuration.currentLanguagePairId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    final vocabularyItems = await _vocabularyRepository
        .getVocabularyItemsByLanguageCombinationId(
      configuration.currentLanguagePairId!,
    );

    final allStudySets = await _studySetRepository
        .getStudySetsByLanguageCombinationId(
      configuration.currentLanguagePairId!,
    );

    final userStudySets = allStudySets
        .where((studySet) => !studySet.isDefaultStudySet)
        .toList();

    final memberships = <int, Set<int>>{};
    for (final item in vocabularyItems) {
      if (item.id == null) continue;
      memberships[item.id!] = await _studySetRepository
          .getStudySetIdsForVocabularyItem(item.id!);
    }

    StudySet? initialStudySet;
    final preferredId = widget.initialStudySetId ?? configuration.currentStudySetId;

    if (preferredId != null) {
      for (final studySet in userStudySets) {
        if (studySet.id == preferredId) {
          initialStudySet = studySet;
          break;
        }
      }
    }

    initialStudySet ??= userStudySets.isNotEmpty ? userStudySets.first : null;

    if (!mounted) return;

    setState(() {
      _vocabularyItems = vocabularyItems;
      _studySets = userStudySets;
      _studySetMemberships = memberships;
      _selectedStudySet = initialStudySet;
      _loading = false;
    });
  }

  List<VocabularyItem> get _filteredVocabularyItems {
    final searchText = _searchController.text.trim().toLowerCase();

    return _vocabularyItems.where((item) {
      if (searchText.isNotEmpty) {
        final matchesSearch =
            item.sourceExpression.toLowerCase().contains(searchText) ||
            item.targetExpression.toLowerCase().contains(searchText);
        if (!matchesSearch) return false;
      }

      // Remove: only show items that already belong to the selected Study Set.
      // Add: show all items; those already in the Study Set are greyed out.
      if (_action == _MembershipAction.remove &&
          _selectedStudySet?.id != null &&
          item.id != null) {
        final memberships = _studySetMemberships[item.id!] ?? <int>{};
        return memberships.contains(_selectedStudySet!.id);
      }

      return true;
    }).toList();
  }

  bool _isEligible(VocabularyItem item) {
    if (_action == null || _selectedStudySet?.id == null || item.id == null) {
      return false;
    }

    final memberships = _studySetMemberships[item.id!] ?? <int>{};
    final isMember = memberships.contains(_selectedStudySet!.id);

    return _action == _MembershipAction.add ? !isMember : isMember;
  }

  String _studySetName(StudySet studySet) {
    return studySet.name;
  }

  String get _operationTitle {
    switch (_action) {
      case _MembershipAction.add:
        return 'Add to Study Set';
      case _MembershipAction.remove:
        return 'Remove from Study Set';
      case null:
        return 'Manage Membership';
    }
  }


  void _changeAction(_MembershipAction? action) {
    if (action == null) return;

    setState(() {
      _action = action;
      _selectedVocabularyItemIds.clear();
    });
  }

  void _changeStudySet(StudySet? studySet) {
    setState(() {
      _selectedStudySet = studySet;
      _selectedVocabularyItemIds.clear();
    });
  }

  void _toggleVocabularyItem(VocabularyItem item) {
    if (!_isEligible(item) || item.id == null) return;

    setState(() {
      if (_selectedVocabularyItemIds.contains(item.id)) {
        _selectedVocabularyItemIds.remove(item.id);
      } else {
        _selectedVocabularyItemIds.add(item.id!);
      }
    });
  }

  Future<void> _applyChanges() async {
    if (_action == null || _selectedStudySet?.id == null ||
        _selectedVocabularyItemIds.isEmpty || _applying) {
      return;
    }

    final selectedCount = _selectedVocabularyItemIds.length;
    final studySetName = _selectedStudySet!.name;
    final action = _action!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final verb = action == _MembershipAction.add ? 'Add' : 'Remove';
        final preposition = action == _MembershipAction.add ? 'to' : 'from';

        return AlertDialog(
          title: Text('$verb Vocabulary Items'),
          content: Text(
            '$verb $selectedCount vocabulary '
            '${selectedCount == 1 ? 'item' : 'items'} $preposition '
            '"$studySetName"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(verb),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _applying = true;
    });

    try {
      final selectedItems = _vocabularyItems.where(
        (item) => _selectedVocabularyItemIds.contains(item.id),
      );

      for (final item in selectedItems) {
        if (item.id == null) continue;

        if (action == _MembershipAction.add) {
          await _studySetRepository.addVocabularyItemToStudySet(
            item.id!,
            _selectedStudySet!.id!,
          );
          (_studySetMemberships[item.id!] ??= <int>{})
              .add(_selectedStudySet!.id!);
        } else {
          await _studySetRepository.removeVocabularyItemFromStudySet(
            item.id!,
            _selectedStudySet!.id!,
          );
          (_studySetMemberships[item.id!] ??= <int>{})
              .remove(_selectedStudySet!.id!);
        }
      }

      if (!mounted) return;

      setState(() {
        _selectedVocabularyItemIds.clear();
        _applying = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == _MembershipAction.add
                ? '$selectedCount ${selectedCount == 1 ? 'item' : 'items'} added to $studySetName.'
                : '$selectedCount ${selectedCount == 1 ? 'item' : 'items'} removed from $studySetName.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _applying = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Membership change failed: $error'),
        ),
      );
    }
  }

  Widget _buildActionSection() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What do you want to do?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<_MembershipAction>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: const Text('Add'),
                    value: _MembershipAction.add,
                    groupValue: _action,
                    onChanged: _applying ? null : _changeAction,
                  ),
                ),
                Expanded(
                  child: RadioListTile<_MembershipAction>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: const Text('Remove'),
                    value: _MembershipAction.remove,
                    groupValue: _action,
                    onChanged: _applying ? null : _changeAction,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudySetSection() {
    final enabled = _action != null && !_applying && _studySets.isNotEmpty;
    final label = _action == _MembershipAction.add
        ? 'Add to which Study Set?'
        : 'Remove from which Study Set?';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedStudySet?.id,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              hint: const Text('Select a Study Set'),
              items: _studySets.map((studySet) {
                return DropdownMenuItem<int>(
                  value: studySet.id!,
                  child: Text(_studySetName(studySet)),
                );
              }).toList(),
              onChanged: enabled
                  ? (studySetId) {
                      if (studySetId == null) return;
                      _changeStudySet(
                        _studySets.firstWhere(
                          (studySet) => studySet.id == studySetId,
                        ),
                      );
                    }
                  : null,
            ),
            if (_action == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Choose Add or Remove first.'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVocabularyItem(VocabularyItem item) {
    final eligible = _isEligible(item);
    final selected = _selectedVocabularyItemIds.contains(item.id);
    return Opacity(
      opacity: eligible ? 1.0 : 0.55,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: InkWell(
          onTap: eligible && !_applying
              ? () => _toggleVocabularyItem(item)
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: eligible && !_applying
                      ? (_) => _toggleVocabularyItem(item)
                      : null,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.sourceExpression,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        item.targetExpression,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildEmptyState() {
    if (_studySets.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'There are no user Study Sets to manage.\n\n'
            'Repository membership is permanent and cannot be changed here.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_action == null || _selectedStudySet == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Choose an action and a Study Set to begin selecting Vocabulary Items.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_filteredVocabularyItems.isEmpty) {
      final message = _action == _MembershipAction.add
          ? 'No Vocabulary Items match the current search.'
          : 'This Study Set has no Vocabulary Items to remove.';

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
    }

    if (_action == _MembershipAction.add &&
        _filteredVocabularyItems.every((item) => !_isEligible(item))) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'All Vocabulary Items shown are already in this Study Set.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredVocabularyItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Membership'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildActionSection(),
                _buildStudySetSection(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: TextField(
                    controller: _searchController,
                    enabled: !_applying,
                    onChanged: (_) => setState(() {
                      _selectedVocabularyItemIds.clear();
                    }),
                    decoration: const InputDecoration(
                      labelText: 'Search Vocabulary',
                      hintText: 'Source or target',
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                if (_action != null && _selectedStudySet != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_selectedVocabularyItemIds.length} selected',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                Expanded(
                  child: (_action == null || _selectedStudySet == null)
                      ? _buildEmptyState()
                      : filteredItems.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            return _buildVocabularyItem(filteredItems[index]);
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade400),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _applying
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Done'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _selectedVocabularyItemIds.isEmpty ||
                                    _action == null ||
                                    _selectedStudySet == null ||
                                    _applying
                                ? null
                                : _applyChanges,
                            child: Text(
                              _applying ? 'Applying...' : 'Confirm',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
