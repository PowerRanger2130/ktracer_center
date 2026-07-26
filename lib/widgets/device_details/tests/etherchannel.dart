import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/widgets/device_details/tests/current_device_card.dart';

class LegendItem {
  const LegendItem(this.icon, this.text, {this.used = false});
  final String icon;
  final String text;
  final bool used;
}

class EtherchannelTest extends StatefulWidget {
  const EtherchannelTest({required this.device, super.key});
  final NetDevice device;

  @override
  State<EtherchannelTest> createState() => _EtherchannelTestState();
}

class _EtherchannelTestState extends State<EtherchannelTest> {
  // Custom grid widget for displaying Etherchannel data
  Widget _etherchannelGrid() {
    final columns = ['Group', 'Port-channel', 'Protocol', 'Ports'];
    final rows = [
      ['1', 'Po1(SU)', 'PAgP', 'Gi1/0/11(P), Gi1/0/12(P)'],
    ];

    // Track hovered row
    final hoveredRow = ValueNotifier<int?>(null);
    Color cardBg(BuildContext context) => FluentTheme.of(context).cardColor;
    Color evenRowBg(BuildContext context) =>
        const Color(0xFF373737).withOpacity(0.8);
    Color oddRowBg(BuildContext context) {
      // Blend with black for dark theme
      return const Color(0xFF373737).withOpacity(0.8);
    }

    Color hoverBg(BuildContext context) =>
        const Color(0xFF373737).withOpacity(0.1);

    Color getRowColor(BuildContext context, int index, bool isHovered) {
      if (isHovered) {
        return hoverBg(context);
      }
      return index % 2 == 0 ? evenRowBg(context) : oddRowBg(context);
    }

    return ValueListenableBuilder<int?>(
      valueListenable: hoveredRow,
      builder: (context, hoverIdx, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header row
            Container(
              decoration: BoxDecoration(
                color: cardBg(context),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Row(
                children: List.generate(
                  columns.length,
                  (i) => Expanded(
                    flex: [8, 12, 8, 20][i],
                    child: Text(
                      columns[i],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Data rows
            ...List.generate(rows.length, (rowIdx) {
              final isHovered = hoverIdx == rowIdx;
              return MouseRegion(
                onEnter: (_) => hoveredRow.value = rowIdx,
                onExit: (_) => hoveredRow.value = null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    color: getRowColor(context, rowIdx, isHovered),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  child: Row(
                    children: List.generate(
                      rows[rowIdx].length,
                      (colIdx) => Expanded(
                        flex: [8, 12, 8, 20][colIdx],
                        child: Text(
                          rows[rowIdx][colIdx],
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const double cardW = 200;

    Widget _buildLegend(LegendItem item1, LegendItem item2) {
      Widget buildCard(LegendItem item) {
        final textColor = item.used
            ? Colors.white
            : const Color(0xFF9E9E9E).withOpacity(0.7);
        final content = SizedBox(
          width: cardW,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item.icon, style: TextStyle(color: textColor)),
              const SizedBox(width: 8),
              Text(
                item.text,
                textAlign: TextAlign.right,
                style: TextStyle(color: textColor),
              ),
            ],
          ),
        );
        if (item.used) return Card(child: content);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: content,
        );
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            buildCard(item1),
            const SizedBox(width: 12),
            buildCard(item2),
          ],
        ),
      );
    }

    return ContentDialog(
      constraints: BoxConstraints(maxWidth: cardW * 2 + 104),
      title: TestDialogHeaderRow(
        title: 'Etherchannel Test',
        device: widget.device,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flags legend
          _buildLegend(
            LegendItem("D", "down"),
            LegendItem("P", "bundled in port-channel", used: true),
          ),
          _buildLegend(
            LegendItem("I", "stand-alone"),
            LegendItem("s", "suspended"),
          ),
          _buildLegend(
            LegendItem("H", "Hot-standby (LACP only)"),
            LegendItem("R", "Layer3"),
          ),
          _buildLegend(
            LegendItem("S", "Layer2", used: true),
            LegendItem("U", "in use", used: true),
          ),
          _buildLegend(
            LegendItem("f", "failed to allocate\naggregator"),
            LegendItem("M", "not in use, minimum\nlinks not met"),
          ),
          Card(
            child: SizedBox(
              width: cardW * 2 + 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text("Number of channel-groups in use:"), Text("1")],
              ),
            ),
          ),
          SizedBox(height: 12),
          Card(
            child: SizedBox(
              width: cardW * 2 + 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text("Number of aggregators:"), Text("1")],
              ),
            ),
          ),
          SizedBox(height: 12),
          _etherchannelGrid(),
        ],
      ),
    );
  }
}
