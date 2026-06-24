import 'package:flutter/material.dart';
import '../models/place.dart';
import '../models/route_plan.dart';
import '../models/functional_point.dart';
import '../models/risk_point.dart';
import '../services/tts_service.dart';
import '../widgets/large_button.dart';
import 'navigation_screen.dart';
import 'debug_map_screen.dart';

enum _RouteTab { overview, keyPoints, riskPoints }

class RouteDetailScreen extends StatefulWidget {
  final RoutePlan route;
  final Place origin;
  final Place destination;

  const RouteDetailScreen({
    super.key,
    required this.route,
    required this.origin,
    required this.destination,
  });

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  final _ttsService = TtsService.instance;
  _RouteTab _tab = _RouteTab.overview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ttsService.speak(widget.route.overviewTts);
    });
  }

  void _startNavigation() {
    _ttsService.stop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NavigationScreen(route: widget.route)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Route · ${widget.route.modeLabel}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'View on map',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DebugMapScreen(
                  origin: widget.origin,
                  destination: widget.destination,
                  routes: [widget.route],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: 'Read route overview',
            onPressed: () => _ttsService.speak(widget.route.overviewTts),
          ),
        ],
      ),
      body: Column(
        children: [
          _AccessibilityScoreBar(
            route: widget.route,
            onReadAloud: (text) => _ttsService.speak(text),
          ),
          _RouteTabBar(
            selectedTab: _tab,
            route: widget.route,
            onTabChanged: (tab) {
              setState(() => _tab = tab);
              _ttsService.speakInterrupt(_tabLabel(tab));
            },
          ),
          Expanded(
            child: _RouteTabContent(
              selectedTab: _tab,
              route: widget.route,
              onReadAloud: (text) => _ttsService.speak(text),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: LargeButton(
              label: 'Start Navigation',
              icon: Icons.navigation,
              onPressed: _startNavigation,
              semanticLabel:
                  'Start navigation. '
                  'You can step through each instruction.',
            ),
          ),
        ],
      ),
    );
  }

  String _tabLabel(_RouteTab tab) => switch (tab) {
    _RouteTab.overview => 'Overview',
    _RouteTab.keyPoints =>
      'Key Points (${widget.route.functionalPoints.length})',
    _RouteTab.riskPoints => 'Risk Points (${widget.route.riskPoints.length})',
  };
}

class _AccessibilityScoreBar extends StatelessWidget {
  final RoutePlan route;
  final void Function(String) onReadAloud;

  const _AccessibilityScoreBar({
    required this.route,
    required this.onReadAloud,
  });

