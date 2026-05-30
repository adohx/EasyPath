import 'package:flutter/material.dart';
import '../models/place.dart';
import '../models/route_plan.dart';
import '../models/functional_point.dart';
import '../models/risk_point.dart';
import '../services/tts_service.dart';
import '../widgets/large_button.dart';
import 'navigation_screen.dart';

class RouteDetailScreen extends StatefulWidget {
  final RoutePlan route;
  final Place destination;

  const RouteDetailScreen({
    super.key,
    required this.route,
    required this.destination,
  });

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  final _tts = TtsService.instance;
  int _tab = 0; // 0=Overview 1=Functional Points 2=Risk Points

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tts.speak(widget.route.overviewTts);
    });
  }

  void _startNavigation() {
    _tts.stop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationScreen(route: widget.route),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Route · ${widget.route.modeLabel}'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: 'Read route overview',
            onPressed: () => _tts.speak(widget.route.overviewTts),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildScoreBar(),
          _buildTabBar(),
          Expanded(child: _buildTabContent()),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildScoreBar() {
    final s = widget.route.accessibilitySummary;
    final color = s.score >= 80
        ? Colors.green[700]!
        : s.score >= 60
            ? Colors.orange[700]!
            : Colors.red[700]!;
    return Semantics(
      label:
          'Accessibility score ${s.score}. ${s.ttsDescription}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: color.withValues(alpha: 0.1),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  '${s.score}',
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
                  const Text('Accessibility Score',
                      style:
                          TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 2),
                  Text(
                    '${s.streetCrossings} crossing${s.streetCrossings == 1 ? '' : 's'}  ·  ${(s.walkingDistanceMeters / 1000).toStringAsFixed(1)} km walk  ·  ${s.transferCount} transfer${s.transferCount == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (s.audibleSignals > 0)
                    Text(
                      '${s.audibleSignals} audible signal${s.audibleSignals == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 13, color: Colors.green[700]),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.volume_up),
              tooltip: 'Read accessibility details',
              onPressed: () => _tts.speak(s.ttsDescription),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      'Overview',
      'Key Points (${widget.route.functionalPoints.length})',
      'Risk Points (${widget.route.riskPoints.length})',
    ];
    return Container(
      color: Colors.white,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _tab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected
                          ? const Color(0xFF1565C0)
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: selected
                        ? const Color(0xFF1565C0)
                        : Colors.grey[600],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildFunctionalPointsTab();
      case 2:
        return _buildRiskPointsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (int i = 0; i < widget.route.legs.length; i++)
          _LegCard(leg: widget.route.legs[i], index: i + 1),
      ],
    );
  }

  Widget _buildFunctionalPointsTab() {
    final fps = widget.route.functionalPoints;
    if (fps.isEmpty) {
      return const Center(
          child: Text('No key points', style: TextStyle(fontSize: 16)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: fps.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _FunctionalPointCard(
        fp: fps[i],
        onTts: () => _tts.speak(fps[i].description),
      ),
    );
  }

  Widget _buildRiskPointsTab() {
    final rps = widget.route.riskPoints;
    if (rps.isEmpty) {
      return const Center(
          child: Text('No risk points', style: TextStyle(fontSize: 16)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rps.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _RiskPointCard(
        rp: rps[i],
        onTts: () => _tts.speak(
            'Caution, ${rps[i].severityLabel}: ${rps[i].description}'),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: LargeButton(
        label: 'Start Simulated Navigation',
        icon: Icons.navigation,
        onPressed: _startNavigation,
        semanticLabel:
            'Start step-by-step simulated navigation. You can step through each instruction.',
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
    final modeIcon = leg.mode == 'bus'
        ? Icons.directions_bus
        : leg.mode == 'walk'
            ? Icons.directions_walk
            : Icons.local_taxi;
    final modeColor = leg.mode == 'bus'
        ? Colors.blue[700]!
        : leg.mode == 'walk'
            ? Colors.green[700]!
            : Colors.orange[700]!;

    final dur = (leg.durationSeconds / 60).round();
    final dist = leg.distanceMeters < 1000
        ? '${leg.distanceMeters.round()} m'
        : '${(leg.distanceMeters / 1000).toStringAsFixed(1)} km';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text('$dur min · $dist',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${leg.fromName}  →  ${leg.toName}',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            if (leg.transitInfo != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Route ${leg.transitInfo!['route']}  ${leg.transitInfo!['headsign']} (scheduled)',
                  style: TextStyle(
                      fontSize: 13, color: Colors.blue[800]),
                ),
              ),
            ],
            if (leg.steps.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...leg.steps.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(fontSize: 15)),
                      Expanded(
                        child: Text(s.instruction,
                            style: const TextStyle(fontSize: 14)),
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
  final FunctionalPoint fp;
  final VoidCallback onTts;

  const _FunctionalPointCard({required this.fp, required this.onTts});

  @override
  Widget build(BuildContext context) {
    final isRequired =
        fp.importance == FunctionalPointImportance.required;
    final color =
        isRequired ? Colors.blue[700]! : Colors.teal[700]!;
    final typeIcon = fp.type.startsWith('bus')
        ? Icons.directions_bus
        : fp.type == 'building_entrance'
            ? Icons.door_front_door
            : Icons.place;

    return Semantics(
      label: '${fp.importanceLabel} point: ${fp.description}',
      child: Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: color,
            child: Icon(typeIcon, color: Colors.white),
          ),
          title: Text(fp.description,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500)),
          subtitle: Text(
            '${fp.importanceLabel} · Trigger at ${fp.triggerDistanceMeters.round()} m',
            style:
                TextStyle(fontSize: 13, color: Colors.grey[600]),
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
  final RiskPoint rp;
  final VoidCallback onTts;

  const _RiskPointCard({required this.rp, required this.onTts});

  @override
  Widget build(BuildContext context) {
    final color = rp.severity == RiskSeverity.high
        ? Colors.red[700]!
        : rp.severity == RiskSeverity.medium
            ? Colors.orange[700]!
            : Colors.yellow[700]!;

    return Semantics(
      label: '${rp.severityLabel}: ${rp.description}',
      child: Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: color,
            child: const Icon(Icons.warning_amber_rounded,
                color: Colors.white),
          ),
          title: Text(rp.description,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500)),
          subtitle: Text(
            '${rp.severityLabel} · Trigger at ${rp.triggerDistanceMeters.round()} m',
            style:
                TextStyle(fontSize: 13, color: Colors.grey[600]),
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
