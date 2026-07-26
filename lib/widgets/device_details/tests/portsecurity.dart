import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/widgets/device_details/tests/current_device_card.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

enum PortSecurityAction {
  shutdown('Shutdown', Color(0xffd13438)),
  restrict('Restrict', Color(0xffc19c00)),
  protect('Protect', Color(0xff107c10));

  const PortSecurityAction(this.label, this.color);

  final String label;
  final Color color;
}

class SwitchPortSecurityEntry {
  const SwitchPortSecurityEntry({
    required this.port,
    required this.maxSecureAddr,
    required this.currentAddr,
    required this.securityViolation,
    this.action = PortSecurityAction.shutdown,
  });

  final String port;
  final int maxSecureAddr;
  final int currentAddr;
  final int securityViolation;
  final PortSecurityAction action;

  int get totalAddressesExcludingOnePerPort =>
      currentAddr > 0 ? currentAddr - 1 : 0;
}

enum PortSecurityFilter {
  all('All ports'),
  active('Learned MACs'),
  empty('No MACs');

  const PortSecurityFilter(this.label);
  final String label;
}

const _systemAddressLimit = 8190;

const _portSecurityRows = <SwitchPortSecurityEntry>[
  SwitchPortSecurityEntry(
    port: 'Gi1/0/2',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/3',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/4',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/5',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/6',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/7',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/8',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/9',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/10',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/13',
    maxSecureAddr: 5,
    currentAddr: 4,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/14',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/15',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/16',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/17',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/18',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/19',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/20',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/21',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/22',
    maxSecureAddr: 5,
    currentAddr: 0,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/23',
    maxSecureAddr: 5,
    currentAddr: 1,
    securityViolation: 0,
  ),
  SwitchPortSecurityEntry(
    port: 'Gi1/0/24',
    maxSecureAddr: 5,
    currentAddr: 2,
    securityViolation: 0,
  ),
];

class SwitchPortSecurityTest extends StatefulWidget {
  const SwitchPortSecurityTest({required this.device, super.key});
  final NetDevice device;

  @override
  State<SwitchPortSecurityTest> createState() => _SwitchPortSecurityTestState();
}

class _SwitchPortSecurityTestState extends State<SwitchPortSecurityTest> {
  PortSecurityFilter _filter = PortSecurityFilter.all;

  List<SwitchPortSecurityEntry> get _filteredRows {
    return switch (_filter) {
      PortSecurityFilter.all => _portSecurityRows,
      PortSecurityFilter.active =>
        _portSecurityRows.where((entry) => entry.currentAddr > 0).toList(),
      PortSecurityFilter.empty =>
        _portSecurityRows.where((entry) => entry.currentAddr == 0).toList(),
    };
  }

  int get _totalLearnedMacs =>
      _portSecurityRows.fold(0, (sum, entry) => sum + entry.currentAddr);

  int get _totalAddressesInSystem => _portSecurityRows.fold(
    0,
    (sum, entry) => sum + entry.totalAddressesExcludingOnePerPort,
  );

  int get _securePortsInUse =>
      _portSecurityRows.where((entry) => entry.currentAddr > 0).length;

  Widget _filterChip(PortSecurityFilter filter) {
    final active = _filter == filter;
    return GestureDetector(
      onTap: () => setState(() => _filter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xff0078d4).withValues(alpha: .85)
              : const Color(0xff0078d4).withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? const Color(0xff0078d4)
                : const Color(0xff0078d4).withValues(alpha: .4),
            width: 1.3,
          ),
        ),
        child: Text(
          filter.label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xff0078d4),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(String title, String value, {Color? accent}) {
    return Card(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[100])),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableCell(
    String value,
    int flex, {
    bool mono = false,
    TextAlign align = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        textAlign: align,
        style: TextStyle(fontFamily: mono ? 'monospace' : null, fontSize: 12),
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: FluentTheme.of(context).cardColor,
      ),
      child: Row(
        children: [
          _tableCell('Secure Port', 15, mono: true),
          _tableCell('MaxSecureAddr', 14, align: TextAlign.center),
          _tableCell('CurrentAddr', 12, align: TextAlign.center),
          _tableCell('SecurityViolation', 14, align: TextAlign.center),
          _tableCell('Security Action', 13, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _tableRow(SwitchPortSecurityEntry entry) {
    final hasCurrent = entry.currentAddr > 0;
    final hasViolation = entry.securityViolation > 0;
    final tint = hasViolation
        ? const Color(0xffd13438).withValues(alpha: .12)
        : hasCurrent
        ? const Color(0xff107c10).withValues(alpha: .12)
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          _tableCell(entry.port, 15, mono: true),
          _tableCell('${entry.maxSecureAddr}', 14, align: TextAlign.center),
          _tableCell(
            '${entry.currentAddr}',
            12,
            align: TextAlign.center,
            mono: true,
          ),
          _tableCell(
            '${entry.securityViolation}',
            14,
            align: TextAlign.center,
            mono: true,
          ),
          Expanded(
            flex: 13,
            child: Align(
              alignment: Alignment.centerRight,
              child: FluentWidgets.chip(
                child: Text(
                  entry.action.label,
                  style: const TextStyle(fontSize: 11),
                ),
                color: entry.action.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 860),
      title: TestDialogHeaderRow(
        title: 'Switch Port Security',
        device: widget.device,
      ),
      content: SizedBox(
        width: 820,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PortSecurityFilter.values.map(_filterChip).toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    'Secure ports in use',
                    '$_securePortsInUse',
                    accent: const Color(0xff107c10),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryCard(
                    'Total learned MACs',
                    '$_totalLearnedMacs',
                    accent: const Color(0xff0078d4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryCard(
                    'Address limit in system',
                    '$_systemAddressLimit',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _tableHeader(),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 820),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _filteredRows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (_, index) => _tableRow(_filteredRows[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
