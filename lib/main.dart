import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_nfc_hce/flutter_nfc_hce.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => NFCProvider(),
      child: MaterialApp(
        title: 'NFC Tech',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2196F3),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2196F3),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        ),
        home: const NFCHomePage(),
      ),
    );
  }
}

class NFCProvider extends ChangeNotifier {
  bool _isNFCAvailable = false;
  bool _isEmulating = false;
  List<NFCTag> _savedTags = [];
  NFCTag? _currentTag;
  String _status = 'Ready';

  bool get isNFCAvailable => _isNFCAvailable;
  bool get isEmulating => _isEmulating;
  List<NFCTag> get savedTags => _savedTags;
  NFCTag? get currentTag => _currentTag;
  String get status => _status;

  void updateStatus(String status) {
    _status = status;
    notifyListeners();
  }

  void setNFCAvailability(bool available) {
    _isNFCAvailable = available;
    notifyListeners();
  }

  void setEmulationStatus(bool emulating) {
    _isEmulating = emulating;
    notifyListeners();
  }

  void setCurrentTag(NFCTag? tag) {
    _currentTag = tag;
    notifyListeners();
  }

  void addSavedTag(NFCTag tag) {
    _savedTags.add(tag);
    _saveTags();
    notifyListeners();
  }

  void removeSavedTag(int index) {
    _savedTags.removeAt(index);
    _saveTags();
    notifyListeners();
  }

  Future<void> _saveTags() async {
    final prefs = await SharedPreferences.getInstance();
    final tagsJson =
        _savedTags
            .map(
              (tag) => {
                'id': tag.id,
                'type': tag.type.toString(),
                'standard': tag.standard.toString(),
              },
            )
            .toList();
    await prefs.setString('saved_tags', jsonEncode(tagsJson));
  }

  Future<void> loadSavedTags() async {
    final prefs = await SharedPreferences.getInstance();
    final tagsString = prefs.getString('saved_tags');
    if (tagsString != null) {
      final tagsList = jsonDecode(tagsString) as List;
      // Note: This is simplified - in a real app you'd store full tag data
      notifyListeners();
    }
  }
}

class NFCHomePage extends StatefulWidget {
  const NFCHomePage({super.key});

  @override
  State<NFCHomePage> createState() => _NFCHomePageState();
}

class _NFCHomePageState extends State<NFCHomePage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _flutterNfcHcePlugin = FlutterNfcHce();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkNFCAvailability();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkNFCAvailability() async {
    try {
      final availability = await FlutterNfcKit.nfcAvailability;
      final provider = Provider.of<NFCProvider>(context, listen: false);

      provider.setNFCAvailability(availability == NFCAvailability.available);

      if (availability == NFCAvailability.available) {
        provider.updateStatus('NFC is available and ready');
      } else {
        provider.updateStatus('NFC is not available on this device');
      }
    } catch (e) {
      Provider.of<NFCProvider>(
        context,
        listen: false,
      ).updateStatus('Error checking NFC: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Tech'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.nfc), text: 'Read'),
            Tab(icon: Icon(Icons.credit_card), text: 'Emulate'),
            Tab(icon: Icon(Icons.storage), text: 'Saved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [NFCReaderTab(), NFCEmulatorTab(), SavedTagsTab()],
      ),
    );
  }
}

class NFCReaderTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<NFCProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.nfc,
                        size: 64,
                        color:
                            provider.isNFCAvailable ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        provider.status,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (provider.isNFCAvailable)
                ElevatedButton.icon(
                  onPressed: () => _readNFCTag(context),
                  icon: const Icon(Icons.tap_and_play),
                  label: const Text('Scan NFC Tag'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              if (provider.currentTag != null) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last Scanned Tag',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('ID: ${provider.currentTag!.id}'),
                        Text('Type: ${provider.currentTag!.type}'),
                        Text('Standard: ${provider.currentTag!.standard}'),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _saveTag(context),
                              icon: const Icon(Icons.save),
                              label: const Text('Save Tag'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _emulateCurrentTag(context),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Emulate'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _readNFCTag(BuildContext context) async {
    final provider = Provider.of<NFCProvider>(context, listen: false);

    try {
      provider.updateStatus('Hold your device near an NFC tag...');

      final tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
        iosMultipleTagMessage: "Multiple tags found!",
        iosAlertMessage: "Scan your NFC tag",
      );

      provider.setCurrentTag(tag);
      provider.updateStatus('Tag scanned successfully!');

      // Vibrate to give feedback
      HapticFeedback.mediumImpact();
    } catch (e) {
      provider.updateStatus('Error reading tag: $e');
    } finally {
      await FlutterNfcKit.finish();
    }
  }

  void _saveTag(BuildContext context) {
    final provider = Provider.of<NFCProvider>(context, listen: false);
    if (provider.currentTag != null) {
      provider.addSavedTag(provider.currentTag!);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tag saved successfully!')));
    }
  }

  void _emulateCurrentTag(BuildContext context) {
    final provider = Provider.of<NFCProvider>(context, listen: false);
    if (provider.currentTag != null) {
      // Switch to emulator tab and start emulation
      DefaultTabController.of(context).animateTo(1);
      // Start emulation with current tag data
    }
  }
}

class NFCEmulatorTab extends StatefulWidget {
  @override
  State<NFCEmulatorTab> createState() => _NFCEmulatorTabState();
}

class _NFCEmulatorTabState extends State<NFCEmulatorTab> {
  final _flutterNfcHcePlugin = FlutterNfcHce();
  bool _isEmulating = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<NFCProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.credit_card,
                        size: 64,
                        color: _isEmulating ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isEmulating
                            ? 'Device is emulating an NFC card'
                            : 'Ready to emulate NFC card',
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (provider.currentTag != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ready to Emulate',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Tag ID: ${provider.currentTag!.id}'),
                        Text('Type: ${provider.currentTag!.type}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        _isEmulating ? null : () => _startEmulation(context),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Emulation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed:
                        !_isEmulating ? null : () => _stopEmulation(context),
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Emulation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_isEmulating)
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.security,
                          color: Colors.green,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your device is now acting as an NFC card!\nTap it against NFC readers to unlock doors.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startEmulation(BuildContext context) async {
    final provider = Provider.of<NFCProvider>(context, listen: false);

    try {
      // Check if NFC HCE is supported
      bool? isNfcHceSupported = await _flutterNfcHcePlugin.isNfcHceSupported();
      bool? isNfcEnabled = await _flutterNfcHcePlugin.isNfcEnabled();

      if (isNfcHceSupported != true) {
        provider.updateStatus('NFC HCE is not supported on this device');
        return;
      }

      if (isNfcEnabled != true) {
        provider.updateStatus(
          'NFC is not enabled. Please enable NFC in settings.',
        );
        return;
      }

      // Start HCE with tag data
      String tagData = provider.currentTag?.id ?? 'DEFAULT_CARD_DATA';
      var result = await _flutterNfcHcePlugin.startNfcHce(tagData);

      setState(() {
        _isEmulating = true;
      });

      provider.updateStatus('Emulation started successfully!');
      provider.setEmulationStatus(true);

      // Vibrate to confirm
      HapticFeedback.mediumImpact();
    } catch (e) {
      provider.updateStatus('Error starting emulation: $e');
    }
  }

  Future<void> _stopEmulation(BuildContext context) async {
    final provider = Provider.of<NFCProvider>(context, listen: false);

    try {
      await _flutterNfcHcePlugin.stopNfcHce();

      setState(() {
        _isEmulating = false;
      });

      provider.updateStatus('Emulation stopped');
      provider.setEmulationStatus(false);
    } catch (e) {
      provider.updateStatus('Error stopping emulation: $e');
    }
  }
}

class SavedTagsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<NFCProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (provider.savedTags.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.storage, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No saved tags yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scan and save NFC tags to access them later',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.savedTags.length,
                    itemBuilder: (context, index) {
                      final tag = provider.savedTags[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.nfc),
                          title: Text('Tag ${index + 1}'),
                          subtitle: Text('ID: ${tag.id}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_arrow),
                                onPressed: () {
                                  // Start emulation with this tag
                                  provider.setCurrentTag(tag);
                                  DefaultTabController.of(context).animateTo(1);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => provider.removeSavedTag(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