  @override
  Widget build(BuildContext context) {
    final summary = route.accessibilitySummary;
    final color = summary.score >= 80
        ? Colors.green[700]!
        : summary.score >= 60
        ? Colors.orange[700]!
        : Colors.red[700]!;
    return Semantics(
      label: 'Accessibility score ${summary.score}. ${summary.ttsDescription}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: color.withValues(alpha: 0.1),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  '${summary.score}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accessibility Score',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${summary.streetCrossings} crossing${summary.streetCrossings == 1 ? '' : 's'}'
                    '  ·  '
                    '${(summary.walkingDistanceMeters / 1000).toStringAsFixed(1)} km walk'
                    '  ·  '
                    '${summary.transferCount} transfer${summary.transferCount == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (summary.audibleSignals > 0)
                    Text(
                      '${summary.audibleSignals} audible signal${summary.audibleSignals == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 13, color: Colors.green[700]),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.volume_up),
              tooltip: 'Read accessibility details',
              onPressed: () => onReadAloud(summary.ttsDescription),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteTabBar extends StatelessWidget {
  final _RouteTab selectedTab;
  final RoutePlan route;
  final void Function(_RouteTab) onTabChanged;

  const _RouteTabBar({
    required this.selectedTab,
    required this.route,
    required this.onTabChanged,
  });

  String _labelFor(_RouteTab tab) => switch (tab) {
    _RouteTab.overview => 'Overview',
    _RouteTab.keyPoints => 'Key Points (${route.functionalPoints.length})',
    _RouteTab.riskPoints => 'Risk Points (${route.riskPoints.length})',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
      child: Row(
        children: _RouteTab.values.map((tab) {
          final selected = selectedTab == tab;
          final label = _labelFor(tab);
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(tab),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected
                          ? colorScheme.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RouteTabContent extends StatelessWidget {
  final _RouteTab selectedTab;
  final RoutePlan route;
  final void Function(String) onReadAloud;

  const _RouteTabContent({
    required this.selectedTab,
    required this.route,
    required this.onReadAloud,
  });

  @override
  Widget build(BuildContext context) => switch (selectedTab) {
    _RouteTab.overview => _OverviewTab(route: route),
    _RouteTab.keyPoints => _FunctionalPointsTab(
      functionalPoints: route.functionalPoints,
      onReadAloud: onReadAloud,
    ),
    _RouteTab.riskPoints => _RiskPointsTab(
      riskPoints: route.riskPoints,
      onReadAloud: onReadAloud,
    ),
  };
}

class _OverviewTab extends StatelessWidget {
  final RoutePlan route;

  const _OverviewTab({required this.route});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (int i = 0; i < route.legs.length; i++)
          _LegCard(leg: route.legs[i], index: i + 1),
      ],
    );
  }
}

class _FunctionalPointsTab extends StatelessWidget {
  final List<FunctionalPoint> functionalPoints;
  final void Function(String) onReadAloud;

  const _FunctionalPointsTab({
    required this.functionalPoints,
    required this.onReadAloud,
  });

  @override
  Widget build(BuildContext context) {
    if (functionalPoints.isEmpty) {
      return const Center(
        child: Text('No key points', style: TextStyle(fontSize: 16)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: functionalPoints.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _FunctionalPointCard(
        functionalPoint: functionalPoints[index],
        onTts: () => onReadAloud(functionalPoints[index].description),
      ),
    );
  }
}

class _RiskPointsTab extends StatelessWidget {
  final List<RiskPoint> riskPoints;
  final void Function(String) onReadAloud;

  const _RiskPointsTab({required this.riskPoints, required this.onReadAloud});

  @override
  Widget build(BuildContext context) {
    if (riskPoints.isEmpty) {
      return const Center(
        child: Text('No risk points', style: TextStyle(fontSize: 16)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: riskPoints.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _RiskPointCard(
        riskPoint: riskPoints[index],
        onTts: () => onReadAloud(
          'Caution, ${riskPoints[index].severityLabel}: '
          '${riskPoints[index].description}',
        ),
      ),
    );
  }
}

class _LegCard extends StatelessWidget {
  final JourneyLeg leg;
  final int index;

  const _LegCard({required this.leg, required this.index});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final modeIcon = leg.mode == 'bus'
        ? Icons.directions_bus
        : leg.mode == 'walk'
        ? Icons.directions_walk
        : Icons.local_taxi;
    final modeColor = leg.mode == 'bus'
        ? colorScheme.primary
        : leg.mode == 'walk'
        ? Colors.green[700]!
        : Colors.orange[700]!;

    final durationMinutes = (leg.durationSeconds / 60).round();
    final distance = leg.distanceMeters < 1000
        ? '${leg.distanceMeters.round()} m'
        : '${(leg.distanceMeters / 1000).toStringAsFixed(1)} km';
    final scheduled = leg.transitInfo?['scheduled'] as bool?;
    final scheduleLabel = switch (scheduled) {
      true => ' (scheduled)',
      false => ' (real-time)',
      null => '',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(modeIcon, color: modeColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Leg $index: ${leg.modeLabel}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '$durationMinutes min · $distance',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${leg.fromName}  →  ${leg.toName}',
              style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
            ),
            if (leg.transitInfo != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Route ${leg.transitInfo!['route']}  '
                  '${leg.transitInfo!['headsign']}$scheduleLabel',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
            if (leg.steps.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...leg.steps.map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 15)),
                      Expanded(
                        child: Text(
                          step.instruction,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FunctionalPointCard extends StatelessWidget {
  final FunctionalPoint functionalPoint;
  final VoidCallback onTts;

  const _FunctionalPointCard({
    required this.functionalPoint,
    required this.onTts,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRequired =
        functionalPoint.importance == FunctionalPointImportance.required;
    final color = isRequired ? colorScheme.primary : colorScheme.secondary;
    final typeIcon = functionalPoint.type.startsWith('bus')
        ? Icons.directions_bus
        : functionalPoint.type == 'building_entrance'
        ? Icons.door_front_door
        : Icons.place;

    return Semantics(
      label:
          '${functionalPoint.importanceLabel} point: '
          '${functionalPoint.description}',
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: color,
            child: Icon(
              typeIcon,
              color: isRequired
                  ? colorScheme.onPrimary
                  : colorScheme.onSecondary,
            ),
          ),
          title: Text(
            functionalPoint.description,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            '${functionalPoint.importanceLabel} · '
            'Trigger at ${functionalPoint.triggerDistanceMeters.round()} m',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: onTts,
          ),
        ),
      ),
    );
  }
}

class _RiskPointCard extends StatelessWidget {
  final RiskPoint riskPoint;
  final VoidCallback onTts;

  const _RiskPointCard({required this.riskPoint, required this.onTts});

  @override
  Widget build(BuildContext context) {
    final color = riskPoint.severity == RiskSeverity.high
        ? Colors.red[700]!
        : riskPoint.severity == RiskSeverity.medium
        ? Colors.orange[700]!
        : Colors.yellow[700]!;

    return Semantics(
      label: '${riskPoint.severityLabel}: ${riskPoint.description}',
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: color,
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white),
          ),
          title: Text(
            riskPoint.description,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            '${riskPoint.severityLabel} · '
            'Trigger at ${riskPoint.triggerDistanceMeters.round()} m',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: onTts,
          ),
        ),
      ),
    );
  }
}
