import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../common.dart';
import '../remote_hostname.dart';

class LocalAddressBook extends StatefulWidget {
  const LocalAddressBook({Key? key}) : super(key: key);

  @override
  State<LocalAddressBook> createState() => _LocalAddressBookState();
}

class _LocalAddressBookEntry {
  String name;
  String address;
  // Password is intentionally session-only until portable authenticated
  // encryption/key import is implemented. Never write it in plaintext.
  String password;
  _LocalAddressBookEntry(this.name, this.address, [this.password = '']);
  Map<String, dynamic> toJson() => {'name': name, 'address': address};
  factory _LocalAddressBookEntry.fromJson(Map<String, dynamic> j) =>
      _LocalAddressBookEntry((j['name'] ?? '').toString(), (j['address'] ?? '').toString());
}

class _LocalAddressBookState extends State<LocalAddressBook> {
  final List<_LocalAddressBookEntry> _entries = [];
  final _search = TextEditingController();
  bool _loading = true;
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<File> _bookFile() async {
    // Use a predictable per-user location on both Windows and Linux.
    final support = await getApplicationSupportDirectory();
    final folder = Directory('${support.path}${Platform.pathSeparator}TACOMPUTER_RustDesk');
    await folder.create(recursive: true);
    final destination = File('${folder.path}${Platform.pathSeparator}Address_Book.txt');

    // Migrate a previous portable address book only if the new file is absent.
    // Never overwrite an existing address book.
    if (!await destination.exists()) {
      final executableDir = File(Platform.resolvedExecutable).parent;
      final legacy = File('${executableDir.path}${Platform.pathSeparator}Address_Book.txt');
      if (await legacy.exists()) {
        final oldText = await legacy.readAsString();
        try {
          final oldData = jsonDecode(oldText);
          if (oldData is Map && oldData['devices'] is List) {
            await destination.writeAsString(oldText, flush: true);
          }
        } catch (e) {
          debugPrint('Local Address Book migration skipped: $e');
        }
      }
    }
    return destination;
  }

  Future<void> _showBookPath() async {
    try {
      final file = _file ?? await _bookFile();
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Local Address Book file'),
        content: SelectableText(file.path),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (e) {
      _showBookError(e);
    }
  }

  void _showBookError(Object error) {
    debugPrint('Local Address Book error: $error');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Address Book file error: $error')),
      );
    }
  }

  Future<void> _load() async {
    try {
      _file = await _bookFile();
      if (await _file!.exists()) {
        final data = jsonDecode(await _file!.readAsString());
        if (data is Map && data['devices'] is List) {
          _entries.addAll((data['devices'] as List)
              .whereType<Map>()
              .map((e) => _LocalAddressBookEntry.fromJson(Map<String, dynamic>.from(e)))
              .where((e) => e.address.isNotEmpty));
        }
      }
    } catch (e) {
      _showBookError(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    _file ??= await _bookFile();
    await _file!.writeAsString(const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'devices': _entries.map((e) => e.toJson()).toList(),
    }), flush: true);
  }

  Future<void> _edit([_LocalAddressBookEntry? entry]) async {
    final name = TextEditingController(text: entry?.name ?? '');
    final address = TextEditingController(text: entry?.address ?? '');
    final password = TextEditingController(text: entry?.password ?? '');
    final result = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(entry == null ? 'Add device' : 'Edit device'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Computer name / Label', border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 18),
            TextField(controller: address, decoration: const InputDecoration(labelText: 'RustDesk ID / IP:Port / Hostname:Port', border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 18),
            TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password (optional; session only)', border: OutlineInputBorder(), isDense: true)),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))],
    ));
    if (result == true && address.text.trim().isNotEmpty) {
      setState(() {
        if (entry == null) {
          _entries.add(_LocalAddressBookEntry(name.text.trim(), address.text.trim(), password.text));
        } else {
          entry.name = name.text.trim();
          entry.address = address.text.trim();
          entry.password = password.text;
        }
      });
      try {
        await _save();
      } catch (e) {
        _showBookError(e);
      }
    }
    name.dispose(); address.dispose(); password.dispose();
  }

  Future<void> _connect(_LocalAddressBookEntry entry) async {
    var target = entry.address.trim();
    target = await resolveRemoteHostname(target);
    if (!mounted) return;
    connect(context, target, password: entry.password.isEmpty ? null : entry.password);
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.toLowerCase();
    final visible = _entries.where((e) => '${e.name} ${e.address}'.toLowerCase().contains(query)).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: Row(children: [
        Expanded(child: TextField(controller: _search, onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name, ID, IP or hostname', isDense: true))),
        IconButton(tooltip: 'Address Book file location', onPressed: _showBookPath, icon: const Icon(Icons.folder_open)),
        IconButton(tooltip: 'Add device', onPressed: () => _edit(), icon: const Icon(Icons.add)),
      ])),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : visible.isEmpty
        ? const Center(child: Text('No local devices. Select + to add one.'))
        : Scrollbar(child: ListView.separated(itemCount: visible.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final e = visible[i];
            return ListTile(dense: true, leading: const Icon(Icons.computer),
              title: Text(e.name.isEmpty ? e.address : e.name), subtitle: Text(e.address),
              trailing: Wrap(children: [
                TextButton(onPressed: () => _connect(e), child: const Text('Connect')),
                PopupMenuButton<String>(onSelected: (v) async {
                  if (v == 'edit') await _edit(e);
                  if (v == 'delete') { setState(() => _entries.remove(e)); try { await _save(); } catch (err) { _showBookError(err); } }
                }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete'))]),
              ]));
          }))),
    ]);
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }
}
