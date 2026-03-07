import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/thought.dart';
import '../data/thought_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.userId});

  final String userId;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repository = ThoughtRepository(FirebaseFirestore.instance);
  Mood _selectedMood = Mood.neutral;

  Future<void> _showAddThoughtSheet() async {
    final contentController = TextEditingController();
    final tagsController = TextEditingController();
    Mood selectedMood = _selectedMood;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Thought', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Write what is on your mind...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Mood>(
                value: selectedMood,
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Mood'),
                items: Mood.values
                    .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedMood = value;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  hintText: 'Tags (comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final content = contentController.text.trim();
                    if (content.isEmpty) return;
                    final tags = tagsController.text
                        .split(',')
                        .map((tag) => tag.trim().toLowerCase())
                        .where((tag) => tag.isNotEmpty)
                        .toSet()
                        .toList();

                    await _repository.addThought(
                      userId: widget.userId,
                      content: content,
                      mood: selectedMood,
                      tags: tags,
                    );

                    if (!mounted) return;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save Thought'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ThoughtNest'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddThoughtSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Thought'),
      ),
      body: StreamBuilder<List<Thought>>(
        stream: _repository.watchThoughts(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final thoughts = snapshot.data ?? [];
          if (thoughts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No thoughts yet. Add your first one.'),
              ),
            );
          }

          final moodCount = <Mood, int>{};
          for (final thought in thoughts) {
            moodCount.update(thought.mood, (value) => value + 1, ifAbsent: () => 1);
          }

          return Column(
            children: [
              Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: Mood.values.map((m) {
                      final count = moodCount[m] ?? 0;
                      return Chip(label: Text('${m.name}: $count'));
                    }).toList(),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: thoughts.length,
                  itemBuilder: (context, index) {
                    final thought = thoughts[index];
                    return Dismissible(
                      key: ValueKey(thought.id),
                      background: Container(
                        color: Colors.red.shade300,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _repository.deleteThought(
                        userId: widget.userId,
                        thoughtId: thought.id,
                      ),
                      child: ListTile(
                        title: Text(thought.content),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${DateFormat.yMMMd().add_jm().format(thought.createdAt)}  |  ${thought.mood.name}'),
                            if (thought.tags.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Wrap(
                                  spacing: 6,
                                  children: thought.tags.map((tag) => Chip(label: Text(tag))).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
