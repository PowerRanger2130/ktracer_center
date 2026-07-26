// ignore_for_file: avoid_print

import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/app_state.dart';
import 'package:ktracer_center/database/database.dart';
import 'package:ktracer_center/devices/lab_inventory.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:vector_math/vector_math_64.dart' hide Colors;

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.userOverrides});

  final Map<String, String>? userOverrides;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _userController = TextEditingController();

  List<AutoSuggestBoxItem<KtUser>> _userSuggestions = [];
  Timer? _debounce;
  String _lastQuery = '';
  Future<List<KtUser>>? _usersFuture;
  int? _lastProjectId;
  List<KtUser> _projectUsers = [];

  Future<List<KtUser>> _loadProjectUsers(int projectId) async {
    final users = await Database.getProjectUsers(projectId);
    _projectUsers = users;
    return users;
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _descriptionController.dispose();
    _userController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _lastQuery = text;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (text.isEmpty) {
        setState(() {
          _userSuggestions = [];
        });
        return;
      }

      final users = await Database.searchUsers(text);
      if (!mounted) return;
      if (text != _lastQuery) return;

      final state = context.read<AppState>();
      final currentUser = state.currentUser;

      final filteredUsers = users.where((u) {
        if (u.id == currentUser?.id) return false;
        if (_projectUsers.any((pUser) => pUser.id == u.id)) return false;
        return true;
      }).toList();

      setState(() {
        _userSuggestions = filteredUsers.map((user) {
          return AutoSuggestBoxItem<KtUser>(
            value: user,
            label: '${user.name} (${user.email})',
            child: Text('${user.name} (${user.email})'),
          );
        }).toList();
      });
    });
  }

  void _updateProjectName() {
    // Placeholder: Implement project name update logic
    print('Updating project name to: ${_projectNameController.text}');
  }

  void _createNewProject() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final TextEditingController newProjectController =
            TextEditingController();
        String? errorText;

        return StatefulBuilder(
          builder: (context, setState) {
            return ContentDialog(
              title: const Text('Create New Project'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextBox(
                    placeholder: 'New project name',
                    controller: newProjectController,
                    onChanged: (value) {
                      if (errorText != null) {
                        setState(() => errorText = null);
                      }
                    },
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        errorText!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              actions: [
                Button(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                FilledButton(
                  child: const Text('Create'),
                  onPressed: () async {
                    final text = newProjectController.text.trim();
                    if (text.isEmpty) {
                      setState(
                        () => errorText = 'Project name cannot be empty',
                      );
                      return;
                    }
                    if (text.length > 30) {
                      setState(
                        () => errorText = 'Project name is too long (max 30)',
                      );
                      return;
                    }

                    // Create project and add current user as owner
                    print('Creating new project named $text');
                    final project = await Database.createProject(text);

                    if (!context.mounted) return;
                    final state = context.read<AppState>();
                    state.setProjects([...state.projects, project]);
                    state.selectProject(project);

                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _deleteProject(AppState state) async {
    if (state.projects.length > 1) {
      await state.selectedProject?.delete();
      state.setProjects(state.projects..remove(state.selectedProject));
      state.selectProject(state.projects.first);
      print('Deleted project');
      return true;
    }
    print('Cannot delete the only project');
    return false;
  }

  Future<void> _addUserToTeam(KtUser user) async {
    final state = context.read<AppState>();
    if (state.selectedProject == null) return;

    print('Adding user: ${user.email}');
    await state.selectedProject!.addUser(user.id);

    _userController.clear();
    setState(() {
      _userSuggestions = [];
      if (_lastProjectId != null) {
        _usersFuture = _loadProjectUsers(_lastProjectId!);
      }
    });

    if (!mounted) return;
    displayInfoBar(
      context,
      builder: (context, close) {
        return InfoBar(
          title: const Text('User added'),
          content: Text('${user.name} added to project.'),
          severity: InfoBarSeverity.success,
        );
      },
    );
  }

  Future<void> _removeUserFromTeam(KtUser user) async {
    final state = context.read<AppState>();
    if (state.selectedProject == null) return;

    await state.selectedProject!.removeUser(user.id);

    setState(() {
      if (_lastProjectId != null) {
        _usersFuture = _loadProjectUsers(_lastProjectId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.selectedProject?.id != _lastProjectId) {
      _lastProjectId = state.selectedProject?.id;
      if (_lastProjectId != null) {
        _usersFuture = _loadProjectUsers(_lastProjectId!);
        _projectNameController.text = state.selectedProject!.name;
        _descriptionController.text = state.selectedProject!.description ?? '';
      } else {
        _usersFuture = null;
        _projectUsers = [];
        _projectNameController.clear();
        _descriptionController.clear();
      }
    }

    return FluentTheme(
      data: FluentTheme.of(context).copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        micaBackgroundColor: Colors.transparent,
      ),
      child: ScaffoldPage(
        header: PageHeader(
          title: const Text('Project Details'),
          commandBar: CommandBar(
            mainAxisAlignment: MainAxisAlignment.end,
            primaryItems: [
              CommandBarBuilderItem(
                builder: (context, mode, parent) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Tooltip(
                      message: 'New Project',
                      child: FilledButton(
                        onPressed: _createNewProject,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.add, size: 18),
                            SizedBox(width: 8),
                            Text('New Project'),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                wrappedItem: CommandBarButton(
                  icon: const Icon(FluentIcons.add),
                  label: const Text('New Project'),
                  onPressed: _createNewProject,
                ),
              ),
              CommandBarButton(
                icon: const Icon(FluentIcons.delete),
                label: const Text('Delete'),
                onPressed: () async {
                  final state = context.read<AppState>();
                  final projectName = state.selectedProject?.name ?? '';
                  final del = await _deleteProject(state);
                  if (!mounted) return;
                  if (del && context.mounted) {
                    await displayInfoBar(
                      context,
                      builder: (context, close) {
                        return InfoBar(
                          title: const Text('Delete successful'),
                          content: Text('Deleted the project $projectName.'),
                          action: IconButton(
                            icon: const WindowsIcon(WindowsIcons.clear),
                            onPressed: close,
                          ),
                          severity: InfoBarSeverity.success,
                        );
                      },
                    );
                  } else {
                    if (context.mounted) {
                      await displayInfoBar(
                        context,
                        builder: (context, close) {
                          return InfoBar(
                            title: const Text('Delete failed'),
                            content: const Text(
                              'You must have at least one project.',
                            ),
                            action: IconButton(
                              icon: const WindowsIcon(WindowsIcons.clear),
                              onPressed: close,
                            ),
                            severity: InfoBarSeverity.warning,
                          );
                        },
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Column 1: Project Settings
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Project Settings',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        InfoLabel(
                          label: 'Project Name',
                          child: TextBox(
                            controller: _projectNameController,
                            placeholder: 'Enter project name',
                          ),
                        ),
                        const SizedBox(height: 10),
                        InfoLabel(
                          label: 'Description',
                          child: TextBox(
                            controller: _descriptionController,
                            placeholder: 'Enter project description',
                            maxLines: 3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Button(
                          onPressed: _updateProjectName,
                          child: const Text('Save Details'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40), // Spacer between columns
                  // Column 2: Team
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Team',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        InfoLabel(
                          label: 'Add User',
                          child: AutoSuggestBox<KtUser>(
                            controller: _userController,
                            placeholder: 'Enter user email',
                            items: _userSuggestions,
                            onSelected: (item) {
                              if (item.value != null) {
                                _addUserToTeam(item.value!);
                              }
                            },
                            onChanged: (text, reason) {
                              if (reason == TextChangedReason.userInput) {
                                _onSearchChanged(text);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Current Users:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        if (widget.userOverrides != null)
                          Builder(
                            builder: (context) {
                              final overrideEntries = widget
                                  .userOverrides!
                                  .entries
                                  .toList();
                              if (overrideEntries.isEmpty) {
                                return const Text('No users in this project.');
                              }
                              return Column(
                                children: overrideEntries.map((entry) {
                                  return ListTile(
                                    title: Text(entry.key),
                                    subtitle: Text(entry.value),
                                  );
                                }).toList(),
                              );
                            },
                          )
                        else if (_usersFuture != null)
                          FutureBuilder<List<KtUser>>(
                            future: _usersFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const ProgressRing();
                              }
                              if (snapshot.hasError) {
                                return Text('Error: ${snapshot.error}');
                              }
                              final users = snapshot.data ?? [];
                              if (users.isEmpty) {
                                return const Text('No users in this project.');
                              }
                              return Column(
                                children: users.map((user) {
                                  return ListTile(
                                    title: Text(user.name),
                                    subtitle: Text(user.email),
                                    trailing: Row(
                                      children: [
                                        Button(
                                          onPressed: null,
                                          child: const Text(
                                            'Manage Role',
                                          ), // Not implemented
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(FluentIcons.delete),
                                          onPressed: () =>
                                              _removeUserFromTeam(user),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              // Devices Section
              Row(
                children: [
                  const Text(
                    'Devices',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (state.devices.isNotEmpty)
                    FilledButton(
                      onPressed: () async {
                        int acquired = 0;
                        int failed = 0;
                        for (final device in state.devices) {
                          final lockService = state.lockService;
                          final hasLock =
                              lockService?.hasLock(device.id) ?? false;
                          if (hasLock) continue; // Already locked

                          final success = await state.requestDeviceLock(
                            device.id,
                          );
                          if (success) {
                            acquired++;
                          } else {
                            failed++;
                          }
                        }
                        if (!mounted) return;
                        if (context.mounted) {
                          displayInfoBar(
                            context,
                            builder: (context, close) => InfoBar(
                              title: Text(
                                failed == 0
                                    ? 'All Locks Acquired'
                                    : 'Locks Acquired',
                              ),
                              content: Text(
                                acquired > 0
                                    ? 'Locked $acquired device(s)${failed > 0 ? ', $failed failed' : ''}'
                                    : 'No new locks acquired${failed > 0 ? ' ($failed unavailable)' : ''}',
                              ),
                              severity: failed == 0
                                  ? InfoBarSeverity.success
                                  : InfoBarSeverity.warning,
                            ),
                          );
                        }
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.lock, size: 14),
                          SizedBox(width: 6),
                          Text('Lock All'),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${state.devices.length} device(s) in project',
                style: TextStyle(color: Colors.grey[100]),
              ),
              const SizedBox(height: 8),
              Text(
                'Use the + button in the Devices pane to add devices',
                style: TextStyle(color: Colors.grey[120], fontSize: 12),
              ),
              const SizedBox(height: 16),
              if (state.devices.isNotEmpty)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: state.devices.map((device) {
                    // Get lock status for this device
                    final lockService = state.lockService;
                    final hasLock = lockService?.hasLock(device.id) ?? false;
                    final isLockedInProject =
                        lockService?.isLocked(device.id) ?? false;
                    final lockHolder = lockService?.getLock(device.id);

                    // Get device configuration status
                    final isConfiguring =
                        lockService?.isDeviceConfiguring(device.id) ?? false;
                    final deviceStatus = lockService?.getDeviceStatus(
                      device.id,
                    );
                    final statusMessage = lockService?.getDeviceStatusMessage(
                      device.id,
                    );

                    // Get the assigned real_id from the lock (if we have one)
                    final assignedRealId = lockHolder?.realId;

                    // Check global availability for this preset
                    final labRealIds = LabInventory.getByPresetId(
                      device.presetId,
                    ).map((d) => d.realId).toList();
                    final availableCount =
                        lockService?.getAvailableCountForPreset(
                          device.presetId,
                          labRealIds,
                        ) ??
                        labRealIds.length;

                    return _HoverCard(
                      onTap: () => state.navigateToDevice(device.id),
                      child: Card(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 220,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: device.color,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      device.hostname,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Lock/Status indicator
                                  if (isConfiguring)
                                    Tooltip(
                                      message:
                                          statusMessage ?? 'Configuring...',
                                      child: const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: ProgressRing(),
                                      ),
                                    )
                                  else if (hasLock)
                                    Tooltip(
                                      message: deviceStatus == 'ready'
                                          ? 'Device ready'
                                          : deviceStatus == 'error'
                                          ? statusMessage ?? 'Error'
                                          : 'You have control',
                                      child: Icon(
                                        deviceStatus == 'error'
                                            ? FluentIcons.warning
                                            : FluentIcons.lock,
                                        size: 14,
                                        color: deviceStatus == 'error'
                                            ? Colors.orange
                                            : Colors.green,
                                      ),
                                    )
                                  else if (isLockedInProject)
                                    Tooltip(
                                      message: 'Locked by another user',
                                      child: Icon(
                                        FluentIcons.lock,
                                        size: 14,
                                        color: Colors.red,
                                      ),
                                    )
                                  else if (availableCount == 0)
                                    Tooltip(
                                      message:
                                          'All ${device.name} devices are busy (locked by other projects)',
                                      child: Icon(
                                        FluentIcons.blocked,
                                        size: 14,
                                        color: Colors.orange,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                device.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[100],
                                ),
                              ),
                              // Show physical device assignment or availability
                              if (hasLock && assignedRealId != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (isConfiguring) ...[
                                      const SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: ProgressRing(strokeWidth: 1.5),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Expanded(
                                      child: Text(
                                        isConfiguring
                                            ? statusMessage ?? 'Configuring...'
                                            : 'Physical: #$assignedRealId (${availableCount}/${labRealIds.length} free)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isConfiguring
                                              ? Colors.blue
                                              : Colors.green,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                const SizedBox(height: 4),
                                Text(
                                  labRealIds.isEmpty
                                      ? 'No devices of this type'
                                      : availableCount > 0
                                      ? 'Free: $availableCount/${labRealIds.length}'
                                      : 'All ${labRealIds.length} locked',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: labRealIds.isEmpty
                                        ? Colors.red
                                        : availableCount > 0
                                        ? Colors.grey[120]
                                        : Colors.orange,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              // Lock/Unlock button
                              if (hasLock)
                                Button(
                                  onPressed: isConfiguring
                                      ? null
                                      : () async {
                                          final released = await state
                                              .releaseDeviceLock(device.id);
                                          if (!mounted) return;
                                          if (released) {
                                            if (context.mounted) {
                                              displayInfoBar(
                                                context,
                                                builder: (context, close) =>
                                                    InfoBar(
                                                      title: const Text(
                                                        'Lock Released',
                                                      ),
                                                      content: Text(
                                                        'Released control of ${device.hostname}',
                                                      ),
                                                      severity:
                                                          InfoBarSeverity.info,
                                                    ),
                                              );
                                            }
                                          }
                                        },
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(FluentIcons.unlock, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'Release',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isLockedInProject)
                                Tooltip(
                                  message:
                                      'Device is locked by ${lockHolder?.userId ?? 'another user'}',
                                  child: Button(
                                    onPressed: null,
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(FluentIcons.lock, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'Locked',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ],
                                    ), // Disabled
                                  ),
                                )
                              else if (labRealIds.isEmpty)
                                Tooltip(
                                  message:
                                      'No physical ${device.name} devices exist in the lab',
                                  child: Button(
                                    onPressed: null,
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(FluentIcons.warning, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'No Devices',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ],
                                    ), // Disabled
                                  ),
                                )
                              else if (availableCount == 0)
                                Tooltip(
                                  message:
                                      'All physical ${device.name} devices are currently locked by other projects',
                                  child: Button(
                                    onPressed: null,
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(FluentIcons.blocked, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'Unavailable',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ],
                                    ), // Disabled
                                  ),
                                )
                              else
                                Button(
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(FluentIcons.lock, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'Request Lock',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  onPressed: () async {
                                    final acquired = await state
                                        .requestDeviceLock(device.id);
                                    if (!mounted) return;
                                    if (acquired) {
                                      if (context.mounted) {
                                        displayInfoBar(
                                          context,
                                          builder: (context, close) => InfoBar(
                                            title: const Text('Lock Acquired'),
                                            content: Text(
                                              'You now have control of ${device.hostname}',
                                            ),
                                            severity: InfoBarSeverity.success,
                                          ),
                                        );
                                      }
                                    } else {
                                      if (context.mounted) {
                                        displayInfoBar(
                                          context,
                                          builder: (context, close) => InfoBar(
                                            title: const Text('Lock Failed'),
                                            content: Text(
                                              'Could not acquire lock for ${device.hostname}. No physical device available or Python service not running.',
                                            ),
                                            severity: InfoBarSeverity.warning,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A card widget with hover animation effect
class _HoverCard extends StatefulWidget {
  const _HoverCard({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.identity()
            ..translateByVector3(Vector3(0.0, _isHovered ? -4.0 : 0.0, 0)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? .2 : 0),
                blurRadius: _isHovered ? 12 : 0,
                offset: Offset(0, _isHovered ? 6 : 0),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
