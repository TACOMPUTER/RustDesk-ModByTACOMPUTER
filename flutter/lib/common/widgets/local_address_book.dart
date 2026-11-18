import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../common.dart';

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
    // Prefer the portable app folder; fall back to per-user support storage
    // when an installed location (for example /usr/lib or Program Files) is read-only.
    final executableDir = File(Platform.resolvedExecutable).parent;
    final portableFile = File('${executableDir.path}${Platform.pathSeparator}Address_Book.txt');
    try {
      await portableFile.parent.create(recursive: true);
      await portableFile.writeAsString(await portableFile.exists() ? await portableFile.readAsString() : '');
      return portableFile;
    } catch (_) {
      final dir = await getApplicationSupportDirectory();
      final appDir = Directory('${dir.path}${Platform.pathSeparator}TACOMPUTER_RustDesk');
      if (!await appDir.exists()) await appDir.create(recursive: true);
      return File('${appDir.path}${Platform.pathSeparator}Address_Book.txt');
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
      debugPrint('Local Address Book load failed: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    _file ??= await _bookFile();
    await _file!.writeAsString(const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'devices': _entries.map((e) => e.toJson()).toList(),
    }));
  }

  Future<void> _edit([_LocalAddressBookEntry? entry]) async {
    final name = TextEditingController(text: entry?.name ?? '');
    final address = TextEditingController(text: entry?.address ?? '');
    final password = TextEditingController(text: entry?.password ?? '');
    final result = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(entry == null ? 'Add device' : 'Edit device'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Computer name / Label')),
        TextField(controller: address, decoration: const InputDecoration(labelText: 'RustDesk ID / IP / Hostname')),
        TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password (optional; session only)')),
      ])),
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
      await _save();
    }
    name.dispose(); address.dispose(); password.dispose();
  }

  Future<void> _connect(_LocalAddressBookEntry entry) async {
    var target = entry.address.trim();
    // Preserve RustDesk IDs; resolve hostnames to an address for Direct IP.
    final numericId = RegExp(r'^[0-9]{6,}$').hasMatch(target);
    if (!numericId && InternetAddress.tryParse(target) == null) {
      // Try DNS/hosts lookup for machine names and FQDNs. If lookup fails,
      // fall back to the original value as a possible custom RustDesk ID.
      try {
        final addresses = await InternetAddress.lookup(target);
        if (addresses.isNotEmpty) target = addresses.first.address;
      } catch (_) {
        // Keep target unchanged; RustDesk will handle it as an ID.
      }
    }
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
                  if (v == 'delete') { setState(() => _entries.remove(e)); await _save(); }
                }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete'))]),
              ]));
          }))),
    ]);
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }
}
