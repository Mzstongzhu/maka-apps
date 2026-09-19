import 'package:flutter/material.dart';
import 'groups_screen.dart';
import 'bottle_screen.dart';
import 'activities_screen.dart';
import 'announcements_screen.dart';

/// 功能页：小社区 / 漂流瓶 / 活动 / 公告
class FeaturesScreen extends StatefulWidget {
  const FeaturesScreen({super.key});
  @override
  State<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends State<FeaturesScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final entries = <_FeatureEntry>[
      _FeatureEntry('小社区', '发现并加入感兴趣的社区', Icons.groups, const Color(0xFF6366F1),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupsScreen()))),
      _FeatureEntry('漂流瓶', '捞一个匿名的心事', Icons.sailing, const Color(0xFF0EA5E9),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BottleScreen()))),
      _FeatureEntry('活动', '社区活动与报名', Icons.emoji_events_outlined, const Color(0xFFF59E0B),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivitiesScreen()))),
      _FeatureEntry('公告', '官方公告与通知', Icons.campaign_outlined, const Color(0xFFEF4444),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementsScreen()))),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('功能')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: entries.map((e) => _FeatureCard(entry: e)).toList(),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('更多功能持续上线中', style: TextStyle(fontSize: 12, color: cs.outline)),
          ),
        ],
      ),
    );
  }
}

class _FeatureEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _FeatureEntry(this.title, this.subtitle, this.icon, this.color, this.onTap);
}

class _FeatureCard extends StatelessWidget {
  final _FeatureEntry entry;
  const _FeatureCard({required this.entry});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: entry.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: entry.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(entry.icon, color: entry.color, size: 26),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(entry.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
