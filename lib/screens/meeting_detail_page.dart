import 'package:flutter/material.dart';
import 'package:secured_calling/models/meeting_detail.dart';
import 'package:secured_calling/services/meeting_detail_service.dart';
import 'package:secured_calling/widgets/meeting_info_card.dart';
import 'package:secured_calling/widgets/participant_list_item.dart';

class MeetingDetailPage extends StatefulWidget {
  final String meetingId;

  const MeetingDetailPage({super.key, required this.meetingId});

  @override
  State<MeetingDetailPage> createState() => _MeetingDetailPageState();
}

class _MeetingDetailPageState extends State<MeetingDetailPage> {
  late Future<MeetingDetail> _meetingDetailFuture;
  final MeetingDetailService _meetingDetailService = MeetingDetailService();

  @override
  void initState() {
    super.initState();
    _loadMeetingDetails();
  }

  void _loadMeetingDetails() {
    _meetingDetailFuture = _meetingDetailService.fetchMeetingDetail(widget.meetingId);
  }

  Future<void> _refreshMeetingDetails() async {
    setState(() {
      _loadMeetingDetails();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<MeetingDetail>(
        future: _meetingDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Failed to load meeting details: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshMeetingDetails,
                    child: const Text('Try Again'),
                  )
                ],
              ),
            );
          } else if (!snapshot.hasData) {
            return const Center(child: Text('Meeting details not found.'));
          }

          final meetingDetail = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refreshMeetingDetails,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text(meetingDetail.meetingTitle),
                  floating: true,
                  pinned: true,
                  snap: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.share),
                      tooltip: 'Share Meeting',
                      onPressed: () {
                        // Implement sharing logic
                      },
                    ),
                  ],
                ),
                SliverToBoxAdapter(child: MeetingInfoCard(meeting: meetingDetail)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                    child: Text(
                      'Participants (${meetingDetail.participants.length})',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                _buildParticipantsList(meetingDetail),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildParticipantsList(MeetingDetail meetingDetail) {
    if (meetingDetail.participants.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text(
            'No participants have joined yet.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final participant = meetingDetail.participants[index];
          return ParticipantListItem(participant: participant, index: index);
        },
        childCount: meetingDetail.participants.length,
      ),
    );
  }
}
