import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/theme.dart';

class MonoArea extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String xKey;
  final String yKey;
  final double height;

  const MonoArea({
    super.key,
    required this.data,
    required this.xKey,
    required this.yKey,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    
    // Find min/max values
    double maxY = 0;
    final List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      final val = (data[i][yKey] as num).toDouble();
      if (val > maxY) maxY = val;
      spots.add(FlSpot(i.toDouble(), val));
    }
    maxY = maxY > 0 ? maxY * 1.15 : 10;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: appColors.border,
              strokeWidth: 1,
              dashArray: [2, 4],
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (data.length / 5).ceil().toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < data.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        data[index][xKey].toString(),
                        style: TextStyle(color: appColors.mutedForeground, fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max) return const SizedBox.shrink();
                  return Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(color: appColors.mutedForeground, fontSize: 9),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: appColors.borderStrong, width: 1),
            ),
          ),
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: appColors.foreground,
              barWidth: 1.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    appColors.foreground.withValues(alpha: 0.3),
                    appColors.foreground.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => appColors.surface1,
              tooltipBorder: BorderSide(color: appColors.borderStrong),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((s) {
                  return LineTooltipItem(
                    '${data[s.spotIndex][xKey]}: \$${s.y.toStringAsFixed(2)}',
                    TextStyle(color: appColors.foreground, fontSize: 11, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class MonoLine extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String xKey;
  final List<Map<String, dynamic>> lines; // e.g. [{'key': 'rev', 'label': 'Revenue'}]
  final double height;

  const MonoLine({
    super.key,
    required this.data,
    required this.xKey,
    required this.lines,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    
    // Find limits
    double maxY = 0;
    final List<List<FlSpot>> linesSpots = List.generate(lines.length, (_) => []);

    for (int i = 0; i < data.length; i++) {
      for (int l = 0; l < lines.length; l++) {
        final key = lines[l]['key'] as String;
        final val = (data[i][key] as num).toDouble();
        if (val > maxY) maxY = val;
        linesSpots[l].add(FlSpot(i.toDouble(), val));
      }
    }
    maxY = maxY > 0 ? maxY * 1.15 : 10;

    final lineShades = [
      appColors.foreground,
      appColors.mutedForeground,
      appColors.borderStrong,
      appColors.foreground.withValues(alpha: 0.5),
    ];

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: appColors.border,
              strokeWidth: 0.5,
              dashArray: [2, 4],
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (data.length / 5).ceil().toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < data.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        data[index][xKey].toString(),
                        style: TextStyle(color: appColors.mutedForeground, fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max) return const SizedBox.shrink();
                  return Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(color: appColors.mutedForeground, fontSize: 9),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(bottom: BorderSide(color: appColors.borderStrong, width: 1)),
          ),
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          lineBarsData: List.generate(lines.length, (l) {
            return LineChartBarData(
              spots: linesSpots[l],
              isCurved: true,
              color: lineShades[l % lineShades.length],
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
            );
          }),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => appColors.surface1,
              tooltipBorder: BorderSide(color: appColors.borderStrong),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((s) {
                  final label = lines[s.barIndex]['label'] ?? lines[s.barIndex]['key'];
                  return LineTooltipItem(
                    '$label: \$${s.y.toStringAsFixed(2)}',
                    TextStyle(color: lineShades[s.barIndex % lineShades.length], fontSize: 11, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class MonoBar extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String xKey;
  final String yKey;
  final double height;

  const MonoBar({
    super.key,
    required this.data,
    required this.xKey,
    required this.yKey,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    
    // Find limit
    double maxY = 0;
    final List<BarChartGroupData> barGroups = [];

    for (int i = 0; i < data.length; i++) {
      final val = (data[i][yKey] as num).toDouble();
      if (val > maxY) maxY = val;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: appColors.foreground,
              width: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                topRight: Radius.circular(3),
              ),
            ),
          ],
        ),
      );
    }
    maxY = maxY > 0 ? maxY * 1.15 : 10;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: appColors.border,
              strokeWidth: 0.5,
              dashArray: [2, 4],
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < data.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        data[index][xKey].toString(),
                        style: TextStyle(color: appColors.mutedForeground, fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max) return const SizedBox.shrink();
                  return Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(color: appColors.mutedForeground, fontSize: 9),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(bottom: BorderSide(color: appColors.borderStrong, width: 1)),
          ),
          maxY: maxY,
          barGroups: barGroups,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => appColors.surface1,
              tooltipBorder: BorderSide(color: appColors.borderStrong),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${data[groupIndex][xKey]}: ${rod.toY.toStringAsFixed(0)}',
                  TextStyle(color: appColors.foreground, fontSize: 11, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class MonoPie extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final double height;

  const MonoPie({
    super.key,
    required this.data,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    
    final shades = [
      appColors.foreground,
      appColors.mutedForeground,
      appColors.borderStrong,
      appColors.foreground.withValues(alpha: 0.5),
      appColors.foreground.withValues(alpha: 0.3),
    ];

    return SizedBox(
      height: height,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 50,
          sections: List.generate(data.length, (i) {
            final val = (data[i]['value'] as num).toDouble();
            final name = data[i]['name'].toString();
            return PieChartSectionData(
              color: shades[i % shades.length],
              value: val,
              title: '',
              radius: 30,
              badgeWidget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: appColors.background,
                  border: Border.all(color: appColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  name,
                  style: TextStyle(color: appColors.foreground, fontSize: 9),
                ),
              ),
              badgePositionPercentageOffset: 1.25,
            );
          }),
          pieTouchData: PieTouchData(
            touchCallback: (event, response) {},
          ),
        ),
      ),
    );
  }
}
