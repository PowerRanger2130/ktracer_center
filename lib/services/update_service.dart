import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Represents an available update
class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String? changelog;
  final String? htmlUrl;
  final DateTime? publishedAt;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.changelog,
    this.htmlUrl,
    this.publishedAt,
  });
}

/// Download progress information
class DownloadProgress {
  final int downloaded;
  final int total;
  final double percentage;

  DownloadProgress({required this.downloaded, required this.total})
    : percentage = total > 0 ? (downloaded / total) * 100 : 0;
}

/// Service to check for updates from GitHub releases
class UpdateService extends ChangeNotifier {
  // TODO: Replace with your actual GitHub repository
  static const String _githubOwner = 'YOUR_GITHUB_USERNAME';
  static const String _githubRepo = 'ktracer_center';

  /// How often to check for updates in the background (4 hours)
  static const Duration _checkInterval = Duration(hours: 4);

  /// Minimum time between manual checks (1 minute)
  static const Duration _minCheckInterval = Duration(minutes: 1);

  String _currentVersion = '0.0.0';
  UpdateInfo? _availableUpdate;
  bool _isChecking = false;
  bool _isDownloading = false;
  DownloadProgress? _downloadProgress;
  String? _error;
  DateTime? _lastCheckTime;
  Timer? _periodicCheckTimer;
  bool _updateDismissed = false;

  // Getters
  String get currentVersion => _currentVersion;
  UpdateInfo? get availableUpdate => _availableUpdate;
  bool get isChecking => _isChecking;
  bool get isDownloading => _isDownloading;
  DownloadProgress? get downloadProgress => _downloadProgress;
  String? get error => _error;
  bool get hasUpdate => _availableUpdate != null && !_updateDismissed;
  bool get updateDismissed => _updateDismissed;

  /// Initialize the update service
  Future<void> init() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;
      notifyListeners();

      // Check for updates on startup
      await checkForUpdates(showErrors: false);

      // Start periodic checks
      _startPeriodicChecks();
    } catch (e) {
      debugPrint('UpdateService init error: $e');
    }
  }

  /// Start periodic background update checks
  void _startPeriodicChecks() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(_checkInterval, (_) {
      checkForUpdates(showErrors: false);
    });
  }

  /// Check for updates from GitHub releases
  Future<bool> checkForUpdates({bool showErrors = true}) async {
    // Rate limiting
    if (_lastCheckTime != null) {
      final timeSinceLastCheck = DateTime.now().difference(_lastCheckTime!);
      if (timeSinceLastCheck < _minCheckInterval) {
        return _availableUpdate != null;
      }
    }

    if (_isChecking) return false;

    _isChecking = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest',
            ),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 10));

      _lastCheckTime = DateTime.now();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final latestVersion = _parseVersion(data['tag_name'] as String? ?? '');

        if (_isNewerVersion(latestVersion, _currentVersion)) {
          // Find the Windows installer asset
          final assets = data['assets'] as List<dynamic>? ?? [];
          String? downloadUrl;

          for (final asset in assets) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            // Look for Windows installer (exe or msix)
            if (name.endsWith('.exe') || name.endsWith('.msix')) {
              downloadUrl = asset['browser_download_url'] as String?;
              break;
            }
          }

          if (downloadUrl != null) {
            _availableUpdate = UpdateInfo(
              version: latestVersion,
              downloadUrl: downloadUrl,
              changelog: data['body'] as String?,
              htmlUrl: data['html_url'] as String?,
              publishedAt: data['published_at'] != null
                  ? DateTime.tryParse(data['published_at'] as String)
                  : null,
            );
            _updateDismissed = false;
            notifyListeners();
            return true;
          }
        } else {
          _availableUpdate = null;
        }
      } else if (response.statusCode == 404) {
        // No releases yet
        _availableUpdate = null;
      } else {
        throw Exception('GitHub API returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
      if (showErrors) {
        _error = 'Failed to check for updates: $e';
      }
    } finally {
      _isChecking = false;
      notifyListeners();
    }

    return _availableUpdate != null;
  }

  /// Parse version string, removing 'v' prefix if present
  String _parseVersion(String version) {
    return version.startsWith('v') ? version.substring(1) : version;
  }

  /// Compare versions (returns true if remote is newer than current)
  bool _isNewerVersion(String remote, String current) {
    try {
      final remoteParts = remote
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      final currentParts = current
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();

      // Pad to same length
      while (remoteParts.length < 3) remoteParts.add(0);
      while (currentParts.length < 3) currentParts.add(0);

      for (int i = 0; i < remoteParts.length; i++) {
        if (remoteParts[i] > currentParts[i]) return true;
        if (remoteParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      debugPrint('Version comparison error: $e');
      return false;
    }
  }

  /// Download and install the update
  Future<void> downloadAndInstall() async {
    if (_availableUpdate == null || _isDownloading) return;

    _isDownloading = true;
    _downloadProgress = null;
    _error = null;
    notifyListeners();

    try {
      final url = _availableUpdate!.downloadUrl;
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.last;

      // Get temp directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}${Platform.pathSeparator}$fileName';
      final file = File(filePath);

      // Download with progress
      final request = http.Request('GET', uri);
      final streamedResponse = await http.Client().send(request);

      final totalBytes = streamedResponse.contentLength ?? 0;
      int receivedBytes = 0;
      final List<int> bytes = [];

      await for (final chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
        receivedBytes += chunk.length;
        _downloadProgress = DownloadProgress(
          downloaded: receivedBytes,
          total: totalBytes,
        );
        notifyListeners();
      }

      // Write file
      await file.writeAsBytes(bytes);

      _isDownloading = false;
      notifyListeners();

      // Launch the installer
      if (Platform.isWindows) {
        await Process.start(filePath, [], mode: ProcessStartMode.detached);
        // Exit the current app to allow installation
        exit(0);
      }
    } catch (e) {
      debugPrint('Download failed: $e');
      _error = 'Download failed: $e';
      _isDownloading = false;
      notifyListeners();
    }
  }

  /// Open the release page in browser (alternative to direct download)
  Future<void> openReleasePage() async {
    if (_availableUpdate?.htmlUrl != null) {
      final uri = Uri.parse(_availableUpdate!.htmlUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Dismiss the update notification (until next check finds a newer version)
  void dismissUpdate() {
    _updateDismissed = true;
    notifyListeners();
  }

  /// Reset dismissed state and show update again
  void showUpdateAgain() {
    _updateDismissed = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _periodicCheckTimer?.cancel();
    super.dispose();
  }
}
