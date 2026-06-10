import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _historyService = HistoryService();

  List<Map<String, dynamic>> files = [];

  String searchQuery = '';
  String sortBy = 'date';

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    final result = await _historyService.getHistory(
      searchQuery: searchQuery,
      sortBy: sortBy,
    );

    setState(() {
      files = result;
    });
  }

  Icon getFileIcon(String fileType) {
    if (fileType == 'text') {
      return const Icon(Icons.text_snippet);
    }

    if (fileType == 'pdf') {
      return const Icon(Icons.picture_as_pdf);
    }

    if (fileType == 'image') {
      return const Icon(Icons.image);
    }

    return const Icon(Icons.description);
  }

  String formatDate(String date) {
    final parsedDate = DateTime.parse(date);
    return DateFormat('dd.MM.yyyy HH:mm').format(parsedDate);
  }

  String openedLabel(String date) {
    final parsedDate = DateTime.parse(date);
    final now = DateTime.now();

    final difference = now.difference(parsedDate).inDays;

    if (difference == 0) {
      return 'Opened today';
    } else if (difference == 1) {
      return 'Opened yesterday';
    } else {
      return 'Opened $difference days ago';
    }
  }

  Future<void> confirmClearHistory() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Бришење историја?'),
          content: const Text(
            'Ова ќе ги избрише сите твои зачувани фајлови.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Откажи'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Избриши'),
            ),
          ],
        );
      },
    );

    if (shouldClear == true) {
      await _historyService.clearHistory();
      await loadHistory();
    }
  }

  void openFileAgain(Map<String, dynamic> file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Отвори фајл: ${file['fileName']}',
        ),
      ),
    );

    // TODO:
    // Тука подоцна поврзи го вашиот ReaderScreen.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Историја'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: confirmClearHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Пребарувај фајлови...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) async {
                searchQuery = value;
                await loadHistory();
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonFormField<String>(
              value: sortBy,
              decoration: const InputDecoration(
                labelText: 'Сортирај според',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'date',
                  child: Text('Датум'),
                ),
                DropdownMenuItem(
                  value: 'name',
                  child: Text('Име'),
                ),
                DropdownMenuItem(
                  value: 'favorite',
                  child: Text('Омилени'),
                ),
              ],
              onChanged: (value) async {
                sortBy = value!;
                await loadHistory();
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${files.length} зачувани фајлови',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          Expanded(
            child: files.isEmpty
                ? const Center(
              child: Text(
                'Нема зачувани фајлови во твојата историја.',
                style: TextStyle(fontSize: 18),
              ),
            )
                : ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];

                return Dismissible(
                  key: Key(file['id'].toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (_) async {
                    await _historyService.deleteFile(
                      file['id'],
                    );

                    await loadHistory();
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: getFileIcon(file['fileType']),
                      title: Text(
                        file['fileName'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${formatDate(file['createdAt'])}\n${openedLabel(file['createdAt'])}',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: Icon(
                          file['isFavorite'] == 1
                              ? Icons.star
                              : Icons.star_border,
                        ),
                        onPressed: () async {
                          await _historyService.toggleFavorite(
                            id: file['id'],
                            currentValue: file['isFavorite'],
                          );

                          await loadHistory();
                        },
                      ),
                      onTap: () {
                        openFileAgain(file);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}